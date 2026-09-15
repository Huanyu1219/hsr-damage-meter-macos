import Foundation

public enum DamageFormatting {
  public static func compact(_ value: Decimal) -> String {
    guard !value.isNaN else { return "—" }
    let magnitude = abs(value)
    let units: [(Decimal, String)] = [
      (1_000_000_000_000, "T"), (1_000_000_000, "B"), (1_000_000, "M"), (1_000, "K"),
    ]
    let (scale, suffix) = units.first { magnitude >= $0.0 } ?? (1, "")
    let scaled = value / scale
    let digits = scale == 1 ? 0 : abs(scaled) >= 100 ? 0 : abs(scaled) >= 10 ? 1 : 2
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = false
    formatter.minimumFractionDigits = digits
    formatter.maximumFractionDigits = digits
    return (formatter.string(from: NSDecimalNumber(decimal: scaled)) ?? "—") + suffix
  }

  public static func ratio(_ value: Decimal, to total: Decimal) -> Double {
    guard total > 0, !value.isNaN, !total.isNaN else { return 0 }
    return min(1, max(0, NSDecimalNumber(decimal: value / total).doubleValue))
  }

  public static func dps(_ damage: Decimal, elapsed: Double) -> String {
    guard elapsed.isFinite, elapsed >= 1 else { return "—" }
    return compact(damage / Decimal(elapsed)) + "/s"
  }

  public static func duration(_ elapsed: Double) -> String {
    guard elapsed.isFinite, elapsed >= 0, elapsed < Double(Int.max) else { return "—" }
    let seconds = Int(elapsed)
    if seconds >= 3600 {
      return String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
  }
}
