use crate::milla::model::*;
use std::sync::{atomic::AtomicBool, atomic::AtomicUsize, Mutex, OnceLock};

/// The buffers that contain the atmos model.
/// OnceLock means we only ever set this once, and it's read-only after that.
/// (The RwLocks inside it are what let us modify the model anyway.)
pub(crate) static BUFFERS: OnceLock<Buffers> = OnceLock::new();

/// The current set of interesting tiles.
/// We only write this once per tick, and only read it on user input.
pub(crate) static INTERESTING_TILES: Mutex<Vec<InterestingTile>> = Mutex::new(Vec::new());

/// The current set of tiles BYOND wants the pressure of.
/// Written to via BYOND call.
/// Read from and cleared via BYOND call.
pub(crate) static TRACKED_PRESSURE_TILES: Mutex<Vec<(i32, i32, usize)>> = Mutex::new(Vec::new());

/// How long the last tick took, in milliseconds.
pub(crate) static TICK_TIME: AtomicUsize = AtomicUsize::new(0);

/// How long the last tick took, in microseconds.
pub(crate) static TICK_TIME_MICROS: AtomicUsize = AtomicUsize::new(0);

/// How many tiles the last tick worked on, how many of those changed at all, and how many
/// changed in a way BYOND can see.
pub(crate) static TICK_TILES_WORKED_ON: AtomicUsize = AtomicUsize::new(0);
pub(crate) static TICK_TILES_CHANGED: AtomicUsize = AtomicUsize::new(0);
pub(crate) static TICK_TILES_CHANGED_FOR_BYOND: AtomicUsize = AtomicUsize::new(0);

/// How long each part of the last tick took, in microseconds, added up over every Z level:
/// getting the frame ready, walls, wind, air flow, and everything after.
pub(crate) static TICK_PHASE_MICROS: [AtomicUsize; 5] = [
    AtomicUsize::new(0),
    AtomicUsize::new(0),
    AtomicUsize::new(0),
    AtomicUsize::new(0),
    AtomicUsize::new(0),
];

/// How long the slowest Z level took in the last tick, in microseconds.
pub(crate) static TICK_SLOWEST_LEVEL_MICROS: AtomicUsize = AtomicUsize::new(0);

/// Running totals since boot: tile reads BYOND has made, and changed tiles it's been told about.
pub(crate) static TOTAL_TILE_READS: AtomicUsize = AtomicUsize::new(0);
pub(crate) static TOTAL_CHANGED_TILES_TOLD: AtomicUsize = AtomicUsize::new(0);

/// The tiles BYOND is holding a copy of, by Z level. When one of them changes BYOND gets told,
/// and from then on it isn't holding a copy any more.
pub(crate) static REMEMBERED_TILES: Mutex<Vec<TileSet>> = Mutex::new(Vec::new());

/// Set from when a tick is started until the frame it works out has become the current one.
/// Nothing can be written in that time.
pub(crate) static TICK_UNFINISHED: AtomicBool = AtomicBool::new(false);

/// Does BYOND make a finished tick the current frame itself, when it asks what changed?
/// If not, the tick thread does it as soon as it's done.
pub(crate) static BYOND_FINISHES_TICKS: AtomicBool = AtomicBool::new(false);

/// The interesting tiles of a tick that's been worked out but isn't the current frame yet.
pub(crate) static FINISHED_INTERESTING_TILES: Mutex<Option<Vec<InterestingTile>>> =
    Mutex::new(None);

/// The tiles whose air has changed since BYOND last asked, by Z level.
pub(crate) static CHANGED_TILES: Mutex<Vec<TileSet>> = Mutex::new(Vec::new());
