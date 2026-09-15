import LiveDomain
import SwiftUI

/// The leader fills the fixed plot height; labels always show the actual party share.
struct TeamShareChart: View {
  let snapshot: LiveSnapshot
  @Binding var selection: UInt32?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private let plotHeight: CGFloat = 180
  private var highest: Decimal { snapshot.party.map(\.damage).max() ?? 0 }

  var body: some View {
    HStack(alignment: .bottom, spacing: AppSpacing.md) {
      ForEach(snapshot.party) { character in
        Button {
          selection = selection == character.id ? nil : character.id
        } label: {
          VStack(spacing: AppSpacing.sm) {
            Text(DamageFormatting.compact(character.damage))
              .font(.subheadline.weight(.semibold)).monospacedDigit()
              .lineLimit(1).minimumScaleFactor(0.65)
              .help(character.damage.description)
            Text(
              DamageFormatting.ratio(character.damage, to: snapshot.total).formatted(
                .percent.precision(.fractionLength(1)))
            )
            .font(.caption).monospacedDigit().foregroundStyle(.secondary)
            ZStack(alignment: .bottom) {
              RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.4))
              UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6)
                .fill(CharacterStyle.accent(character.id).opacity(0.8))
                .frame(height: plotHeight * DamageFormatting.ratio(character.damage, to: highest))
            }.frame(maxWidth: 80).frame(height: plotHeight)
              .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: character.damage)
              .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: highest)
            CharacterPortrait(id: character.id, name: character.name, size: 36)
            Text(character.name).font(.caption).lineLimit(1)
          }.frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(
              selection == character.id ? CharacterStyle.accent(character.id).opacity(0.1) : .clear,
              in: RoundedRectangle(cornerRadius: AppRadius.control)
            )
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
          .accessibilityLabel(
            "\(character.name)，伤害 \(character.damage.description)，占比 \(DamageFormatting.ratio(character.damage, to: snapshot.total).formatted(.percent))"
          )
          .accessibilityAddTraits(selection == character.id ? .isSelected : [])
      }
    }.cardSurface()
  }
}
