//! The lighting engine, called from SSlighting (code/modules/lighting/lighting_engine.dm). The work is in engine.rs;
//! this is the BYOND side of it.
//!
//! It only reads the arguments and lists DM passes, and writes into lists DM passes, and what it keeps of them are
//! numbers and turfs: turfs aren't reference counted and are known by their place in the world, so it never holds a
//! BYOND reference.

pub(crate) mod engine;

use byondapi::prelude::*;
use engine::{Engine, Update};
use eyre::eyre;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::Mutex;

/// Bumped whenever what DM and the engine pass each other changes. DM won't use an engine that says anything else.
const ENGINE_VERSION: f32 = 1.0;

const TYPE_TURF: u8 = 0x01;
const TYPE_NUMBER: u8 = 0x2A;

struct State {
    engine: Engine,
    /// Turfs on one z-level
    per_level: u32,
    seen: Vec<u32>,
    out: Vec<ByondValue>,
}

impl State {
    /// A turf's z-level (from 1) and number on it
    fn place(&self, turf: &ByondValue) -> Result<(usize, u32), String> {
        let id = turf_id(turf).ok_or("expected a turf")?;
        Ok(((id / self.per_level) as usize + 1, id % self.per_level))
    }
}

static STATE: Mutex<Option<State>> = Mutex::new(None);

fn num(value: &ByondValue) -> f32 {
    if value.0.type_ == TYPE_NUMBER {
        // Safety: numbers keep their value in num
        unsafe { value.0.data.num }
    } else {
        0.0
    }
}

fn int(value: &ByondValue) -> i32 {
    num(value) as i32
}

/// A turf's reference number: (z - 1) * maxx * maxy + (y - 1) * maxx + (x - 1), checked by lighting_setup()
fn turf_id(value: &ByondValue) -> Option<u32> {
    if value.0.type_ == TYPE_TURF {
        // Safety: references keep their number in ref_
        Some(unsafe { value.0.data.ref_ })
    } else {
        None
    }
}

fn read(list: &ByondValue) -> Result<Vec<ByondValue>, String> {
    list.get_list_values()
        .map_err(|e| format!("couldn't read a list: {e:?}"))
}

fn write(list: &ByondValue, values: &[ByondValue]) -> Result<(), String> {
    list.write_list(values)
        .map_err(|e| format!("couldn't write a list: {e:?}"))
}

/// Runs `call`, turning its errors, and any panic, into a runtime for DM
fn guarded(name: &str, call: impl FnOnce() -> Result<f32, String>) -> eyre::Result<ByondValue> {
    match catch_unwind(AssertUnwindSafe(call)) {
        Ok(Ok(value)) => Ok(ByondValue::new_num(value)),
        Ok(Err(error)) => Err(eyre!("lighting engine, {name}: {error}")),
        Err(_) => Err(eyre!("lighting engine, {name}: panicked")),
    }
}

fn with_state(
    name: &str,
    call: impl FnOnce(&mut State) -> Result<f32, String>,
) -> eyre::Result<ByondValue> {
    guarded(name, || {
        let mut guard = STATE
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        let state = guard.as_mut().ok_or("not set up")?;
        call(state)
    })
}

/// Starts afresh for a world this size, rounding what lighting objects draw to multiples of `round`. `turfs` are a few
/// turfs and `coordinates` their x, y and z one after another, to check turfs are numbered the way the engine thinks.
/// Returns the engine's version.
#[byondapi::bind]
fn lighting_setup(
    maxx: ByondValue,
    maxy: ByondValue,
    round: ByondValue,
    turfs: ByondValue,
    coordinates: ByondValue,
) -> eyre::Result<ByondValue> {
    guarded("setup", || {
        let (maxx, maxy, round) = (int(&maxx), int(&maxy), num(&round));
        if maxx < 1 || maxy < 1 || round <= 0.0 {
            return Err(format!("no world ({maxx} by {maxy}) or rounding ({round})"));
        }
        let turfs = read(&turfs)?;
        let coordinates = read(&coordinates)?;
        if coordinates.len() != turfs.len() * 3 {
            return Err("turfs and coordinates don't match".into());
        }
        let per_level = (maxx * maxy) as u32;
        for (i, turf) in turfs.iter().enumerate() {
            let (x, y, z) = (
                int(&coordinates[i * 3]),
                int(&coordinates[i * 3 + 1]),
                int(&coordinates[i * 3 + 2]),
            );
            let expected = (z as u32 - 1) * per_level + ((y - 1) * maxx + (x - 1)) as u32;
            if turf_id(turf) != Some(expected) {
                return Err(format!(
                    "turf ({x},{y},{z}) is numbered {:?}, not {expected}",
                    turf_id(turf)
                ));
            }
        }
        *STATE
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = Some(State {
            engine: Engine::new(maxx, maxy, round),
            per_level,
            seen: Vec::new(),
            out: Vec::new(),
        });
        Ok(ENGINE_VERSION)
    })
}

/// Many turfs' flags: turf, flags, turf, flags... (engine::OPAQUE and co.)
#[byondapi::bind]
fn lighting_flags(list: ByondValue) -> eyre::Result<ByondValue> {
    with_state("flags", |state| {
        let values = read(&list)?;
        for pair in values.chunks_exact(2) {
            let (z, t) = state.place(&pair[0])?;
            state.engine.set_flags(z, t, int(&pair[1]) as u8);
        }
        Ok((values.len() / 2) as f32)
    })
}

/// One turf's flags
#[byondapi::bind]
fn lighting_flag(turf: ByondValue, flags: ByondValue) -> eyre::Result<ByondValue> {
    with_state("flag", |state| {
        let (z, t) = state.place(&turf)?;
        state.engine.set_flags(z, t, int(&flags) as u8);
        Ok(1.0)
    })
}

/// A falloff table for one light range: `dim` x `dim` values, column after column
#[byondapi::bind]
fn lighting_sheet(id: ByondValue, dim: ByondValue, values: ByondValue) -> eyre::Result<ByondValue> {
    with_state("sheet", |state| {
        let values = read(&values)?;
        let dim = int(&dim);
        if dim < 2 || values.len() != (dim * dim) as usize {
            return Err(format!("a {dim} wide table with {} values", values.len()));
        }
        state
            .engine
            .set_sheet(int(&id) as usize, dim, values.iter().map(num).collect());
        Ok(1.0)
    })
}

/// What update_corners() works out once it has looked around: the light's id, pixel_turf's x and y, the z-level it
/// looked on, its power and colour, its falloff table, 1 if only what it can see changed, and what view() handed back.
#[byondapi::bind]
fn lighting_update(
    id: ByondValue,
    x: ByondValue,
    y: ByondValue,
    z: ByondValue,
    power: ByondValue,
    red: ByondValue,
    green: ByondValue,
    blue: ByondValue,
    sheet: ByondValue,
    vis_only: ByondValue,
    seen: ByondValue,
) -> eyre::Result<ByondValue> {
    with_state("update", |state| {
        let update = Update {
            id: int(&id) as usize,
            z: int(&z) as usize,
            tx: int(&x),
            ty: int(&y),
            power: num(&power),
            lum: [num(&red), num(&green), num(&blue)],
            sheet: int(&sheet) as usize,
            vis_only: int(&vis_only) != 0,
        };
        if update.id == 0 || update.z == 0 {
            return Err("no id or z-level".into());
        }
        let values = read(&seen)?;
        let mut turfs = std::mem::take(&mut state.seen);
        turfs.clear();
        let first = (update.z as u32 - 1) * state.per_level;
        for v in values.iter() {
            if let Some(t) = turf_id(v) {
                if t >= first && t - first < state.per_level {
                    turfs.push(t - first);
                }
            }
        }
        let result = state.engine.update(&update, &turfs);
        state.seen = turfs;
        result.map(|_| 1.0)
    })
}

/// remove_lum()
#[byondapi::bind]
fn lighting_remove(id: ByondValue) -> eyre::Result<ByondValue> {
    with_state("remove", |state| {
        state.engine.remove(int(&id) as usize);
        Ok(1.0)
    })
}

/// The light source is gone: takes its light off and frees its id
#[byondapi::bind]
fn lighting_forget(id: ByondValue) -> eyre::Result<ByondValue> {
    with_state("forget", |state| {
        state.engine.forget(int(&id) as usize);
        Ok(1.0)
    })
}

/// The ids of the lights on the turf's corners, written into `out`, for reconsider_lights(). Returns how many.
#[byondapi::bind]
fn lighting_affecting(turf: ByondValue, out: ByondValue) -> eyre::Result<ByondValue> {
    with_state("affecting", |state| {
        let (z, t) = state.place(&turf)?;
        let ids = state.engine.affecting(z, t);
        if ids.is_empty() {
            return Ok(0.0);
        }
        let values: Vec<ByondValue> = ids
            .iter()
            .map(|&id| ByondValue::new_num(id as f32))
            .collect();
        write(&out, &values)?;
        Ok(ids.len() as f32)
    })
}

/// The corner stage, then up to `max` lighting objects to draw, into `out`: the turf, then the 12 colours and the
/// brightest (see engine::Engine::object_values()). Returns how many are still waiting.
#[byondapi::bind]
fn lighting_flush(max: ByondValue, out: ByondValue) -> eyre::Result<ByondValue> {
    with_state("flush", |state| {
        state.engine.flush_corners();
        let mut values = std::mem::take(&mut state.out);
        values.clear();
        let per_level = state.per_level;
        let left = state
            .engine
            .take_objects(int(&max).max(0) as usize, |z, t, colours| {
                values.push(ByondValue::new_ref(
                    ValueType::Turf,
                    (z - 1) * per_level + t,
                ));
                values.extend(colours.iter().map(|&v| ByondValue::new_num(v)));
            });
        let result = if values.is_empty() {
            Ok(())
        } else {
            write(&out, &values)
        };
        state.out = values;
        result.map(|_| left as f32)
    })
}

/// What one turf's lighting object draws, into `out`, as lighting_flush() gives it
#[byondapi::bind]
fn lighting_object(turf: ByondValue, out: ByondValue) -> eyre::Result<ByondValue> {
    with_state("object", |state| {
        let (z, t) = state.place(&turf)?;
        let values: Vec<ByondValue> = state
            .engine
            .object_values(z, t)
            .iter()
            .map(|&v| ByondValue::new_num(v))
            .collect();
        write(&out, &values)?;
        Ok(1.0)
    })
}

/// get_lumcount()'s total light on the turf's corners
#[byondapi::bind]
fn lighting_lumcount(turf: ByondValue) -> eyre::Result<ByondValue> {
    with_state("lumcount", |state| {
        let (z, t) = state.place(&turf)?;
        Ok(state.engine.lumcount(z, t))
    })
}
