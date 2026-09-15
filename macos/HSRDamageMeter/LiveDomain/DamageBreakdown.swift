import Foundation

public struct DamageCategory: Identifiable, Equatable, Sendable {
  public let id: String
  public let damage: Decimal
  public var label: String {
    switch id {
    case "": "未提供分类"
    case "Normal", "Basic": "普攻"
    case "BPSkill", "Skill": "战技"
    case "Ultra", "Ultimate": "终结技"
    case "QTE": "触发攻击"
    case "DOT", "DoT": "持续伤害"
    case "Pursued", "Additional": "附加伤害"
    case "Maze", "MazeNormal", "Technique": "秘技"
    case "Insert", "Follow-Up": "追加攻击"
    case "ElementDamage", "Break": "击破伤害"
    case "Servant": "忆灵伤害"
    case "TrueDamage", "True": "真实伤害"
    case "ElationDamage", "Elation": "欢愉伤害"
    case "Assist": "援助攻击"
    default: "未知分类"
    }
  }
}

public enum DamageBreakdown {
  public static func categories(_ characters: [LiveCharacter]) -> [DamageCategory] {
    var totals: [String: Decimal] = [:]
    for character in characters {
      for (label, amount) in character.damageByType { totals[label, default: 0] += amount }
    }
    return totals.map { DamageCategory(id: $0.key, damage: $0.value) }.sorted {
      $0.damage == $1.damage ? $0.id < $1.id : $0.damage > $1.damage
    }
  }
}
