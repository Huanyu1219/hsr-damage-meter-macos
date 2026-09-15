import LiveDomain
import SwiftUI

enum AppSpacing {
  static let xs: CGFloat = 4
  static let sm: CGFloat = 8
  static let md: CGFloat = 12
  static let lg: CGFloat = 16
  static let row: CGFloat = 20
  static let xl: CGFloat = 24
  static let xxl: CGFloat = 32
}

enum AppRadius {
  static let small: CGFloat = 6
  static let control: CGFloat = 8
  static let card: CGFloat = 12
  static let largeCard: CGFloat = 16
}

enum CharacterStyle {
  static func accent(_ id: UInt32) -> Color {
    switch CharacterCatalog.element(for: id) {
    case "Physical": return .gray
    case "Fire": return .red
    case "Ice": return .blue
    case "Thunder": return Color(red: 0.75, green: 0.32, blue: 0.82)
    case "Wind": return .teal
    case "Quantum": return Color(red: 0.40, green: 0.28, blue: 0.80)
    case "Imaginary": return Color(red: 0.80, green: 0.64, blue: 0.18)
    default: return .gray
    }
  }
}

struct CardSurface: ViewModifier {
  func body(content: Content) -> some View {
    content.padding(AppSpacing.row)
      .background(
        Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: AppRadius.card))
  }
}

extension View {
  func cardSurface() -> some View { modifier(CardSurface()) }
}
