public enum ProtocolEvent: Equatable, Sendable {
  case hello(Hello)
  case combatStart(CombatStart)
  case combatEnd(CombatEnd)
  case partyUpdate(PartyUpdate)
  case damage(Damage)

  public var type: String {
    switch self {
    case .hello: "hello"
    case .combatStart: "combat_start"
    case .combatEnd: "combat_end"
    case .partyUpdate: "party_update"
    case .damage: "damage"
    }
  }
}
