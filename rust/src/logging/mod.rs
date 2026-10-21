use byondapi::global_call::call_global;
use byondapi::prelude::ByondValue;
use byondapi::threadsync::thread_sync;
use chrono::prelude::Utc;
use uuid::Uuid;

/// Call stack trace dm method with message.
pub(crate) fn dm_call_stack_trace(msg: String) -> eyre::Result<()> {
    call_global("stack_trace", &[ByondValue::new_str(msg)?])?;

    Ok(())
}

/// Panic handler, called on unhandled errors.
/// Writes panic info to a text file, and calls dm stack trace proc as well.
pub(crate) fn setup_panic_handler() {
    std::panic::set_hook(Box::new(|info| {
        let msg = format!("Panic! {info}");
        let msg_copy = msg.clone();
        let _ = thread_sync(
            || -> ByondValue {
                if let Err(error) = dm_call_stack_trace(msg_copy) {
                    let second_msg = format!("BYOND error \n {:#?}", error);
                    let panic_guid = Uuid::new_v4();
                    let ts = Utc::now().format("%Y%m%d_%H%M%S").to_string();
                    let file_end = format!("{}_{}", ts, panic_guid);
                    let _ = std::fs::write(
                        format!("data/rustlibs_dm_trace_failed_{}.txt", file_end),
                        second_msg.clone(),
                    );
                }
                Default::default()
            },
            true,
        );
        // GUID may seem pointless but on the off chance we get 2 panics in the same second its needed
        let panic_guid = Uuid::new_v4();
        let ts = Utc::now().format("%Y%m%d_%H%M%S").to_string();
        let file_end = format!("{}_{}", ts, panic_guid);
        let _ = std::fs::write(format!("data/rustlibs_panic_{}.txt", file_end), msg.clone());
    }))
}

/// Runs the body of a function BYOND called, and turns a panic into an error.
/// BYOND then reports the error as a runtime. A panic that reaches BYOND takes down DreamDaemon.
/// Used by `#[rustlibs_macros::bind]`, you shouldn't need to call this yourself.
pub(crate) fn catch_panic<T, E>(call: impl FnOnce() -> Result<T, E>) -> Result<T, E>
where
    E: From<eyre::Report>,
{
    match std::panic::catch_unwind(std::panic::AssertUnwindSafe(call)) {
        Ok(result) => result,
        Err(payload) => Err(eyre::eyre!("Rust panic: {}", panic_message(&payload)).into()),
    }
}

/// Gets the message out of a caught panic.
pub(crate) fn panic_message(payload: &Box<dyn std::any::Any + Send>) -> String {
    if let Some(message) = payload.downcast_ref::<&str>() {
        message.to_string()
    } else if let Some(message) = payload.downcast_ref::<String>() {
        message.clone()
    } else {
        "unknown panic".to_string()
    }
}
