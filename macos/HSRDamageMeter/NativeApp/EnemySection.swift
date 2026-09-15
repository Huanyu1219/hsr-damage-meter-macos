import LiveDomain
import SwiftUI

struct EnemySection: View {
  let snapshot: LiveSnapshot
  let data: GameDataLibrary
  let connected: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("敌人").font(.headline)
      if snapshot.enemies.isEmpty {
        Text("等待敌方数据").font(.subheadline).foregroundStyle(.secondary)
      } else {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), alignment: .leading)], spacing: 12) {
          ForEach(snapshot.enemies) { enemy in
            EnemyCard(
              enemy: enemy, data: data, acting: snapshot.actingEnemy == enemy.id,
              stale: !connected || snapshot.ended)
          }
        }
      }
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct EnemyCard: View {
  let enemy: LiveEnemy
  let data: GameDataLibrary
  let acting: Bool
  let stale: Bool
  @State private var portrait: NSImage?
  private var status: String {
    if stale || enemy.stale { return "最后记录" }
    if enemy.defeated { return "已击败" }
    if enemy.onField == false { return "已离场" }
    if acting { return "行动中" }
    if let hp = enemy.hp { return hp > 0 ? "存活" : "生命耗尽" }
    return "状态未知"
  }
  var body: some View {
    HStack(spacing: 12) {
      Group {
        if let portrait {
          Image(nsImage: portrait).resizable().scaledToFit()
        } else {
          Image(systemName: "photo").font(.title).foregroundStyle(.secondary)
        }
      }.frame(width: 80, height: 90)
      VStack(alignment: .leading, spacing: 8) {
        Text(data.monster(enemy.templateID)?.zh ?? enemy.name).font(.headline).lineLimit(2)
        Text(status).font(.caption).foregroundStyle(enemy.defeated ? .secondary : .primary)
          .help("当前协议提供生命、在场和行动状态，不提供完整增益/减益列表")
        HStack {
          Text(enemy.hp.map(DamageFormatting.compact) ?? "—")
          Text("/").foregroundStyle(.secondary)
          Text(enemy.maxHP.map(DamageFormatting.compact) ?? "—")
        }.font(.subheadline).monospacedDigit()
        if let hp = enemy.hp, let maxHP = enemy.maxHP, maxHP > 0 {
          DamageBar(value: DamageFormatting.ratio(hp, to: maxHP), accent: .red)
        }
      }.frame(maxWidth: .infinity, alignment: .leading)
    }.padding(12)
      .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
      .task(id: "\(enemy.templateID ?? 0)-\(data.version)") {
        portrait = await data.portrait(enemy.templateID)
      }
  }
}
