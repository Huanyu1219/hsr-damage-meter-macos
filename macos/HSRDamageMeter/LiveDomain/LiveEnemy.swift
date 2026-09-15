import Foundation

public struct LiveEnemy: Codable, Identifiable, Sendable, Equatable {
  public let id: UInt32  // Runtime UID: identical monster templates can appear together.
  public var templateID: UInt32?
  public var name: String
  public var hp: Decimal?
  public var maxHP: Decimal?
  public var defeated = false
  public var onField: Bool?
  public var stale = false
  public init(
    id: UInt32, templateID: UInt32? = nil, name: String = "未知敌人", hp: Decimal? = nil,
    maxHP: Decimal? = nil
  ) {
    self.id = id
    self.templateID = templateID
    self.name = name
    self.hp = hp
    self.maxHP = maxHP
  }
}
