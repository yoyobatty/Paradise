use crate::jobs;
use byondapi::value::ByondValue;
use eyre::Result;
use serde::{Deserialize, Serialize};
use std::cell::RefCell;
use std::collections::{BTreeMap, HashMap};
use std::time::Duration;
// ----------------------------------------------------------------------------
// Interface

#[derive(Serialize, Deserialize)]
struct Response {
    status_code: u16,
    headers: HashMap<String, String>,
    body: Option<String>,
}

// If the response can be deserialized -> success.
// If the response can't be deserialized -> failure or WIP.

// ----------------------------------------------------------------------------
// Shared HTTP client state

const VERSION: &str = env!("CARGO_PKG_VERSION");
const PKG_NAME: &str = env!("CARGO_PKG_NAME");

thread_local! {
    pub static HTTP_CLIENT: RefCell<Option<ureq::Agent>> = RefCell::new(Some(new_client()));
}

fn new_client() -> ureq::Agent {
    ureq::Agent::config_builder()
        .timeout_global(Some(Duration::from_secs(5)))
        // Error statuses like 404 come back to BYOND like any other response
        .http_status_as_error(false)
        .build()
        .new_agent()
}

// ----------------------------------------------------------------------------
// Request construction and execution

struct RequestPrep {
    client: ureq::Agent,
    method: String,
    url: String,
    headers: Vec<(String, String)>,
    body: Vec<u8>,
}

fn construct_request(
    method: &str,
    url: &str,
    body: &str,
    headers: &Option<BTreeMap<String, String>>,
) -> Option<RequestPrep> {
    HTTP_CLIENT.with(|cell| {
        let borrow = cell.borrow_mut();
        match &*borrow {
            Some(client) => {
                let mut final_headers =
                    vec![("User-Agent".to_string(), format!("{PKG_NAME}/{VERSION}"))];

                if let Some(h) = headers {
                    for (key, value) in h {
                        final_headers.push((key.clone(), value.clone()));
                    }
                }

                Some(RequestPrep {
                    client: client.clone(),
                    method: method.to_string(),
                    url: url.to_string(),
                    headers: final_headers,
                    body: body.as_bytes().to_vec(),
                })
            }

            // If we got here we royally fucked up
            None => None,
        }
    })
}

fn with_headers<B>(
    mut req: ureq::RequestBuilder<B>,
    headers: &[(String, String)],
) -> ureq::RequestBuilder<B> {
    for (key, value) in headers {
        req = req.header(key, value);
    }
    req
}

fn send_request(prep: &RequestPrep) -> Result<ureq::http::Response<ureq::Body>, ureq::Error> {
    let client = &prep.client;
    let url = prep.url.as_str();
    match prep.method.as_str() {
        "post" => with_headers(client.post(url), &prep.headers).send(&prep.body[..]),
        "put" => with_headers(client.put(url), &prep.headers).send(&prep.body[..]),
        "patch" => with_headers(client.patch(url), &prep.headers).send(&prep.body[..]),
        method => {
            let req = match method {
                "delete" => client.delete(url),
                "head" => client.head(url),
                _ => client.get(url),
            };
            let req = with_headers(req, &prep.headers);
            // These only send a body if they were given one
            if prep.body.is_empty() {
                req.call()
            } else {
                req.force_send_body().send(&prep.body[..])
            }
        }
    }
}

fn submit_request(prep: RequestPrep) -> Result<String> {
    // Send the request
    // TODO: this is a sinful hack, rewrite this as soon as the module is stable on live
    let mut response = match send_request(&prep) {
        Ok(r) => r,
        Err(e) => {
            let mut resp = Response {
                status_code: 0,
                headers: HashMap::new(),
                body: None,
            };
            resp.body = Some(e.to_string());
            return Ok(serde_json::to_string(&resp)?);
        }
    };
    let mut resp = Response {
        status_code: response.status().as_u16(),
        headers: HashMap::new(),
        body: None,
    };

    for (key, value) in response.headers() {
        let Ok(value) = value.to_str() else {
            continue;
        };

        resp.headers.insert(key.to_string(), value.to_owned());
    }

    resp.body = Some(response.body_mut().read_to_string()?);

    Ok(serde_json::to_string(&resp)?)
}

// Exported methods
#[byondapi::bind]
fn http_start_client() -> Result<ByondValue> {
    HTTP_CLIENT.with(|cell| cell.replace(Some(new_client())));
    Ok(ByondValue::null())
}

#[byondapi::bind]
fn http_shutdown_client() -> Result<ByondValue> {
    HTTP_CLIENT.with(|cell| cell.replace(None));
    Ok(ByondValue::null())
}

#[byondapi::bind]
fn http_submit_async_request(mut request: ByondValue) -> Result<ByondValue> {
    let method = request.read_var("method")?.get_string()?;
    let url = request.read_var("url")?.get_string()?;
    let body = request.read_var("body")?.get_string()?;

    let headers = request.read_var("headers")?.get_list()?;

    let mut real_headers = None;

    if !headers.is_empty() {
        let mut btm: BTreeMap<String, String> = BTreeMap::new();

        for pair in headers.chunks(2) {
            if let [k, v] = pair {
                let kstr = k.get_string()?;
                let vstr = v.get_string()?;
                btm.insert(kstr, vstr);
            }
        }

        real_headers = Some(btm);
    }

    let req = match construct_request(method.as_str(), url.as_str(), body.as_str(), &real_headers) {
        Some(r) => r,
        None => return Ok(ByondValue::null()),
    };

    // Start the request as a job on a new thread
    let job_id = jobs::start(move || match submit_request(req) {
        Ok(r) => r,
        Err(e) => e.to_string(),
    });

    // Write job id back to BYOND
    request.write_var("id", &ByondValue::new_num(job_id as f32))?;
    request.write_var("in_progress", &ByondValue::new_num(1f32))?;

    Ok(ByondValue::null())
}

#[byondapi::bind]
fn http_check_job(mut request: ByondValue) -> Result<ByondValue> {
    // logging::setup_panic_handler();
    let id = request.read_var("id")?.get_number()? as usize;
    match jobs::check(&id) {
        // Job id exists, check progress
        Some(res) => match res {
            // Request completed, parse it
            Ok(res) => {
                // We are no longer in progress
                request.write_var("in_progress", &ByondValue::new_num(0f32))?;
                request
                    .write_var("error_code", &ByondValue::null())
                    .unwrap();

                // Decode response. A request that failed partway, like reading a body that's too
                // big, gives back its error as plain text, so pass that on like a failed connection.
                let web_response: Response = match serde_json::from_str(&res) {
                    Ok(response) => response,
                    Err(_) => Response {
                        status_code: 0,
                        headers: HashMap::new(),
                        body: Some(res),
                    },
                };
                // We have a response - assemble our HTML datum
                let target_type = ByondValue::new_str("/datum/http_response")?;
                let mut response_datum = ByondValue::builtin_new(target_type, &[])?;

                // Write primitives
                response_datum
                    .write_var(
                        "status_code",
                        &ByondValue::new_num(web_response.status_code as f32),
                    )
                    .unwrap();
                response_datum
                    .write_var("body", &ByondValue::new_str(web_response.body.unwrap())?)?;

                // Headers are more complicated since its an assoc list
                let mut headers_list = ByondValue::new_list().unwrap();
                for header_k in web_response.headers.keys() {
                    // Get the key as a BV
                    let hk_bv = ByondValue::new_str(header_k.to_string())?;

                    // Get the value as a BV
                    let hv = web_response.headers.get(header_k).unwrap();
                    let hv_bv = ByondValue::new_str(hv.to_string())?;

                    headers_list.write_list_index(hk_bv, hv_bv)?;
                }
                response_datum.write_var("headers", &headers_list)?;

                // Send it back
                Ok(response_datum)
            }
            // Request is still being made
            Err(flume::TryRecvError::Empty) => {
                request.write_var("error_code", &ByondValue::new_str(jobs::NO_RESULTS_YET)?)?;
                return Ok(ByondValue::null());
            }
            // Something bad happened during the request
            Err(flume::TryRecvError::Disconnected) => {
                request.write_var("error_code", &ByondValue::new_str(jobs::JOB_PANICKED)?)?;
                request.write_var("in_progress", &ByondValue::new_num(0f32))?;
                return Ok(ByondValue::null());
            }
        },
        // Job id does not exist
        None => {
            request.write_var(
                "error_code",
                &ByondValue::new_str(jobs::NO_SUCH_JOB).unwrap(),
            )?;

            return Ok(ByondValue::null());
        }
    }
}
