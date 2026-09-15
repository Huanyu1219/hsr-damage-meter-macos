import Foundation

public struct VeritasEnemy: Decodable, Sendable, Equatable {
  public struct Stats: Decodable, Sendable, Equatable {
    public let properties: [String: Decimal]
  }
  public let id: UInt32
  public let uid: UInt32
  public let name: String
  public let baseStats: Stats
  enum CodingKeys: String, CodingKey {
    case id, uid, name
    case baseStats = "base_stats"
  }
}

public struct VeritasEnemyStat: Decodable, Sendable, Equatable {
  public struct Property: Decodable, Sendable, Equatable {
    public let type: String
    public let value: Decimal
  }
  public let entity: VeritasDamage.Entity
  public let property: Property
}
