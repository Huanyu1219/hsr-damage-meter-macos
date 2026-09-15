import LiveDomain
import SwiftUI
import VeritasNetworking

struct ConnectionBadge: View {
  let status: ConnectionStatus
  var demo = false
  var body: some View {
    Label(
      demo
        ? "演示"
        : status == .connected
          ? "已连接" : status == .connecting ? "连接中" : status == .incompatible ? "版本不兼容" : "未连接",
      systemImage: status == .connected
        ? "circle.fill" : status == .connecting ? "arrow.triangle.2.circlepath" : "circle"
    )
    .font(.caption).foregroundStyle(status == .connected && !demo ? .green : .secondary)
  }
}

struct HeroMetricCard: View {
  let title: String
  let value: String
  let detail: String
  var precise = ""
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    VStack(alignment: .leading, spacing: AppSpacing.md) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text(value).font(.system(size: 28, weight: .semibold)).monospacedDigit()
        .lineLimit(1).minimumScaleFactor(0.65)
        .contentTransition(reduceMotion ? .identity : .numericText())
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: value)
        .help(precise)
      Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
    }.frame(maxWidth: .infinity, alignment: .leading).cardSurface()
      .accessibilityElement(children: .combine)
  }
}

struct CharacterPortrait: View {
  let id: UInt32
  let name: String
  var image: NSImage? = nil
  var size: CGFloat = 40
  var body: some View {
    Group {
      if let image = image ?? PortraitCache.image(id) {
        Image(nsImage: image).resizable().scaledToFill()
      } else {
        Text(String(name.prefix(1))).font(.title3.weight(.medium)).foregroundStyle(
          CharacterStyle.accent(id))
      }
    }
    .frame(width: size, height: size)
    .background(CharacterStyle.accent(id).opacity(0.09))
    .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
    .overlay(
      RoundedRectangle(cornerRadius: AppRadius.control).stroke(
        CharacterStyle.accent(id).opacity(0.2))
    )
    .accessibilityHidden(true)
  }
}

struct DamageBar: View {
  let value: Double
  let accent: Color
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    GeometryReader { geometry in
      Capsule().fill(.quaternary)
        .overlay(alignment: .leading) {
          Capsule().fill(accent.opacity(0.8)).frame(
            width: geometry.size.width * min(1, max(0, value)))
        }
    }.frame(height: 8)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: value)
      .accessibilityHidden(true)
  }
}

struct DamageContributionRow: View {
  let character: LiveCharacter
  let total: Decimal
  let selected: Bool
  let select: () -> Void

  var body: some View {
    Button(action: select) {
      HStack(spacing: AppSpacing.md) {
        CharacterPortrait(id: character.id, name: character.name)
        Text(character.name).font(.body.weight(.medium))
          .lineLimit(1).frame(width: 110, alignment: .leading)
        DamageBar(
          value: DamageFormatting.ratio(character.damage, to: total),
          accent: CharacterStyle.accent(character.id))
        Text(character.damage.formatted(.number.precision(.fractionLength(0...2))))
          .font(.body.weight(.semibold)).monospacedDigit()
          .lineLimit(1).minimumScaleFactor(0.6)
          .frame(width: 170, alignment: .trailing).help(character.damage.description)
        Text(
          DamageFormatting.ratio(character.damage, to: total).formatted(
            .percent.precision(.fractionLength(1)))
        )
        .monospacedDigit().frame(width: 64, alignment: .trailing)
      }.padding(AppSpacing.md)
        .background(
          selected ? CharacterStyle.accent(character.id).opacity(0.07) : .clear,
          in: RoundedRectangle(cornerRadius: AppRadius.control)
        )
        .contentShape(Rectangle())
    }.buttonStyle(.plain)
      .accessibilityLabel(
        "\(character.name)，伤害 \(character.damage.description)"
      )
      .accessibilityAddTraits(selected ? .isSelected : [])
      .help("选择角色，查看精确伤害与本场指标")
  }
}

struct InlineStatusBanner: View {
  let message: String
  var warning = false
  var body: some View {
    Label(message, systemImage: warning ? "exclamationmark.circle" : "info.circle")
      .font(.caption).foregroundStyle(warning ? .orange : .secondary)
      .fixedSize(horizontal: false, vertical: true)
  }
}

struct CharacterInspector: View {
  let character: LiveCharacter
  let snapshot: LiveSnapshot
  var body: some View {
    VStack(alignment: .leading, spacing: AppSpacing.lg) {
      HStack {
        CharacterPortrait(id: character.id, name: character.name)
        VStack(alignment: .leading, spacing: 4) {
          Text(character.name).font(.headline)

        }
      }
      Text(DamageFormatting.compact(character.damage)).font(.title.weight(.semibold))
        .monospacedDigit()
        .textSelection(.enabled).help(character.damage.description)
      LabeledContent(
        "伤害占比",
        value: DamageFormatting.ratio(character.damage, to: snapshot.total).formatted(
          .percent.precision(.fractionLength(1))))
      LabeledContent(
        "DPS", value: DamageFormatting.dps(character.damage, elapsed: snapshot.elapsed))
      Divider()
      Text("精确累计").font(.caption).foregroundStyle(.secondary)
      Text(character.damage.description).font(.caption.monospaced()).textSelection(.enabled)

    }.font(.subheadline).monospacedDigit().cardSurface()
  }
}

@MainActor private enum PortraitCache {
  static var images: [UInt32: NSImage] = [:]
  static var unavailable: Set<UInt32> = []
  static func image(_ id: UInt32) -> NSImage? {
    if let image = images[id] { return image }
    guard !unavailable.contains(id), let url = CharacterCatalog.portraitURL(for: id),
      let image = NSImage(contentsOf: url)
    else {
      unavailable.insert(id)
      return nil
    }
    images[id] = image
    return image
  }
}
