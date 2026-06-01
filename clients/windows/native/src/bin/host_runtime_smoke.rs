use std::{
    io::{Read, Write},
    net::TcpStream,
    thread,
    time::Duration,
};

use crafting_table_windows_native::host_runtime::{HostRuntimeService, RuntimeState};

fn main() {
    let service = HostRuntimeService::default();
    let view = service.start().expect("Host Runtime starts");
    assert_eq!(view.state, RuntimeState::Running, "Host Runtime is running");

    let response = read_health().expect("GET /health succeeds");
    assert!(
        response.starts_with("HTTP/1.1 200 OK") || response.starts_with("HTTP/1.0 200 OK"),
        "unexpected /health response: {response}"
    );
    assert!(
        response.contains("ct-codex-remote-server"),
        "health response does not identify CTCore remote server: {response}"
    );

    service.stop().expect("Host Runtime stops");
    println!("Host Runtime smoke passed.");
}

fn read_health() -> std::io::Result<String> {
    let mut last_error = None;
    for _ in 0..10 {
        match TcpStream::connect("127.0.0.1:3765") {
            Ok(mut stream) => {
                stream.set_read_timeout(Some(Duration::from_secs(5)))?;
                stream.write_all(
                    b"GET /health HTTP/1.1\r\nHost: 127.0.0.1:3765\r\nConnection: close\r\n\r\n",
                )?;

                let mut response = String::new();
                stream.read_to_string(&mut response)?;
                return Ok(response);
            }
            Err(error) => {
                last_error = Some(error);
                thread::sleep(Duration::from_millis(100));
            }
        }
    }

    Err(last_error.unwrap_or_else(|| {
        std::io::Error::new(
            std::io::ErrorKind::TimedOut,
            "timed out connecting to 127.0.0.1:3765",
        )
    }))
}
