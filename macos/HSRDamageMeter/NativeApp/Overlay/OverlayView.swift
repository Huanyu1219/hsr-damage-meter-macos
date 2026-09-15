import LiveDomain
import SwiftUI

struct OverlayView: View {
  let model: AppModel
  let controller: OverlayController
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @State private var hovering = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Circle().fill(model.status == .connected || model.demo ? Color.green : .gray)
          .frame(width: 6, height: 6)
          .accessibilityLabel(model.status.rawValue)
        Text(DamageFormatting.duration(model.snapshot.elapsed))
          .font(.caption).monospacedDigit().foregroundStyle(.secondary)
        Spacer()
        HStack(spacing: 10) {
          Menu {
            ForEach(OverlayMode.allCases) { mode in
              Button(mode.label) { controller.setMode(mode) }
            }
            Button("鼠标穿透") { controller.setClickThrough(true) }
          } label: {
            Image(systemName: "ellipsis")
          }
          .menuStyle(.borderlessButton).fixedSize().help("浮窗选项")
          Button {
            controller.hide()
          } label: {
            Image(systemName: "xmark")
          }
          .buttonStyle(.plain).help("隐藏浮窗")
        }.opacity(hovering ? 1 : 0)
          .allowsHitTesting(hovering).accessibilityHidden(!hovering)
      }.frame(height: 18)

      if model.snapshot.party.isEmpty {
        Text(model.status == .connected ? "等待战斗" : "未连接")
          .font(.caption).foregroundStyle(.secondary)
      } else {
        ForEach(model.snapshot.party.prefix(4)) { character in
          row(character)
        }
      }
      Spacer(minLength: 0)
      if controller.mode != .minimal {
        Divider()
        HStack {
          VStack(alignment: .leading, spacing: 3) {
            Text("总伤害").font(.caption2).foregroundStyle(.secondary)
            Text(DamageFormatting.compact(model.snapshot.total)).fontWeight(.semibold)
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 3) {
            Text("DPA").font(.caption2).foregroundStyle(.secondary)
            Text(model.snapshot.dpa.map(DamageFormatting.compact) ?? "—")
          }
        }.font(.subheadline).monospacedDigit()
      }
      if model.snapshot.partial && model.snapshot.eventCount > 0 {
        Text("数据不完整").font(.caption2).foregroundStyle(.orange)
      }
    }.padding(14)
      .frame(width: controller.mode.size.width, height: controller.mode.size.height)
      .background {
        RoundedRectangle(cornerRadius: 14)
          .fill(Color(nsColor: .windowBackgroundColor).opacity(reduceTransparency ? 1 : 0.94))
      }
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12)))
      .preferredColorScheme(.dark)
      .onHover { hovering = $0 }
  }

  private func row(_ character: LiveCharacter) -> some View {
    HStack(spacing: 9) {
      if controller.mode != .minimal {
        CharacterPortrait(id: character.id, name: character.name, size: 32)
      }
      VStack(alignment: .leading, spacing: 5) {
        HStack {
          Text(character.name).lineLimit(1)
          Spacer(minLength: 4)
          Text(
            DamageFormatting.ratio(character.damage, to: model.snapshot.total).formatted(
              .percent.precision(.fractionLength(1)))
          )
          .foregroundStyle(CharacterStyle.accent(character.id))
        }.font(.subheadline).monospacedDigit()
        if controller.mode != .minimal {
          DamageBar(
            value: DamageFormatting.ratio(character.damage, to: model.snapshot.total),
            accent: CharacterStyle.accent(character.id))
          HStack {
            Text(DamageFormatting.compact(character.damage))
            Spacer()
            if controller.mode == .detailed {
              Text(DamageFormatting.dps(character.damage, elapsed: model.snapshot.elapsed))
            }
          }.font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }
      }
    }.accessibilityElement(children: .combine)
  }
}

#Preview {
  OverlayView(model: PreviewFactory.connectedLiveSession(), controller: OverlayController())
}
