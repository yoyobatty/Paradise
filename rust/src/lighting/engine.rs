//! The lighting engine: keeps the lighting corners, what each light gives each corner, and what each lighting object
//! should draw. DM decides when a light needs working out, finds what it can see with view(), works out the falloff
//! (as tables per light range, see SSlighting's falloff_table()) and draws the lighting objects. The sums here are
//! the ones the DM lighting code did, in the same 32 bit float operations in the same order.
//!
//! Places: turfs are numbered from 0 on each z-level, (y - 1) * maxx + (x - 1). Corners sit between turfs: corner
//! (cx, cy), cx in 0..=maxx and cy in 0..=maxy, is DM's corner at x = cx + 0.5, y = cy + 0.5. Turf (x, y) has corners
//! NE (x, y), SE (x, y - 1), SW (x - 1, y - 1) and NW (x - 1, y).

/// The turf blocks light from every direction (IS_OPAQUE_TURF)
pub const OPAQUE: u8 = 1;
/// The turf has a lighting object to draw on
pub const OBJECT: u8 = 2;

#[derive(Clone, Default)]
pub struct Corner {
    pub lum: [f32; 3],
    pub cache: [f32; 3],
    pub largest: f32,
    pub needs_update: bool,
    /// Light ids, as DM's affecting list: one entry each time a light took hold, dropped one at a time
    pub affecting: Vec<u32>,
    // Scratch for the update under way
    stamp: u32,
    level: f32,
    // The updating light's strength here before it started, marked with its stamp: DM's effect_str[corner]
    old_mark: u32,
    old: f32,
}

pub struct Level {
    pub corners: Vec<Corner>,
    pub flags: Vec<u8>,
    object_queued: Vec<bool>,
}

pub struct Light {
    pub id: u32,
    pub z: usize,
    pub applied: [f32; 3],
    /// DM's effect_str: corner -> strength
    pub effect: Vec<(u32, f32)>,
}

/// A falloff table DM worked out for one light range: LUM_FALLOFF() for every corner offset a light of that range can
/// reach. Entry (ix, iy) is the corner at x offset ix - half - 1 and y offset iy - half - 1 from the light's turf.
pub struct Sheet {
    pub dim: i32,
    pub half: i32,
    pub values: Vec<f32>,
}

/// What DM hands over for one light's update: see /datum/light_source/proc/update_corners()
pub struct Update {
    pub id: usize,
    /// The z-level view() looked around on
    pub z: usize,
    /// pixel_turf's x and y: where the falloff is measured from
    pub tx: i32,
    pub ty: i32,
    pub power: f32,
    pub lum: [f32; 3],
    pub sheet: usize,
    /// Only what it can see changed: the corners it already lights keep what they have
    pub vis_only: bool,
}

pub struct Engine {
    pub maxx: i32,
    pub maxy: i32,
    /// LIGHTING_ROUND_VALUE
    round: f32,
    pub levels: Vec<Option<Level>>,
    pub lights: Vec<Option<Light>>,
    pub sheets: Vec<Option<Sheet>>,
    stamp: u32,
    /// SSlighting's corners_queue: (z, corner)
    corner_queue: Vec<(u32, u32)>,
    /// SSlighting's objects_queue, by turf: (z, turf)
    object_queue: Vec<(u32, u32)>,
    reached: Vec<u32>,
}

impl Engine {
    pub fn new(maxx: i32, maxy: i32, round: f32) -> Self {
        Engine {
            maxx,
            maxy,
            round,
            levels: Vec::new(),
            lights: Vec::new(),
            sheets: Vec::new(),
            stamp: 0,
            corner_queue: Vec::new(),
            object_queue: Vec::new(),
            reached: Vec::new(),
        }
    }

    /// The z-level's grids, made the first time anything happens there. z counts from 1.
    pub fn level(&mut self, z: usize) -> &mut Level {
        if z >= self.levels.len() {
            self.levels.resize_with(z + 1, || None);
        }
        let turfs = (self.maxx * self.maxy) as usize;
        let corners = ((self.maxx + 1) * (self.maxy + 1)) as usize;
        self.levels[z].get_or_insert_with(|| Level {
            corners: vec![Corner::default(); corners],
            flags: vec![0; turfs],
            object_queued: vec![false; turfs],
        })
    }

    #[inline]
    pub fn turf_xy(&self, turf: u32) -> (i32, i32) {
        let t = turf as i32;
        (t % self.maxx + 1, t / self.maxx + 1)
    }

    /// NE, SE, SW, NW
    #[inline]
    fn turf_corners(&self, x: i32, y: i32) -> [u32; 4] {
        let cols = self.maxx + 1;
        [
            (y * cols + x) as u32,
            ((y - 1) * cols + x) as u32,
            ((y - 1) * cols + x - 1) as u32,
            (y * cols + x - 1) as u32,
        ]
    }

    pub fn set_flags(&mut self, z: usize, turf: u32, flags: u8) {
        self.level(z).flags[turf as usize] = flags;
    }

    pub fn set_sheet(&mut self, id: usize, dim: i32, values: Vec<f32>) {
        if id >= self.sheets.len() {
            self.sheets.resize_with(id + 1, || None);
        }
        self.sheets[id] = Some(Sheet {
            dim,
            half: (dim - 2) / 2,
            values,
        });
    }

    /// LUM_FALLOFF() for corner (cx, cy) from a light on turf (tx, ty). Off the table it's 0, as DM's sum clamps to there.
    #[inline]
    fn falloff(sheet: &Sheet, tx: i32, ty: i32, cx: i32, cy: i32) -> f32 {
        let ix = cx - tx + sheet.half + 1;
        let iy = cy - ty + sheet.half + 1;
        if ix < 0 || iy < 0 || ix >= sheet.dim || iy >= sheet.dim {
            return 0.0;
        }
        sheet.values[(ix * sheet.dim + iy) as usize]
    }

    fn next_stamp(&mut self) -> u32 {
        self.stamp = self.stamp.wrapping_add(1);
        if self.stamp == 0 {
            for level in self.levels.iter_mut().flatten() {
                for c in level.corners.iter_mut() {
                    c.stamp = 0;
                    c.old_mark = 0;
                }
            }
            self.stamp = 1;
        }
        self.stamp
    }

    /// ADD_CORNER_LUM
    #[inline]
    fn add_lum(level: &mut Level, queue: &mut Vec<(u32, u32)>, z: usize, corner: u32, d: [f32; 3]) {
        if d[0] != 0.0 || d[1] != 0.0 || d[2] != 0.0 {
            let c = &mut level.corners[corner as usize];
            c.lum[0] += d[0];
            c.lum[1] += d[1];
            c.lum[2] += d[2];
            if !c.needs_update {
                c.needs_update = true;
                queue.push((z as u32, corner));
            }
        }
    }

    fn remove_affecting(corner: &mut Corner, id: u32) {
        if let Some(at) = corner.affecting.iter().position(|&l| l == id) {
            corner.affecting.remove(at);
        }
    }

    /// update_corners() from where it starts gathering corners. `seen` is what view() handed back, as turfs on the
    /// light's z-level, in its order.
    pub fn update(&mut self, u: &Update, seen: &[u32]) -> Result<(), String> {
        if u.id >= self.lights.len() {
            self.lights.resize_with(u.id + 1, || None);
        }
        let mut light = self.lights[u.id].take().unwrap_or(Light {
            id: u.id as u32,
            z: u.z,
            applied: [0.0; 3],
            effect: Vec::new(),
        });
        if light.z != u.z && !light.effect.is_empty() {
            // Moved to another z-level with its light still on the old one: DM keeps one list of corners for both, and
            // working it out afresh drops every corner it no longer reaches, so take it off there first
            self.remove_light(&mut light);
        }
        let result = self.update_light(&mut light, u, seen);
        self.lights[u.id] = Some(light);
        result
    }

    fn update_light(&mut self, light: &mut Light, u: &Update, seen: &[u32]) -> Result<(), String> {
        let stamp = self.next_stamp();
        let z = u.z;
        let maxx = self.maxx;
        let sheets = std::mem::take(&mut self.sheets);
        let result = (|| {
            let sheet = sheets
                .get(u.sheet)
                .and_then(|s| s.as_ref())
                .ok_or("no such sheet")?;
            self.level(z);
            let mut reached = std::mem::take(&mut self.reached);
            reached.clear();
            let (tx, ty) = (u.tx, u.ty);
            let mut queue = std::mem::take(&mut self.corner_queue);
            let level = self.levels[z].as_mut().unwrap();
            // What we light now, for the loops below (DM's effect_str lookups)
            for &(c, s) in light.effect.iter() {
                let corner = &mut level.corners[c as usize];
                corner.old_mark = stamp;
                corner.old = s;
            }
            // GATHER_CORNER over every turf view() handed back that doesn't block light
            let cols = maxx + 1;
            for &t in seen {
                if level.flags[t as usize] & OPAQUE != 0 {
                    continue;
                }
                let x = t as i32 % maxx + 1;
                let y = t as i32 / maxx + 1;
                for (cx, cy) in [(x, y), (x, y - 1), (x - 1, y - 1), (x - 1, y)] {
                    let c = (cy * cols + cx) as u32;
                    let corner = &mut level.corners[c as usize];
                    if corner.stamp == stamp {
                        continue;
                    }
                    corner.stamp = stamp;
                    let lvl = Self::falloff(sheet, tx, ty, cx, cy);
                    corner.level = lvl;
                    if lvl > 0.0 || corner.old_mark == stamp {
                        reached.push(c);
                    }
                }
            }

            // Onto the corners we reach, then off those we no longer do
            let power = u.power;
            let lum = u.lum;
            let applied = light.applied;
            let mut effect = Vec::with_capacity(reached.len());
            for &c in reached.iter() {
                let corner = &mut level.corners[c as usize];
                let old;
                if corner.old_mark != stamp {
                    old = 0.0f32;
                } else {
                    old = corner.old;
                    if u.vis_only {
                        // DM: a visibility update leaves the corners it already lights as they are
                        effect.push((c, old));
                        corner.old_mark = 0;
                        continue;
                    }
                }
                let strength = corner.level * power;
                if strength == 0.0 {
                    continue; // DM: nothing here now; if it had something, the loop below takes it off
                }
                if corner.old_mark != stamp {
                    corner.affecting.push(u.id as u32);
                }
                corner.old_mark = 0;
                effect.push((c, strength));
                let d = [
                    strength * lum[0] - old * applied[0],
                    strength * lum[1] - old * applied[1],
                    strength * lum[2] - old * applied[2],
                ];
                Self::add_lum(level, &mut queue, z, c, d);
            }
            // Anything we lit before that we don't now: not seen this time, or seen with nothing on it
            for &(c, s) in light.effect.iter() {
                let corner = &mut level.corners[c as usize];
                if corner.old_mark == stamp {
                    let strength = -s;
                    let d = [
                        strength * applied[0],
                        strength * applied[1],
                        strength * applied[2],
                    ];
                    Self::remove_affecting(corner, u.id as u32);
                    Self::add_lum(level, &mut queue, z, c, d);
                    level.corners[c as usize].old_mark = 0;
                }
            }
            light.effect = effect;
            light.z = z;
            light.applied = u.lum;
            self.corner_queue = queue;
            self.reached = reached;
            Ok(())
        })();
        self.sheets = sheets;
        result
    }

    /// remove_lum()
    pub fn remove(&mut self, id: usize) {
        if let Some(mut light) = self.lights.get_mut(id).and_then(|l| l.take()) {
            self.remove_light(&mut light);
            self.lights[id] = Some(light);
        }
    }

    fn remove_light(&mut self, light: &mut Light) {
        let z = light.z;
        let applied = light.applied;
        let mut queue = std::mem::take(&mut self.corner_queue);
        let light_id = light.id;
        let level = self.level(z);
        for &(c, s) in light.effect.iter() {
            let strength = -s;
            let d = [
                strength * applied[0],
                strength * applied[1],
                strength * applied[2],
            ];
            Self::add_lum(level, &mut queue, z, c, d);
            Self::remove_affecting(&mut level.corners[c as usize], light_id);
        }
        light.effect.clear();
        self.corner_queue = queue;
    }

    /// The light is gone for good
    pub fn forget(&mut self, id: usize) {
        self.remove(id);
        if let Some(slot) = self.lights.get_mut(id) {
            *slot = None;
        }
    }

    /// The corner stage: each corner queued works out what it draws, and queues the lighting objects that draw it
    pub fn flush_corners(&mut self) {
        let mut queue = std::mem::take(&mut self.corner_queue);
        let maxx = self.maxx;
        let maxy = self.maxy;
        let round = self.round;
        for &(z, c) in queue.iter() {
            let z = z as usize;
            let Some(level) = self.levels.get_mut(z).and_then(|l| l.as_mut()) else {
                continue;
            };
            let corner = &mut level.corners[c as usize];
            corner.needs_update = false;
            let changed = update_cache(corner, round);
            let unlit = corner.affecting.is_empty();
            if changed {
                let cx = c as i32 % (maxx + 1);
                let cy = c as i32 / (maxx + 1);
                // master_NE, master_SE, master_SW, master_NW
                for (x, y) in [(cx + 1, cy + 1), (cx + 1, cy), (cx, cy), (cx, cy + 1)] {
                    if x < 1 || y < 1 || x > maxx || y > maxy {
                        continue;
                    }
                    let t = ((y - 1) * maxx + (x - 1)) as usize;
                    if level.flags[t] & OBJECT != 0 && !level.object_queued[t] {
                        level.object_queued[t] = true;
                        self.object_queue.push((z as u32, t as u32));
                    }
                }
            }
            if unlit {
                // Nothing lights it any more: start it from nothing, float leftovers and all
                *corner = Corner {
                    stamp: corner.stamp,
                    old_mark: corner.old_mark,
                    ..Corner::default()
                };
            }
        }
        queue.clear();
        self.corner_queue = queue;
    }

    /// What a turf's lighting object draws: the SW, SE, NW and NE corners' colours, then the brightest of them
    pub fn object_values(&self, z: usize, turf: u32) -> [f32; 13] {
        let mut out = [0.0f32; 13];
        let Some(level) = self.levels.get(z).and_then(|l| l.as_ref()) else {
            return out;
        };
        let (x, y) = self.turf_xy(turf);
        let [ne, se, sw, nw] = self.turf_corners(x, y);
        let mut max = 0.0f32;
        for (i, c) in [sw, se, nw, ne].into_iter().enumerate() {
            let corner = &level.corners[c as usize];
            out[i * 3] = corner.cache[0];
            out[i * 3 + 1] = corner.cache[1];
            out[i * 3 + 2] = corner.cache[2];
            // max(red, green, blue, alpha corner)
            max = if i == 0 {
                corner.largest
            } else {
                max.max(corner.largest)
            };
        }
        out[12] = max;
        out
    }

    /// Takes up to `max` lighting objects off the queue. Returns how many are left.
    pub fn take_objects(&mut self, max: usize, mut each: impl FnMut(u32, u32, [f32; 13])) -> usize {
        let n = self.object_queue.len().min(max);
        let taken: Vec<(u32, u32)> = self.object_queue.drain(..n).collect();
        for (z, t) in taken {
            let values = self.object_values(z as usize, t);
            if let Some(level) = self.levels.get_mut(z as usize).and_then(|l| l.as_mut()) {
                level.object_queued[t as usize] = false;
            }
            each(z, t, values);
        }
        self.object_queue.len()
    }

    /// get_lumcount()'s total: lum_r + lum_b + lum_g over the turf's corners, NE, SE, SW, NW
    pub fn lumcount(&self, z: usize, turf: u32) -> f32 {
        let Some(level) = self.levels.get(z).and_then(|l| l.as_ref()) else {
            return 0.0;
        };
        let (x, y) = self.turf_xy(turf);
        let mut total = 0.0f32;
        for c in self.turf_corners(x, y) {
            let corner = &level.corners[c as usize];
            total += corner.lum[0] + corner.lum[2] + corner.lum[1];
        }
        total
    }

    /// The lights on a turf's corners, NE, SE, SW, NW, each once
    pub fn affecting(&mut self, z: usize, turf: u32) -> Vec<u32> {
        let (x, y) = self.turf_xy(turf);
        let corners = self.turf_corners(x, y);
        let level = self.level(z);
        let mut out: Vec<u32> = Vec::new();
        for c in corners {
            for &id in level.corners[c as usize].affecting.iter() {
                if !out.contains(&id) {
                    out.push(id);
                }
            }
        }
        out
    }

    /// Checks the books, for the tests: every corner's light is what the lights on it say they give it, and corners and lights agree
    /// on which lights which. Returns the problems found.
    #[cfg(test)]
    pub fn check(&self) -> Vec<String> {
        use std::collections::HashMap;
        let mut problems = Vec::new();
        let mut expected: HashMap<(usize, u32), [f64; 3]> = HashMap::new();
        let mut holds: HashMap<(usize, u32), Vec<u32>> = HashMap::new();
        for (id, light) in self.lights.iter().enumerate() {
            let Some(light) = light else { continue };
            for &(c, s) in light.effect.iter() {
                let e = expected.entry((light.z, c)).or_insert([0.0; 3]);
                for k in 0..3 {
                    e[k] += (s * light.applied[k]) as f64;
                }
                holds.entry((light.z, c)).or_default().push(id as u32);
            }
        }
        let cols = self.maxx + 1;
        for (z, level) in self.levels.iter().enumerate() {
            let Some(level) = level else { continue };
            for (c, corner) in level.corners.iter().enumerate() {
                let e = expected.get(&(z, c as u32)).copied().unwrap_or([0.0; 3]);
                if (0..3).any(|k| (corner.lum[k] as f64 - e[k]).abs() > 0.001) {
                    problems.push(format!(
                        "corner {},{},{} has {:?}, its lights give it {:?}",
                        c as i32 % cols,
                        c as i32 / cols,
                        z,
                        corner.lum,
                        e
                    ));
                }
                let mut a = corner.affecting.clone();
                let mut b = holds.get(&(z, c as u32)).cloned().unwrap_or_default();
                a.sort_unstable();
                b.sort_unstable();
                if a != b {
                    problems.push(format!(
                        "corner {},{},{} thinks lights {:?} light it, they say {:?}",
                        c as i32 % cols,
                        c as i32 / cols,
                        z,
                        a,
                        b
                    ));
                }
            }
        }
        problems
    }
}

/// What a corner draws, from its light (LIGHTING_SOFT_THRESHOLD 0): returns whether that changed
pub fn update_cache(corner: &mut Corner, round: f32) -> bool {
    let [lum_r, lum_g, lum_b] = corner.lum;
    let largest = lum_r.max(lum_g).max(lum_b);
    let mut factor = 1.0f32;
    if largest > 1.0 {
        factor = 1.0 / largest;
    }
    let old = corner.cache;
    corner.cache = [
        round_to(lum_r * factor, round),
        round_to(lum_g * factor, round),
        round_to(lum_b * factor, round),
    ];
    corner.largest = round_to(largest, round);
    old != corner.cache
}

/// DM's round(value, step)
#[inline]
pub fn round_to(value: f32, step: f32) -> f32 {
    (value / step + 0.5).floor() * step
}

#[cfg(test)]
mod tests {
    use super::*;

    fn engine_with_sheet(value: f32) -> Engine {
        let mut e = Engine::new(10, 10, 1.0 / 64.0);
        let dim = 2 * 2 + 2;
        e.set_sheet(1, dim, vec![value; (dim * dim) as usize]);
        for t in 0..100 {
            e.set_flags(1, t, OBJECT);
        }
        e
    }

    fn update(id: usize) -> Update {
        Update {
            id,
            z: 1,
            tx: 5,
            ty: 5,
            power: 1.0,
            lum: [1.0, 0.5, 0.25],
            sheet: 1,
            vis_only: false,
        }
    }

    fn seen_around(x: i32, y: i32, reach: i32) -> Vec<u32> {
        (0..100u32)
            .filter(|&t| {
                let (tx, ty) = (t as i32 % 10 + 1, t as i32 / 10 + 1);
                (tx - x).abs() <= reach && (ty - y).abs() <= reach
            })
            .collect()
    }

    #[test]
    fn a_light_lights_what_it_sees_and_takes_it_off_again() {
        let mut e = engine_with_sheet(0.5);
        e.update(&update(1), &seen_around(5, 5, 2)).unwrap();
        assert_eq!(e.lights[1].as_ref().unwrap().effect.len(), 36);
        let c = (5 * 11 + 5) as usize;
        assert_eq!(
            e.levels[1].as_ref().unwrap().corners[c].lum,
            [0.5, 0.25, 0.125]
        );
        assert!(e.check().is_empty());
        e.flush_corners();
        assert!(!e.object_queue.is_empty());
        e.remove(1);
        assert_eq!(
            e.levels[1].as_ref().unwrap().corners[c].lum,
            [0.0, 0.0, 0.0]
        );
        assert!(e.check().is_empty());
    }

    #[test]
    fn walls_are_skipped_and_corners_left_behind_are_taken_off() {
        let mut e = engine_with_sheet(0.5);
        e.update(&update(1), &seen_around(5, 5, 2)).unwrap();
        e.set_flags(1, 4 * 10 + 6, OPAQUE | OBJECT); // turf (7, 5)
        e.update(&update(1), &seen_around(5, 5, 1)).unwrap();
        assert_eq!(e.lights[1].as_ref().unwrap().effect.len(), 16);
        assert!(e.check().is_empty());
    }

    #[test]
    fn rounding_matches_byond() {
        assert_eq!(round_to(0.5, 1.0 / 64.0), 0.5);
        assert_eq!(round_to(1.0 / 128.0, 1.0 / 64.0), 1.0 / 64.0);
        assert_eq!(round_to(0.0, 1.0 / 64.0), 0.0);
    }
}
