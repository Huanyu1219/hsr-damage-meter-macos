import Foundation
import SQLite3
import VeritasNetworking
import XCTest

@testable import LiveDomain

final class HistoryMaintenanceTests: XCTestCase {
  func testRetentionAndCascadeProtectRunningBattle() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("history.sqlite")
    let db = try BattleHistoryDatabase(url: url)
    let old = UUID()
    let recent = UUID()
    let running = UUID()
    for (id, days, status) in [
      (old, 100, "completed"), (recent, 1, "incomplete"), (running, 100, "running"),
    ] {
      var record = BattleRecord(
        id: id, startedAt: Date().addingTimeInterval(-Double(days) * 86400),
        status: status, collectorVersion: "test", snapshot: LiveSnapshot())
      guard
        case .event(.damage(let damage)) = try SocketFrame.decode(
          #"42["OnDamage",{"attacker":{"uid":1,"team":"Player"},"damage":1}]"#)
      else { return XCTFail() }
      record.events = [SavedDamage(sequence: 1, elapsed: 1, event: damage)]
      try db.save(record)
    }
    try db.delete(ids: nil, before: Date().addingTimeInterval(-30 * 86400))
    XCTAssertNil(try db.load(id: old))
    XCTAssertNotNil(try db.load(id: recent))
    XCTAssertNotNil(try db.load(id: running))
    try db.delete(ids: [recent, running])
    XCTAssertNil(try db.load(id: recent))
    XCTAssertNotNil(try db.load(id: running))
    try db.delete(ids: nil)
    var handle: OpaquePointer?
    XCTAssertEqual(sqlite3_open(url.path, &handle), SQLITE_OK)
    defer { sqlite3_close(handle) }
    var stmt: OpaquePointer?
    XCTAssertEqual(
      sqlite3_prepare_v2(handle, "SELECT count(*) FROM damage_events", -1, &stmt, nil), SQLITE_OK)
    defer { sqlite3_finalize(stmt) }
    XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW)
    XCTAssertEqual(sqlite3_column_int(stmt, 0), 1)
  }

  func testHighVolumeSessionsReconnectAndDeleteDoesNotResurrect() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = LiveCombatStore()
    await store.enableHistory(at: directory.appendingPathComponent("history.sqlite"))
    guard
      case .event(let lineup) = try SocketFrame.decode(
        #"42["OnSetBattleLineup",{"avatars":[{"id":1407,"name":"遐蝶"}]}]"#),
      case .event(let damage) = try SocketFrame.decode(
        #"42["OnDamage",{"attacker":{"uid":1407,"team":"Player"},"damage":0.125,"type":"Servant"}]"#
      )
    else { return XCTFail() }
    for index in 0..<20 {
      await store.consume(lineup)
      await store.consume(.begin)
      for _ in 0..<1000 { await store.consume(damage) }
      if index.isMultiple(of: 2) {
        await store.disconnected()
        await store.consume(.connected("0.2.52"))
      }
      await store.consume(.end(125))
    }
    let rows = try await store.history()
    XCTAssertEqual(rows.count, 20)
    XCTAssertEqual(rows.filter { $0.status == "incomplete" }.count, 10)
    XCTAssertTrue(rows.allSatisfy { $0.total == 125 })
    try await store.deleteHistory()
    await store.reset()
    _ = await store.currentSnapshot()
    let remaining = try await store.history()
    XCTAssertTrue(remaining.isEmpty)
  }
}
