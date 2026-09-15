import Foundation
import LiveDomain
import VeritasNetworking
import XCTest

final class TransportTests: XCTestCase {
  func testMockWebSocketEndToEnd() async throws {
    guard ProcessInfo.processInfo.environment["HSR_MOCK_TEST"] == "1" else {
      throw XCTSkip(
        "Run scripts/mock-veritas.py and set HSR_MOCK_TEST=1 for loopback transport integration")
    }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = LiveCombatStore()
    await store.enableHistory(at: directory.appendingPathComponent("history.sqlite"))
    let client = VeritasClient(
      port: UInt16(ProcessInfo.processInfo.environment["HSR_MOCK_PORT"] ?? "1305") ?? 1305)
    let task = Task {
      await client.run(receive: { await store.consume($0) }, status: { _ in })
    }
    try await Task.sleep(for: .seconds(4))
    let snapshot = await store.currentSnapshot()
    task.cancel()
    await client.disconnect()
    await task.value
    XCTAssertEqual(snapshot.eventCount, 3)
    XCTAssertEqual(snapshot.total, Decimal(string: "479993.5740259297"))
    XCTAssertEqual(snapshot.characters.first?.name, "流萤")
    XCTAssertFalse(snapshot.partial)
    XCTAssertFalse(snapshot.mismatch)
    XCTAssertTrue(snapshot.ended)
    // Restart the receiver against the same collector endpoint; prior combat must not accumulate.
    let reconnected = Task {
      await client.run(receive: { await store.consume($0) }, status: { _ in })
    }
    try await Task.sleep(for: .seconds(4))
    let again = await store.currentSnapshot()
    reconnected.cancel()
    await client.disconnect()
    await reconnected.value
    XCTAssertEqual(again.total, snapshot.total)
    XCTAssertEqual(again.eventCount, 3)
    XCTAssertFalse(again.partial)
    let rows = try await store.history()
    XCTAssertEqual(rows.count, 2)
    XCTAssertTrue(rows.allSatisfy { $0.status == "completed" && $0.total == snapshot.total })
  }
}
