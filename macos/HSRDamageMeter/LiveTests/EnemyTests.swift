import Foundation
import LiveDomain
import VeritasNetworking
import XCTest

final class EnemyTests: XCTestCase {
  private func send(_ json: String, to store: LiveCombatStore) async throws {
    guard case .event(let event) = try SocketFrame.decode("42" + json) else { return XCTFail() }
    await store.consume(event)
  }

  func testEnemyInstancesHPFormationDefeatAndReset() async throws {
    let store = LiveCombatStore()
    await store.consume(.begin)
    try await send(
      #"["OnStatChange",{"entity":{"uid":1,"team":"Enemy"},"property":{"type":"CurrentHP","value":55.5}}]"#,
      to: store)
    for uid in [1, 2] {
      try await send(
        "[\"OnInitializeEnemy\",{\"enemy\":{\"id\":1002011,\"uid\":\(uid),\"name\":\"冰锋\",\"base_stats\":{\"properties\":{\"MaxHP\":100,\"CurrentHP\":100}}}}]",
        to: store)
    }
    var result = await store.currentSnapshot()
    XCTAssertEqual(result.enemies.count, 2)
    XCTAssertEqual(result.enemies.map(\.hp), [55.5, 100])
    try await send(
      #"["OnUpdateTeamFormation",{"team":"Enemy","entities":[{"uid":2,"team":"Enemy"}]}]"#,
      to: store)
    try await send(
      #"["OnTurnBegin",{"action_value":10,"turn_owner":{"uid":2,"team":"Enemy"}}]"#, to: store)
    result = await store.currentSnapshot()
    XCTAssertEqual(result.actingEnemy, 2)
    XCTAssertEqual(result.enemies.map(\.onField), [false, true])
    try await send(#"["OnEntityDefeated",{"entity_defeated":{"uid":2,"team":"Enemy"}}]"#, to: store)
    result = await store.currentSnapshot()
    XCTAssertTrue(result.enemies[1].defeated)
    XCTAssertEqual(result.enemies[1].hp, 0)
    XCTAssertNil(result.actingEnemy)
    try await send(
      #"["OnStatChange",{"entity":{"uid":2,"team":"Enemy"},"property":{"type":"CurrentHP","value":80}}]"#,
      to: store)
    result = await store.currentSnapshot()
    XCTAssertFalse(result.enemies[1].defeated)
    await store.disconnected()
    result = await store.currentSnapshot()
    XCTAssertTrue(result.enemies.allSatisfy(\.stale))
    await store.consume(.end(0))
    try await send(
      #"["OnStatChange",{"entity":{"uid":2,"team":"Enemy"},"property":{"type":"CurrentHP","value":40}}]"#,
      to: store)
    result = await store.currentSnapshot()
    XCTAssertEqual(result.enemies[1].hp, 80)
    await store.reset()
    result = await store.currentSnapshot()
    XCTAssertTrue(result.enemies.isEmpty)
  }
}
