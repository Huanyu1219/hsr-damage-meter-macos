use hsr_collector_protocol::bridge::protocol::{Envelope, Event};

const SESSION: &str = include_str!("../../protocol/fixtures/sample_session.jsonl");

#[test]
fn shared_fixtures_roundtrip_and_preserve_order() {
    let mut previous = 0;
    for line in SESSION.lines() {
        let envelope: Envelope = serde_json::from_str(line).unwrap();
        assert!(envelope.sequence > previous);
        previous = envelope.sequence;
        let decoded: Envelope = serde_json::from_str(&envelope.to_json().unwrap()).unwrap();
        assert_eq!(envelope, decoded);
    }
    assert_eq!(previous, 7);
}

#[test]
fn rejects_shared_invalid_corpus() {
    let cases: serde_json::Value =
        serde_json::from_str(include_str!("../../protocol/fixtures/invalid_events.json")).unwrap();
    for case in cases.as_array().unwrap() {
        assert!(
            serde_json::from_value::<Envelope>(case["event"].clone()).is_err(),
            "{}",
            case["name"]
        );
    }
}

#[test]
fn preserves_unknown_fields_as_absent_values_and_exact_maximum() {
    let envelope: Envelope = serde_json::from_str(SESSION.lines().nth(5).unwrap()).unwrap();
    let Event::Damage(damage) = envelope.event else {
        panic!("expected damage")
    };
    assert_eq!(damage.amount, i64::MAX);
    assert_eq!(damage.source_character_id, None);
    assert_eq!(damage.is_crit, None);
}

#[test]
fn additive_fields_are_accepted() {
    let mut value: serde_json::Value =
        serde_json::from_str(SESSION.lines().next().unwrap()).unwrap();
    value["future"] = true.into();
    value["payload"]["future"] = true.into();
    assert!(serde_json::from_value::<Envelope>(value).is_ok());
}

#[test]
fn nonfinite_timestamps_cannot_be_constructed() {
    let envelope: Envelope = serde_json::from_str(SESSION.lines().next().unwrap()).unwrap();
    assert!(Envelope::new(1, f64::NAN, envelope.event.clone()).is_err());
    assert!(Envelope::new(1, f64::INFINITY, envelope.event).is_err());
}

#[test]
fn serde_serialization_revalidates_mutated_envelopes() {
    let mut envelope: Envelope = serde_json::from_str(SESSION.lines().next().unwrap()).unwrap();
    envelope.timestamp = f64::NAN;
    assert!(serde_json::to_string(&envelope).is_err());
    envelope.timestamp = 0.0;
    envelope.sequence = 0;
    assert!(serde_json::to_string(&envelope).is_err());
}
