import Foundation
import LiveDomain

@MainActor enum PreviewFactory {
  static func snapshot() -> LiveSnapshot {
    var value = LiveSnapshot()
    value.characters = [
      LiveCharacter(
        id: 1310, name: "流萤", damage: Decimal(string: "4820130.25")!, hits: 18, maxHit: 482000),
      LiveCharacter(
        id: 1225, name: "忘归人", damage: Decimal(string: "1510870.50")!, hits: 11, maxHit: 160000),
      LiveCharacter(
        id: 1309, name: "知更鸟", damage: Decimal(string: "894000.12")!, hits: 12, maxHit: 92000),
      LiveCharacter(
        id: 1409, name: "风堇", damage: Decimal(string: "653000.30")!, hits: 8, maxHit: 81000),
    ]
    for index in value.characters.indices {
      value.characters[index].damageByType = ["Normal": value.characters[index].damage]
    }
    value.total = value.characters.reduce(0) { $0 + $1.damage }
    value.highest = 482000
    value.elapsed = 83
    value.actionValue = 250
    value.eventCount = 49
    value.active = true
    value.partial = false
    value.enemies = [
      LiveEnemy(id: 1, templateID: 1_002_011, name: "冰锋", hp: 55000, maxHP: 100000),
      LiveEnemy(id: 2, templateID: 1_002_011, name: "冰锋", hp: 20000, maxHP: 100000),
    ]
    value.actingEnemy = 1
    return value
  }

  static func connectedLiveSession() -> AppModel {
    let model = AppModel()
    model.demo = true
    model.snapshot = snapshot()
    model.status = .connected
    model.version = "0.2.52 · 演示"
    return model
  }

  static func disconnected() -> AppModel { AppModel() }
  static func ready() -> AppModel {
    let model = AppModel()
    model.status = .connected
    return model
  }
  static func largeDamageNumbers() -> AppModel {
    let model = connectedLiveSession()
    model.snapshot.characters = [
      LiveCharacter(
        id: 1310, name: "流萤", damage: 9_223_372_036_854_775_807, hits: 1,
        maxHit: 9_223_372_036_854_775_807)
    ]
    model.snapshot.characters[0].damageByType = ["Unknown": model.snapshot.characters[0].damage]
    model.snapshot.total = model.snapshot.characters[0].damage
    model.snapshot.highest = model.snapshot.total
    return model
  }
}
