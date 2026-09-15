import Foundation
import SQLite3
import VeritasNetworking
import XCTest

@testable import LiveDomain

final class HistoryRobustnessTests: XCTestCase {
  func testNormalQuitFlushesSmallUnsettledBattle() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("history.sqlite")
    let store = LiveCombatStore()
    await store.enableHistory(at: url)
    await store.consume(.begin)
    guard
      case .event(let event) = try SocketFrame.decode(
        #"42["OnDamage",{"attacker":{"uid":1407,"team":"Player"},"damage":3}]"#)
    else { return XCTFail() }
    await store.consume(event)
    await store.finishHistory()
    let reopened = LiveCombatStore()
    await reopened.enableHistory(at: url)
    let rows = try await reopened.history()
    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows.first?.total, 3)
    XCTAssertEqual(rows.first?.status, "interrupted")
  }

  func testLockedDatabaseDoesNotBlockCombatAndEventuallySaves() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("history.sqlite")
    let store = LiveCombatStore()
    await store.enableHistory(at: url)
    var lock: OpaquePointer?
    XCTAssertEqual(sqlite3_open(url.path, &lock), SQLITE_OK)
    defer { sqlite3_close(lock) }
    XCTAssertEqual(sqlite3_exec(lock, "BEGIN IMMEDIATE", nil, nil, nil), SQLITE_OK)
    guard
      case .event(let damage) = try SocketFrame.decode(
        #"42["OnDamage",{"attacker":{"uid":1407,"team":"Player"},"damage":1}]"#)
    else { return XCTFail() }
    let start = ContinuousClock.now
    await store.consume(.begin)
    for _ in 0..<512 { await store.consume(damage) }
    let live = await store.currentSnapshot()
    XCTAssertEqual(live.total, 512)
    XCTAssertLessThan(start.duration(to: .now), .milliseconds(400))
    // Let the first write fail, then send another burst while retry backoff is active.
    _ = try await store.history()
    let error = await store.historyError
    XCTAssertNotNil(error)
    let retryStart = ContinuousClock.now
    for _ in 0..<512 { await store.consume(damage) }
    XCTAssertLessThan(retryStart.duration(to: .now), .milliseconds(400))
    XCTAssertEqual(sqlite3_exec(lock, "COMMIT", nil, nil, nil), SQLITE_OK)
    await store.consume(.end(1024))
    try await Task.sleep(for: .milliseconds(550))
    let rows = try await store.history()
    let id = try XCTUnwrap(rows.first?.id)
    let saved = try await store.historyDetail(id: id, includeEvents: true)
    XCTAssertEqual(saved?.snapshot.total, 1024)
    XCTAssertEqual(saved?.events.count, 1024)
  }

  func testEmptyBlobThrowsInsteadOfCrashingAndFutureSchemaIsPreserved() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("history.sqlite")
    let database = try BattleHistoryDatabase(url: url)
    let id = UUID()
    try database.save(
      BattleRecord(
        id: id, startedAt: Date(), status: "running",
        collectorVersion: "test", snapshot: LiveSnapshot()))
    var db: OpaquePointer?
    XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
    defer { sqlite3_close(db) }
    XCTAssertEqual(sqlite3_exec(db, "UPDATE sessions SET snapshot=x''", nil, nil, nil), SQLITE_OK)
    XCTAssertThrowsError(try database.load(id: id))
    XCTAssertEqual(
      sqlite3_exec(
        db,
        "UPDATE app_settings SET value='999' WHERE key='schema_version'", nil, nil, nil), SQLITE_OK)
    XCTAssertThrowsError(try BattleHistoryDatabase(url: url))
    var statement: OpaquePointer?
    XCTAssertEqual(
      sqlite3_prepare_v2(db, "SELECT status FROM sessions", -1, &statement, nil), SQLITE_OK)
    defer { sqlite3_finalize(statement) }
    XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
    let status = try XCTUnwrap(sqlite3_column_text(statement, 0))
    XCTAssertEqual(String(cString: status), "running")
  }
}
