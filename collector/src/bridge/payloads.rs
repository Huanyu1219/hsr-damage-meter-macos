use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Hello {
    pub collector: String,
    pub collector_version: String,
    pub game_version: String,
    pub capabilities: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CombatStart {
    #[serde(deserialize_with = "deserialize_session_id")]
    pub session_id: Uuid,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CombatEnd {
    #[serde(deserialize_with = "deserialize_session_id")]
    pub session_id: Uuid,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PartyMember {
    pub entity_id: i64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub character_id: Option<i64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PartyUpdate {
    pub members: Vec<PartyMember>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Damage {
    #[serde(deserialize_with = "deserialize_session_id")]
    pub session_id: Uuid,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source_entity_id: Option<i64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source_character_id: Option<i64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub target_entity_id: Option<i64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub skill_id: Option<i64>,
    pub amount: i64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub damage_type: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub is_crit: Option<bool>,
}

// Match the canonical hyphenated UUID representation required by the schema.
fn deserialize_session_id<'de, D: serde::Deserializer<'de>>(
    deserializer: D,
) -> Result<Uuid, D::Error> {
    let value = String::deserialize(deserializer)?;
    let uuid = Uuid::parse_str(&value).map_err(serde::de::Error::custom)?;
    if value.len() != 36 || !uuid.hyphenated().to_string().eq_ignore_ascii_case(&value) {
        return Err(serde::de::Error::custom(
            "sessionId must be a hyphenated UUID",
        ));
    }
    Ok(uuid)
}
