import Foundation
import SQLite3
import VeritasNetworking
import XCTest

@testable import LiveDomain

final class HistoryTests: XCTestCase {
  func testHistoryPaginationAndOrder() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = LiveCombatStore()
    await store.enableHistory(at: directory.appendingPathComponent("history.sqlite"))
    for _ in 0..<53 {
      try await start(store)
      try await damage(store)
      await store.consume(.end(Decimal(string: "0.1")!))
    }
    let first = try await store.history()
    let second = try await store.history(offset: 50)
    XCTAssertEqual(first.count, 50)
    XCTAssertEqual(second.count, 3)
    XCTAssertTrue(Set(first.map(\.id)).isDisjoint(with: Set(second.map(\.id))))
    let oldest = try await store.history(oldestFirst: true)
    XCTAssertEqual(oldest.first?.id, second.last?.id)
  }
  private func send(_ json: String, to store: LiveCombatStore) async throws {
    guard case .event(let event) = try SocketFrame.decode("42" + json) else { return XCTFail() }
    await store.consume(event)
  }
  private func start(_ store: LiveCombatStore) async throws {
    try await send(
      #"["OnSetBattleLineup",{"avatars":[{"id":1407,"name":"遐蝶"},{"id":1413,"name":"长夜月"}]}]"#,
      to: store)
    await store.consume(.begin)
  }
  private func damage(_ store: LiveCombatStore, amount: String = "0.1") async throws {
    try await send(
      "[\"OnDamage\",{\"attacker\":{\"uid\":1407,\"team\":\"Player\"},\"damage\":\(amount),\"type\":\"Servant\"}]",
      to: store)
  }

  func testCompletedBattleRoundtripAndRawDecimalEvents() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("history.sqlite")
    let store = LiveCombatStore()
    await store.enableHistory(at: url)
    await store.consume(.connected("0.2.52"))
    try await start(store)
    for _ in 0..<260 { try await damage(store) }
    await store.consume(.actionValue(100))
    await store.consume(.end(26, actionValue: 100))
    await store.consume(.end(26, actionValue: 100))  // Idempotent settlement.
    let live = await store.currentSnapshot()
    let records = try await store.history(search: "遐蝶")
    XCTAssertEqual(records.count, 1)
    let id = try XCTUnwrap(records.first?.id)
    let saved = try await store.historyDetail(id: id, includeEvents: true)
    let full = try XCTUnwrap(saved)
    XCTAssertEqual(full.snapshot.total, live.total)
    XCTAssertEqual(full.snapshot.dpa, live.dpa)
    XCTAssertEqual(full.snapshot.characters, live.characters)
    XCTAssertEqual(full.events.count, 260)
    XCTAssertEqual(full.events.reduce(Decimal(0)) { $0 + $1.event.damage }, 26)
    XCTAssertEqual(full.events.map(\.sequence), Array(1...260))
    XCTAssertEqual(full.collectorVersion, "0.2.52")
    XCTAssertNil(full.gameVersion)
    XCTAssertEqual(full.status, "completed")
    let trend = try await store.historyTrend(id: id)
    XCTAssertEqual(trend.last?.cumulative, 26)
    let reopened = LiveCombatStore()
    await reopened.enableHistory(at: url)
    let loaded = try await reopened.historyDetail(id: id)
    XCTAssertEqual(loaded?.snapshot.total, 26)
    XCTAssertEqual(loaded?.snapshot.characters.count, 2)
    XCTAssertEqual(
      try JSONDecoder().decode(BattleRecord.self, from: JSONEncoder().encode(full)).events.count,
      260)
  }

  func testDuplicateEndPreservesSettlement() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = LiveCombatStore()
    await store.enableHistory(at: directory.appendingPathComponent("history.sqlite"))
    try await start(store)
    try await damage(store, amount: "10")
    await store.consume(.end(10, actionValue: 100))
    let first = await store.currentSnapshot()
    let rows = try await store.history()
    let id = try XCTUnwrap(rows.first?.id)
    let original = try await store.historyDetail(id: id)
    try await Task.sleep(for: .milliseconds(20))
    await store.consume(.end(10, actionValue: 100))
    let duplicate = await store.currentSnapshot()
    let saved = try await store.historyDetail(id: id)
    XCTAssertEqual(duplicate, first)
    XCTAssertEqual(saved?.endedAt, original?.endedAt)
    XCTAssertEqual(saved?.snapshot.elapsed, first.elapsed)
  }

  func testFailedFinalCheckpointRetriesWithoutBufferedEvents() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("history.sqlite")
    let store = LiveCombatStore()
    await store.enableHistory(at: url)
    try await start(store)
    for _ in 0..<128 { try await damage(store, amount: "1") }
    try await Task.sleep(for: .milliseconds(550))
    let running = await store.currentSnapshot()
    XCTAssertEqual(running.eventCount, 128)
    let initialError = await store.historyError
    XCTAssertNil(initialError)
    _ = try await store.history()  // Await asynchronous persistence before fault injection.
    var db: OpaquePointer?
    XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
    defer { sqlite3_close(db) }
    var statement: OpaquePointer?
    XCTAssertEqual(
      sqlite3_prepare_v2(
        db, "SELECT id FROM sessions WHERE status='running'", -1,
        &statement, nil), SQLITE_OK)
    defer { sqlite3_finalize(statement) }
    XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
    let bytes = try XCTUnwrap(sqlite3_column_text(statement, 0))
    let id = try XCTUnwrap(UUID(uuidString: String(cString: bytes)))
    XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
    // Fail the actual SQLite write after damage has already been committed.
    XCTAssertEqual(
      sqlite3_exec(
        db,
        """
        CREATE TRIGGER fail_settlement BEFORE UPDATE ON sessions
        WHEN NEW.status != 'running'
        BEGIN SELECT RAISE(ABORT, 'injected settlement failure'); END;
        """, nil, nil, nil), SQLITE_OK)
    await store.consume(.end(128, actionValue: 100))
    _ = try await store.history()
    let failed = await store.historyError
    XCTAssertNotNil(failed)
    let settled = await store.currentSnapshot()
    XCTAssertEqual(sqlite3_exec(db, "DROP TRIGGER fail_settlement", nil, nil, nil), SQLITE_OK)
    try await Task.sleep(for: .milliseconds(550))
    _ = await store.currentSnapshot()
    let saved = try await store.historyDetail(id: id, includeEvents: true)
    let error = await store.historyError
    XCTAssertNil(error)
    XCTAssertEqual(saved?.status, "completed")
    XCTAssertEqual(saved?.snapshot.actionValue, 100)
    XCTAssertEqual(saved?.snapshot.elapsed, settled.elapsed)
    XCTAssertNotNil(saved?.endedAt)
    XCTAssertEqual(saved?.events.count, 128)
    await store.reset()
    let afterReset = try await store.history()
    XCTAssertEqual(afterReset.count, 1)
    XCTAssertEqual(afterReset.first?.status, "completed")
  }

  func testResetInterruptionAndCrashRecovery() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("history.sqlite")
    let store = LiveCombatStore()
    await store.enableHistory(at: url)
    try await start(store)
    try await damage(store)
    await store.reset()
    var rows = try await store.history()
    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows[0].status, "interrupted")
    let partial = try await store.historyDetail(id: rows[0].id)
    XCTAssertTrue(partial?.snapshot.partial == true)
    try await start(store)
    for _ in 0..<128 { try await damage(store) }
    _ = try await store.history()  // Wait until the running checkpoint is durable before reopening.
    let reopened = LiveCombatStore()
    await reopened.enableHistory(at: url)
    rows = try await reopened.history()
    XCTAssertEqual(rows.count, 2)
    XCTAssertTrue(rows.allSatisfy { $0.status == "interrupted" })
    let missing = try await reopened.history(search: "不存在")
    XCTAssertTrue(missing.isEmpty)
    let injected = try await reopened.history(search: "' OR 1=1 --")
    XCTAssertTrue(injected.isEmpty)
  }
}
