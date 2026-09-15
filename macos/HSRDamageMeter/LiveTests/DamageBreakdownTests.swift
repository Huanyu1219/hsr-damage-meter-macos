import Foundation
import LiveDomain
import VeritasNetworking
import XCTest

final class DamageBreakdownTests: XCTestCase {
  func testRawAndMissingTypesRemainDistinctAndSumToDamage() async throws {
    let store = LiveCombatStore()
    let frames = [
      #"42["OnDamage",{"attacker":{"uid":1413,"team":"Player"},"damage":0.1,"type":"Servant"}]"#,
      #"42["OnDamage",{"attacker":{"uid":1413,"team":"Player"},"damage":0.2,"type":"FutureCategory"}]"#,
      #"42["OnDamage",{"attacker":{"uid":1409,"team":"Player"},"damage":0.3}]"#,
      #"42["OnDamage",{"attacker":{"uid":1413,"team":"Player"},"damage":0.4,"type":"Servant"}]"#,
    ]
    for frame in frames {
      guard case .event(let event) = try SocketFrame.decode(frame) else { return XCTFail() }
      await store.consume(event)
    }
    let snapshot = await store.currentSnapshot()
    let rows = DamageBreakdown.categories(snapshot.characters)
    XCTAssertEqual(rows.map(\.id), ["Servant", "", "FutureCategory"])
    XCTAssertEqual(rows.reduce(0) { $0 + $1.damage }, snapshot.total)
    XCTAssertEqual(rows[0].damage, Decimal(string: "0.5"))
    let selected = snapshot.characters.first { $0.id == 1413 }!
    XCTAssertEqual(
      DamageBreakdown.categories([selected]).reduce(0) { $0 + $1.damage }, selected.damage)
    await store.reset()
    let cleared = await store.currentSnapshot()
    XCTAssertTrue(DamageBreakdown.categories(cleared.characters).isEmpty)
  }
}
