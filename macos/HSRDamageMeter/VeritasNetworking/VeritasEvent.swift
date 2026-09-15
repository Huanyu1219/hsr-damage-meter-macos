import Foundation

public struct VeritasAvatar: Decodable, Sendable, Equatable {
  public let id: UInt32
  public let name: String
}

public struct VeritasDamage: Codable, Sendable, Equatable {
  public struct Entity: Codable, Sendable, Equatable {
    public let uid: UInt32
    public let team: String
  }
  public let attacker: Entity
  public let damage: Decimal
  /// Upstream classification label; missing values remain unclassified.
  public let type: String?
}

public enum VeritasEvent: Sendable, Equatable {
  case connected(String)
  case lineup([VeritasAvatar])
  case begin
  case damage(VeritasDamage)
  case actionValue(Decimal, owner: VeritasDamage.Entity? = nil)
  case enemy(VeritasEnemy)
  case enemyStat(VeritasEnemyStat)
  case enemyFormation([VeritasDamage.Entity])
  case defeated(VeritasDamage.Entity)
  case turnEnded
  case end(Decimal, actionValue: Decimal? = nil)
  case collectorError
  case ignored
}

public enum SocketFrame: Sendable, Equatable {
  case open(heartbeatTimeout: Double)
  case ping(String)
  case joined
  case event(VeritasEvent)
  case closed
  case ignored

  public static func decode(_ text: String) throws -> SocketFrame {
    struct Open: Decodable {
      let pingInterval: Double
      let pingTimeout: Double
    }
    struct Version: Decodable { let version: String }
    struct Lineup: Decodable { let avatars: [VeritasAvatar] }
    struct End: Decodable {
      let totalDamage: Decimal
      let actionValue: Decimal?
      enum CodingKeys: String, CodingKey {
        case totalDamage = "total_damage"
        case actionValue = "action_value"
      }
    }
    struct Turn: Decodable {
      let actionValue: Decimal
      let owner: VeritasDamage.Entity?
      enum CodingKeys: String, CodingKey {
        case actionValue = "action_value"
        case owner = "turn_owner"
      }
    }
    struct EnemyPacket: Decodable { let enemy: VeritasEnemy }
    struct Formation: Decodable {
      let team: String
      let entities: [VeritasDamage.Entity]
    }
    struct Defeat: Decodable {
      let entityDefeated: VeritasDamage.Entity
      enum CodingKeys: String, CodingKey { case entityDefeated = "entity_defeated" }
    }
    struct EventContainer: Decodable {
      let event: VeritasEvent
      init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        let name = try c.decode(String.self)
        switch name {
        case "Connected": event = .connected(try c.decode(Version.self).version)
        case "OnSetBattleLineup": event = .lineup(try c.decode(Lineup.self).avatars)
        case "OnBattleBegin": event = .begin
        case "OnDamage":
          let damage = try c.decode(VeritasDamage.self)
          guard damage.damage >= 0, !damage.damage.isNaN else {
            throw CocoaError(.coderInvalidValue)
          }
          event = .damage(damage)
        case "OnTurnBegin":
          let turn = try c.decode(Turn.self)
          let value = turn.actionValue
          guard value >= 0, !value.isNaN else { throw CocoaError(.coderInvalidValue) }
          event = .actionValue(value, owner: turn.owner)
        case "OnInitializeEnemy":
          event = .enemy(try c.decode(EnemyPacket.self).enemy)
        case "OnStatChange":
          event = .enemyStat(try c.decode(VeritasEnemyStat.self))
        case "OnUpdateTeamFormation":
          let formation = try c.decode(Formation.self)
          event = formation.team == "Enemy" ? .enemyFormation(formation.entities) : .ignored
        case "OnEntityDefeated":
          event = .defeated(try c.decode(Defeat.self).entityDefeated)
        case "OnTurnEnd": event = .turnEnded
        case "OnBattleEnd":
          let end = try c.decode(End.self)
          let total = end.totalDamage
          if let value = end.actionValue, value < 0 || value.isNaN {
            throw CocoaError(.coderInvalidValue)
          }
          guard total >= 0, !total.isNaN else { throw CocoaError(.coderInvalidValue) }
          event = .end(total, actionValue: end.actionValue)
        case "Error": event = .collectorError
        default: event = .ignored
        }
      }
    }
    guard text.utf8.count <= 4_194_304 else { throw CocoaError(.coderReadCorrupt) }
    if text.hasPrefix("0") {
      let open = try JSONDecoder().decode(Open.self, from: Data(text.dropFirst().utf8))
      let timeout = (open.pingInterval + open.pingTimeout) / 1000
      guard timeout.isFinite, timeout > 0, timeout <= 120 else {
        throw CocoaError(.coderInvalidValue)
      }
      return .open(heartbeatTimeout: timeout)
    }
    if text.hasPrefix("2") { return .ping(String(text.dropFirst())) }
    if text == "1" || text.hasPrefix("41") || text.hasPrefix("44") { return .closed }
    if text.hasPrefix("40") { return .joined }
    if text.hasPrefix("42[") {
      return .event(
        try JSONDecoder().decode(EventContainer.self, from: Data(text.dropFirst(2).utf8)).event)
    }
    return .ignored
  }
}
