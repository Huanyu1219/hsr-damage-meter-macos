import Foundation
import XCTest

@testable import HSRProtocol

final class ProtocolTests: XCTestCase {
  private var fixtures: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("protocol/fixtures")
  }

  private func lines() throws -> [Data] {
    try String(contentsOf: fixtures.appendingPathComponent("sample_session.jsonl"), encoding: .utf8)
      .split(separator: "\n").map { Data($0.utf8) }
  }

  func testSharedFixturesRoundtripAndOrder() throws {
    let events = try lines().map { try JSONDecoder().decode(ProtocolEnvelope.self, from: $0) }
    XCTAssertEqual(events.count, 7)
    XCTAssertEqual(events.map(\.sequence), Array(1...7).map(Int64.init))
    for event in events {
      XCTAssertEqual(
        try JSONDecoder().decode(ProtocolEnvelope.self, from: JSONEncoder().encode(event)), event)
    }
  }

  func testRejectsSharedInvalidCorpus() throws {
    let data = try Data(contentsOf: fixtures.appendingPathComponent("invalid_events.json"))
    let cases = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    for item in cases {
      let event = try JSONSerialization.data(withJSONObject: XCTUnwrap(item["event"]))
      XCTAssertThrowsError(
        try JSONDecoder().decode(ProtocolEnvelope.self, from: event), "\(item["name"] ?? "")")
    }
  }

  func testExactInt64AndUnknownObservations() throws {
    let event = try JSONDecoder().decode(ProtocolEnvelope.self, from: lines()[5])
    guard case .damage(let damage) = event.event else { return XCTFail("Expected damage") }
    XCTAssertEqual(damage.amount, Int64.max)
    XCTAssertNil(damage.sourceCharacterId)
    XCTAssertNil(damage.isCrit)
  }

  func testVersionMismatchIsDistinct() throws {
    var value = try XCTUnwrap(JSONSerialization.jsonObject(with: lines()[0]) as? [String: Any])
    value["protocolVersion"] = 2
    XCTAssertThrowsError(
      try JSONDecoder().decode(
        ProtocolEnvelope.self, from: JSONSerialization.data(withJSONObject: value))
    ) {
      XCTAssertEqual($0 as? ProtocolError, .incompatibleVersion(2))
    }
  }

  func testAdditiveFieldsAreAccepted() throws {
    var value = try XCTUnwrap(JSONSerialization.jsonObject(with: lines()[0]) as? [String: Any])
    value["future"] = true
    var payload = try XCTUnwrap(value["payload"] as? [String: Any])
    payload["future"] = true
    value["payload"] = payload
    XCTAssertNoThrow(
      try JSONDecoder().decode(
        ProtocolEnvelope.self, from: JSONSerialization.data(withJSONObject: value)))
  }

  func testRejectsNonfiniteTimestamp() throws {
    let event = try JSONDecoder().decode(ProtocolEnvelope.self, from: lines()[0]).event
    XCTAssertThrowsError(try ProtocolEnvelope(sequence: 1, timestamp: .nan, event: event))
    XCTAssertThrowsError(try ProtocolEnvelope(sequence: 1, timestamp: .infinity, event: event))
  }
}
