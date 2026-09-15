import LiveDomain
import SwiftUI

struct LiveView: View {
  @Environment(\.openWindow) private var openWindow
  @Bindable var model: AppModel
  @State private var confirmReset = false
  @State private var selectedID: UInt32?

  var body: some View {
    Group {
      ScrollView {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
          header
          if let message = model.gameData.message {
            Text(message).font(.caption).foregroundStyle(.secondary)
              .accessibilityLabel("数据更新：\(message)")
          }
          if let message = model.historyMessage {
            InlineStatusBanner(message: message, warning: true)
          }

          ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.lg) { metrics }.frame(minWidth: 560)
            VStack(spacing: AppSpacing.md) { metrics }
          }
          if !model.snapshot.characters.isEmpty {
            contributions
            EnemySection(
              snapshot: model.snapshot, data: model.gameData,
              connected: model.status == .connected || model.demo)
            if model.snapshot.partial {
              InlineStatusBanner(message: "本场数据不完整", warning: true)
            }
            if model.snapshot.mismatch, let total = model.snapshot.collectorTotal {
              InlineStatusBanner(
                message: "结算校验未通过：\(total.description)", warning: true
              )
            }
          }
        }.padding(AppSpacing.xl).frame(maxWidth: .infinity, alignment: .leading)
      }.background(Color(nsColor: .windowBackgroundColor))
    }
    .frame(minWidth: 900, minHeight: 620)
    .confirmationDialog("重置当前显示？", isPresented: $confirmReset) {
      Button("重置", role: .destructive) { model.reset() }
    } message: {
      Text("只清除本机统计，后续数据将标记为不完整。")
    }
  }

  private var selected: LiveCharacter? {
    model.snapshot.characters.first { $0.id == selectedID }
  }

  @ViewBuilder private var metrics: some View {
    HeroMetricCard(
      title: "全队总伤害", value: DamageFormatting.compact(model.snapshot.total),
      detail: "", precise: model.snapshot.total.description)
    HeroMetricCard(
      title: "队伍 DPS",
      value: DamageFormatting.dps(model.snapshot.total, elapsed: model.snapshot.elapsed),
      detail: "平均每秒伤害", precise: "按本机接收时长估算")
    HeroMetricCard(
      title: "队伍 DPA", value: model.snapshot.dpa.map(DamageFormatting.compact) ?? "—",
      detail: model.snapshot.actionValue.map { "行动值 \(DamageFormatting.compact($0))" } ?? "行动值 —",
      precise: "全队总伤害 ÷ 累计行动值；数据不完整时不计算")
  }

  private var contributions: some View {
    VStack(alignment: .leading, spacing: AppSpacing.lg) {
      HStack {
        Text("队伍伤害占比").font(.headline)
        Spacer()
        Text(
          model.snapshot.ended
            ? "战斗已结束" : model.status == .connected || model.demo ? "进行中" : "连接已中断"
        )
        .font(.caption).foregroundStyle(.secondary)
      }
      HStack(alignment: .top, spacing: AppSpacing.lg) {
        TeamShareChart(snapshot: model.snapshot, selection: $selectedID)
          .frame(maxWidth: .infinity)
        VStack(alignment: .leading, spacing: AppSpacing.md) {
          CharacterDamageTable(snapshot: model.snapshot, selection: $selectedID)
          DamageTypeTable(snapshot: model.snapshot, selected: selected)
        }.frame(width: 440)
      }
      if model.snapshot.unassignedDamage > 0 {
        LabeledContent("未归属伤害", value: model.snapshot.unassignedDamage.description)
          .font(.caption)
      }

    }.frame(maxWidth: .infinity)
  }

  private var header: some View {
    HStack(spacing: AppSpacing.lg) {
      ConnectionBadge(status: model.status, demo: model.demo)
      Text(DamageFormatting.duration(model.snapshot.elapsed)).font(.subheadline.monospacedDigit())
        .foregroundStyle(.secondary).help("本机观察时长")
      Spacer()
      Button("历史") { openWindow(id: "history") }
      Button(model.overlay.visible ? "隐藏浮窗" : "显示浮窗") {
        if model.overlay.visible { model.overlay.hide() } else { model.overlay.show(model: model) }
      }
      Toggle(
        "鼠标穿透",
        isOn: Binding(
          get: { model.overlay.clickThrough },
          set: { model.overlay.setClickThrough($0) }
        )
      ).toggleStyle(.switch)
        .help("仅影响浮窗；可随时在此关闭，恢复浮窗拖动和点击")
      Button(model.gameData.updating ? "检查更新中…" : "更新最新数据") {
        Task { await model.gameData.update() }
      }.disabled(model.gameData.updating)
      if !model.demo { Button("重新连接") { model.reconnect() } }
      Button("重置", systemImage: "arrow.counterclockwise") {
        if model.snapshot.eventCount > 0 { confirmReset = true } else { model.reset() }
      }
    }.controlSize(.small)
  }
}

#Preview("Live") { LiveView(model: PreviewFactory.connectedLiveSession()) }
#Preview("离线") { LiveView(model: PreviewFactory.disconnected()) }
#Preview("等待战斗") { LiveView(model: PreviewFactory.ready()) }
#Preview("大数值 / 最小窗口") {
  LiveView(model: PreviewFactory.largeDamageNumbers()).frame(width: 900, height: 620)
}
