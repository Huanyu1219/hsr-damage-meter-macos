import Foundation
import LiveDomain
import VeritasNetworking
import XCTest

final class LiveTests: XCTestCase {
  private func event(_ json: String) throws -> VeritasEvent {
    guard case .event(let event) = try SocketFrame.decode("42" + json) else {
      throw CocoaError(.coderReadCorrupt)
    }
    return event
  }

  func testHandshakeAndHeartbeat() throws {
    XCTAssertEqual(
      try SocketFrame.decode(#"0{"pingInterval":25000,"pingTimeout":20000}"#),
      .open(heartbeatTimeout: 45))
    XCTAssertEqual(try SocketFrame.decode("2"), .ping(""))
    XCTAssertEqual(try SocketFrame.decode("40{}"), .joined)
    XCTAssertEqual(try SocketFrame.decode("1"), .closed)
    XCTAssertThrowsError(try SocketFrame.decode(#"0{"pingInterval":-1,"pingTimeout":0}"#))
  }

  func testSummonOwnershipSharesAndCumulativeActionValue() async throws {
    let store = LiveCombatStore()
    try await store.consume(
      event(
        #"["OnSetBattleLineup",{"avatars":[{"id":1,"name":"A"},{"id":2,"name":"B"},{"id":3,"name":"C"},{"id":4,"name":"D"}]}]"#
      ))
    await store.consume(.begin)
    // Veritas emits the summoner's UID for servant and snapshot entities.
    for (id, amount, type) in [(1, 40, "Basic"), (1, 20, "Servant"), (2, 40, "Skill")] {
      try await store.consume(
        event(
          "[\"OnDamage\",{\"attacker\":{\"uid\":\(id),\"team\":\"Player\"},\"damage\":\(amount),\"type\":\"\(type)\"}]"
        ))
    }
    var snapshot = await store.currentSnapshot()
    XCTAssertEqual(snapshot.party.count, 4)
    XCTAssertEqual(snapshot.party.map(\.damage), [60, 40, 0, 0])
    XCTAssertEqual(DamageFormatting.ratio(snapshot.party[0].damage, to: snapshot.total), 0.6)
    XCTAssertNil(snapshot.dpa)
    for av in [0, 10, 10, 25] {
      try await store.consume(event("[\"OnTurnBegin\",{\"action_value\":\(av)}]"))
      if av == 0 {
        let zero = await store.currentSnapshot()
        XCTAssertNil(zero.dpa)
      }
    }
    snapshot = await store.currentSnapshot()
    XCTAssertEqual(snapshot.actionValue, 25)
    XCTAssertEqual(snapshot.dpa, 4)
    try await store.consume(event(#"["OnBattleEnd",{"total_damage":100,"action_value":40}]"#))
    snapshot = await store.currentSnapshot()
    XCTAssertEqual(snapshot.dpa, 2.5)
    await store.consume(.actionValue(50))
    snapshot = await store.currentSnapshot()
    XCTAssertEqual(snapshot.actionValue, 40)
    await store.reset()
    snapshot = await store.currentSnapshot()
    XCTAssertNil(snapshot.actionValue)
    XCTAssertNil(snapshot.dpa)
  }

  func testActionValueValidationAndIncompleteEfficiency() async throws {
    XCTAssertThrowsError(try event(#"["OnTurnBegin",{"action_value":-1}]"#))
    XCTAssertThrowsError(try event(#"["OnBattleEnd",{"total_damage":1,"action_value":-1}]"#))
    for reason in ["disconnect", "regression", "unknownOwner"] {
      let store = LiveCombatStore()
      try await store.consume(event(#"["OnSetBattleLineup",{"avatars":[{"id":1,"name":"A"}]}]"#))
      await store.consume(.begin)
      await store.consume(.actionValue(10))
      if reason == "disconnect" { await store.disconnected() }
      if reason == "regression" { await store.consume(.actionValue(5)) }
      if reason == "unknownOwner" {
        try await store.consume(
          event(#"["OnDamage",{"attacker":{"uid":99,"team":"Player"},"damage":10}]"#))
        let snapshot = await store.currentSnapshot()
        XCTAssertEqual(snapshot.party.count, 1)
        XCTAssertEqual(snapshot.unassignedDamage, 10)
      }
      let snapshot = await store.currentSnapshot()
      XCTAssertTrue(snapshot.partial)
      XCTAssertNil(snapshot.dpa)
    }
  }

  func testWireDamageTypesAreChineseAndUnknownKeysStayDistinct() {
    let expected = [
      "Basic": "普攻", "Skill": "战技", "Ultimate": "终结技",
      "DoT": "持续伤害", "Additional": "附加伤害", "Follow-Up": "追加攻击",
      "Technique": "秘技", "Break": "击破伤害", "Servant": "忆灵伤害",
      "True": "真实伤害", "Elation": "欢愉伤害", "Assist": "援助攻击", "QTE": "触发攻击",
    ]
    var character = LiveCharacter(id: 1, name: "A")
    character.damageByType = Dictionary(
      uniqueKeysWithValues: expected.keys.map { ($0, Decimal(1)) })
    character.damageByType["FutureA"] = 1
    character.damageByType["FutureB"] = 1
    let categories = DamageBreakdown.categories([character])
    for row in categories { XCTAssertEqual(row.label, expected[row.id] ?? "未知分类") }
    XCTAssertEqual(categories.count, expected.count + 2)
  }

  func testDecimalPreservationAndUnknownEvents() throws {
    guard
      case .damage(let d) = try event(
        #"["OnDamage",{"attacker":{"uid":1413,"team":"Player"},"damage":367648.1990259297}]"#)
    else { return XCTFail() }
    XCTAssertEqual(d.damage, Decimal(string: "367648.1990259297"))
    XCTAssertEqual(try event(#"["OnFutureEvent",{"unknown":1}]"#), .ignored)
    XCTAssertThrowsError(
      try event(#"["OnDamage",{"attacker":{"uid":1,"team":"Player"},"damage":-1}]"#))
  }

  func testSessionAggregationAndSettlement() async throws {
    let store = LiveCombatStore()
    try await store.consume(
      event(#"["OnSetBattleLineup",{"avatars":[{"id":1,"name":"A"},{"id":2,"name":"B"}]}]"#))
    await store.consume(.begin)
    for (id, value) in [(1, "0.1"), (2, "0.2"), (1, "0.3")] {
      try await store.consume(
        event(
          "[\"OnDamage\",{\"attacker\":{\"uid\":\(id),\"team\":\"Player\"},\"damage\":\(value)}]"))
    }
    await store.consume(.end(Decimal(string: "0.6")!))
    let snapshot = await store.currentSnapshot()
    XCTAssertEqual(snapshot.total, Decimal(string: "0.6"))
    XCTAssertEqual(snapshot.characters.map(\.id), [1, 2])
    XCTAssertEqual(snapshot.characters[0].damage, Decimal(string: "0.4"))
    XCTAssertEqual(snapshot.highest, Decimal(string: "0.3"))
    XCTAssertFalse(snapshot.partial)
    XCTAssertFalse(snapshot.mismatch)
    XCTAssertFalse(snapshot.active)
  }

  func testReconnectAndMidBattleArePartial() async throws {
    let store = LiveCombatStore()
    try await store.consume(
      event(#"["OnDamage",{"attacker":{"uid":1,"team":"Player"},"damage":1}]"#))
    var snapshot = await store.currentSnapshot()
    XCTAssertTrue(snapshot.partial)
    await store.consume(.end(2))
    snapshot = await store.currentSnapshot()
    XCTAssertTrue(snapshot.mismatch)
    try await store.consume(event(#"["OnSetBattleLineup",{"avatars":[{"id":1,"name":"A"}]}]"#))
    await store.consume(.begin)
    await store.disconnected()
    snapshot = await store.currentSnapshot()
    XCTAssertTrue(snapshot.partial)
    XCTAssertEqual(snapshot.total, 0)
  }

  func testIgnoresEnemyDamageAndResets() async throws {
    let store = LiveCombatStore()
    try await store.consume(
      event(#"["OnDamage",{"attacker":{"uid":1,"team":"Enemy"},"damage":123}]"#))
    var snapshot = await store.currentSnapshot()
    XCTAssertEqual(snapshot.eventCount, 0)
    await store.reset()
    snapshot = await store.currentSnapshot()
    XCTAssertEqual(snapshot.characters, [])
    XCTAssertFalse(snapshot.active)
  }
}
