import Foundation

public struct Hello: Codable, Equatable, Sendable {
  public let collector: String
  public let collectorVersion: String
  public let gameVersion: String
  public let capabilities: [String]
}

public struct CombatStart: Codable, Equatable, Sendable {
  public let sessionId: UUID
}

public struct CombatEnd: Codable, Equatable, Sendable {
  public let sessionId: UUID
  public let reason: String?
}

public struct PartyMember: Codable, Equatable, Sendable {
  public let entityId: Int64
  public let characterId: Int64?
  public let name: String?
}

public struct PartyUpdate: Codable, Equatable, Sendable {
  public let members: [PartyMember]
}

public struct Damage: Codable, Equatable, Sendable {
  public let sessionId: UUID
  public let sourceEntityId: Int64?
  public let sourceCharacterId: Int64?
  public let targetEntityId: Int64?
  public let skillId: Int64?
  public let amount: Int64
  public let damageType: String?
  public let isCrit: Bool?
}
