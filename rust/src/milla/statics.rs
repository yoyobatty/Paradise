use crate::milla::model::*;
use std::sync::{atomic::AtomicUsize, Mutex, OnceLock};

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

/// The threads MILLA ticks on. They're kept from tick to tick, instead of starting new ones each tick.
pub(crate) static TICK_THREADS: OnceLock<rayon::ThreadPool> = OnceLock::new();

/// Gets MILLA's threads, starting them the first time.
pub(crate) fn tick_threads() -> &'static rayon::ThreadPool {
    TICK_THREADS.get_or_init(|| {
        rayon::ThreadPoolBuilder::new()
            .thread_name(|index| format!("MILLA {index}"))
            // MILLA runs at the lowest priority, so it doesn't take time from BYOND's own thread.
            .start_handler(|_| {
                let _ = thread_priority::ThreadPriority::Min.set_for_current();
            })
            // Ticks catch and report their own panics. Without this, one that got past them
            // would end the whole server.
            .panic_handler(|_| {})
            .build()
            .expect("MILLA couldn't start its threads")
    })
}
