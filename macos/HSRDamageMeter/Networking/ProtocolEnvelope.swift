import Foundation

public enum ProtocolError: Error, Equatable {
  case incompatibleVersion(Int)
  case unsupportedEvent(String)
  case invalidValue(String)
}

public struct ProtocolEnvelope: Codable, Equatable, Sendable {
  public static let supportedVersion = 1
  public let protocolVersion: Int
  public let sequence: Int64
  /// Unix epoch seconds, including fractional seconds. Not a monotonic clock.
  public let timestamp: Double
  public let event: ProtocolEvent

  private enum CodingKeys: String, CodingKey {
    case protocolVersion, type, sequence, timestamp, payload
  }

  public init(sequence: Int64, timestamp: Double, event: ProtocolEvent) throws {
    self.protocolVersion = Self.supportedVersion
    self.sequence = sequence
    self.timestamp = timestamp
    self.event = event
    try validate()
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let version = try c.decode(Int.self, forKey: .protocolVersion)
    guard version == Self.supportedVersion else { throw ProtocolError.incompatibleVersion(version) }
    let type = try c.decode(String.self, forKey: .type)
    let event: ProtocolEvent
    switch type {
    case "hello": event = .hello(try c.decode(Hello.self, forKey: .payload))
    case "combat_start": event = .combatStart(try c.decode(CombatStart.self, forKey: .payload))
    case "combat_end": event = .combatEnd(try c.decode(CombatEnd.self, forKey: .payload))
    case "party_update": event = .partyUpdate(try c.decode(PartyUpdate.self, forKey: .payload))
    case "damage": event = .damage(try c.decode(Damage.self, forKey: .payload))
    default: throw ProtocolError.unsupportedEvent(type)
    }
    try self.init(
      sequence: c.decode(Int64.self, forKey: .sequence),
      timestamp: c.decode(Double.self, forKey: .timestamp), event: event)
  }

  public func encode(to encoder: any Encoder) throws {
    try validate()
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(protocolVersion, forKey: .protocolVersion)
    try c.encode(event.type, forKey: .type)
    try c.encode(sequence, forKey: .sequence)
    try c.encode(timestamp, forKey: .timestamp)
    switch event {
    case .hello(let p): try c.encode(p, forKey: .payload)
    case .combatStart(let p): try c.encode(p, forKey: .payload)
    case .combatEnd(let p): try c.encode(p, forKey: .payload)
    case .partyUpdate(let p): try c.encode(p, forKey: .payload)
    case .damage(let p): try c.encode(p, forKey: .payload)
    }
  }

  private func validate() throws {
    guard sequence > 0, timestamp.isFinite, timestamp >= 0 else {
      throw ProtocolError.invalidValue("sequence or timestamp")
    }
    switch event {
    case .damage(let d):
      guard d.amount >= 0,
        [d.sourceEntityId, d.sourceCharacterId, d.targetEntityId, d.skillId].allSatisfy({
          $0 == nil || $0! >= 0
        })
      else {
        throw ProtocolError.invalidValue("damage or identity")
      }
    case .partyUpdate(let p):
      guard
        p.members.allSatisfy({ $0.entityId >= 0 && ($0.characterId == nil || $0.characterId! >= 0) }
        )
      else {
        throw ProtocolError.invalidValue("party identity")
      }
    default: break
    }
  }
}
