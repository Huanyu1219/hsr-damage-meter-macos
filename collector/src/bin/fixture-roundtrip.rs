use hsr_collector_protocol::bridge::protocol::Envelope;
use std::io::{self, BufRead};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    for line in io::stdin().lock().lines() {
        let envelope: Envelope = serde_json::from_str(&line?)?;
        println!("{}", envelope.to_json()?);
    }
    Ok(())
}
