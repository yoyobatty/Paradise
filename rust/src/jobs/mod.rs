//! Job system
use flume::{Receiver, Sender, TryRecvError};
use std::{
    cell::RefCell,
    collections::hash_map::{Entry, HashMap},
    panic::{catch_unwind, AssertUnwindSafe},
    sync::{
        atomic::{AtomicUsize, Ordering},
        OnceLock,
    },
    thread,
};

type Output = String;
type JobID = usize;
type Work = Box<dyn FnOnce() + Send + 'static>;

/// The most threads that run jobs at once. Past this, jobs wait for a thread to be free.
const MAX_WORKERS: usize = 64;

struct Job {
    rx: Receiver<Output>,
}

pub const NO_RESULTS_YET: &str = "NO RESULTS YET";
pub const NO_SUCH_JOB: &str = "NO SUCH JOB";
pub const JOB_PANICKED: &str = "JOB PANICKED";

/// The threads that run jobs. A thread is kept for the next job instead of starting a new one each time.
struct Workers {
    queue: Sender<Work>,
    waiting: Receiver<Work>,
    /// Threads waiting for a job.
    idle: AtomicUsize,
    /// Threads started so far.
    total: AtomicUsize,
}

fn workers() -> &'static Workers {
    static WORKERS: OnceLock<Workers> = OnceLock::new();
    WORKERS.get_or_init(|| {
        let (queue, waiting) = flume::unbounded();
        Workers {
            queue,
            waiting,
            idle: AtomicUsize::new(0),
            total: AtomicUsize::new(0),
        }
    })
}

impl Workers {
    fn run(&'static self, work: Work) {
        // Every thread is busy, so start another one, like starting a thread per job did.
        if self.idle.load(Ordering::Acquire) == 0
            && self.total.load(Ordering::Acquire) < MAX_WORKERS
        {
            self.total.fetch_add(1, Ordering::AcqRel);
            let started = thread::Builder::new()
                .name("rustlibs job".to_string())
                .spawn(move || self.work());
            if started.is_err() {
                // Couldn't start one, so the job waits for a busy thread to finish.
                self.total.fetch_sub(1, Ordering::AcqRel);
            }
        }
        let _ = self.queue.send(work);
    }

    fn work(&self) {
        loop {
            self.idle.fetch_add(1, Ordering::AcqRel);
            let work = self.waiting.recv();
            self.idle.fetch_sub(1, Ordering::AcqRel);
            match work {
                Ok(work) => work(),
                Err(_) => break,
            }
        }
    }
}

#[derive(Default)]
struct Jobs {
    map: HashMap<JobID, Job>,
    next_job: usize,
}

impl Jobs {
    fn start<F: FnOnce() -> Output + Send + 'static>(&mut self, f: F) -> usize {
        let (tx, rx) = flume::unbounded();
        workers().run(Box::new(move || {
            // If the job panics, tx is dropped without sending anything and check() says JOB_PANICKED.
            // Catching it keeps the thread alive for the next job.
            if let Ok(output) = catch_unwind(AssertUnwindSafe(f)) {
                let _ = tx.send(output);
            }
        }));
        let id = self.next_job;
        self.next_job += 1;
        self.map.insert(id, Job { rx });
        id
    }

    fn check(&mut self, id: &usize) -> Option<Result<Output, TryRecvError>> {
        let entry = match self.map.entry(id.to_owned()) {
            Entry::Occupied(occupied) => occupied,
            Entry::Vacant(_) => return None,
        };
        let result = match entry.get().rx.try_recv() {
            Ok(result) => Ok(result),
            Err(TryRecvError::Empty) => return Some(Err(TryRecvError::Empty)),
            Err(TryRecvError::Disconnected) => Err(TryRecvError::Disconnected),
        };
        entry.remove();
        Some(result)
    }
}

thread_local! {
    static JOBS: RefCell<Jobs> = RefCell::default();
}

pub fn start<F: FnOnce() -> Output + Send + 'static>(f: F) -> usize {
    JOBS.with(|jobs| jobs.borrow_mut().start(f))
}

pub fn check(id: &usize) -> Option<Result<Output, TryRecvError>> {
    JOBS.with(|jobs| jobs.borrow_mut().check(id))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{Duration, Instant};

    /// Waits for a job to finish and returns what check() said.
    fn wait_for(id: usize) -> Result<Output, TryRecvError> {
        let give_up = Instant::now() + Duration::from_secs(10);
        loop {
            match check(&id) {
                Some(Err(TryRecvError::Empty)) => {
                    assert!(Instant::now() < give_up, "job {id} never finished");
                    thread::sleep(Duration::from_millis(1));
                }
                Some(result) => return result,
                None => panic!("job {id} went missing"),
            }
        }
    }

    #[test]
    fn jobs_finish_and_threads_are_reused() {
        let ids: Vec<usize> = (0..500).map(|i| start(move || i.to_string())).collect();
        for (i, id) in ids.into_iter().enumerate() {
            assert_eq!(wait_for(id), Ok(i.to_string()));
        }
        assert!(workers().total.load(Ordering::Acquire) <= MAX_WORKERS);
    }

    #[test]
    fn panicking_job_is_reported_and_the_next_job_runs() {
        let bad = start(|| panic!("this job panics on purpose"));
        assert_eq!(wait_for(bad), Err(TryRecvError::Disconnected));
        let good = start(|| "still working".to_string());
        assert_eq!(wait_for(good), Ok("still working".to_string()));
    }

    #[test]
    fn slow_jobs_dont_hold_up_quick_ones() {
        let slow: Vec<usize> = (0..8)
            .map(|_| {
                start(|| {
                    thread::sleep(Duration::from_millis(500));
                    "slow".to_string()
                })
            })
            .collect();
        let started = Instant::now();
        let quick = start(|| "quick".to_string());
        assert_eq!(wait_for(quick), Ok("quick".to_string()));
        assert!(started.elapsed() < Duration::from_millis(400));
        for id in slow {
            assert_eq!(wait_for(id), Ok("slow".to_string()));
        }
    }
}
