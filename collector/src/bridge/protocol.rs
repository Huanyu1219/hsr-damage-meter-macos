#[path = "payloads.rs"]
mod payloads;
pub use payloads::*;
use serde::{Deserialize, Serialize};

pub const PROTOCOL_VERSION: u8 = 1;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload", rename_all = "snake_case")]
pub enum Event {
    Hello(Hello),
    CombatStart(CombatStart),
    CombatEnd(CombatEnd),
    PartyUpdate(PartyUpdate),
    Damage(Damage),
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(try_from = "WireEnvelope", rename_all = "camelCase")]
pub struct Envelope {
    protocol_version: u8,
    pub sequence: i64,
    pub timestamp: f64,
    #[serde(flatten)]
    pub event: Event,
}

impl Serialize for Envelope {
    fn serialize<S: serde::Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        self.validate().map_err(serde::ser::Error::custom)?;
        #[derive(Serialize)]
        #[serde(rename_all = "camelCase")]
        struct ValidatedEnvelope<'a> {
            protocol_version: u8,
            sequence: i64,
            timestamp: f64,
            #[serde(flatten)]
            event: &'a Event,
        }
        ValidatedEnvelope {
            protocol_version: self.protocol_version,
            sequence: self.sequence,
            timestamp: self.timestamp,
            event: &self.event,
        }
        .serialize(serializer)
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct WireEnvelope {
    protocol_version: u8,
    sequence: i64,
    timestamp: f64,
    #[serde(flatten)]
    event: Event,
}

impl TryFrom<WireEnvelope> for Envelope {
    type Error = String;
    fn try_from(wire: WireEnvelope) -> Result<Self, Self::Error> {
        if wire.protocol_version != PROTOCOL_VERSION {
            return Err("unsupported protocolVersion".into());
        }
        Self::new(wire.sequence, wire.timestamp, wire.event)
    }
}

impl Envelope {
    pub fn new(sequence: i64, timestamp: f64, event: Event) -> Result<Self, String> {
        let envelope = Self {
            protocol_version: PROTOCOL_VERSION,
            sequence,
            timestamp,
            event,
        };
        envelope.validate()?;
        Ok(envelope)
    }

    pub fn validate(&self) -> Result<(), String> {
        if self.sequence < 1 || !self.timestamp.is_finite() || self.timestamp < 0.0 {
            return Err("invalid envelope sequence or timestamp".into());
        }
        let valid = match &self.event {
            Event::PartyUpdate(party) => party
                .members
                .iter()
                .all(|m| m.entity_id >= 0 && m.character_id.is_none_or(|id| id >= 0)),
            Event::Damage(d) => {
                d.amount >= 0
                    && [
                        d.source_entity_id,
                        d.source_character_id,
                        d.target_entity_id,
                        d.skill_id,
                    ]
                    .iter()
                    .all(|id| id.is_none_or(|id| id >= 0))
            }
            _ => true,
        };
        if valid {
            Ok(())
        } else {
            Err("negative damage or identity".into())
        }
    }

    /// Validate even after a caller changes a public field.
    pub fn to_json(&self) -> Result<String, String> {
        self.validate()?;
        serde_json::to_string(self).map_err(|e| e.to_string())
    }
}
