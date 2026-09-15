import AppKit
import Charts
import LiveDomain
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
  let model: AppModel
  @State private var rows: [BattleSummary] = []
  @State private var search = ""
  @State private var oldestFirst = false
  @State private var loading = false
  @State private var hasMore = false
  @State private var error: String?
  @State private var requestID = UUID()
  @State private var selected: Set<UUID> = []
  @State private var pendingDelete: [UUID]?
  @State private var confirmDelete = false
  @State private var pendingRetention = 0
  @State private var confirmRetention = false
  @AppStorage("history.retentionDays") private var retention = 0

  var body: some View {
    NavigationStack {
      List(selection: $selected) {
        if let error { Text(error).foregroundStyle(.orange) }
        if rows.isEmpty && !loading && error == nil {
          Text(search.isEmpty ? "暂无战斗记录" : "没有匹配的记录").foregroundStyle(.secondary)
        }
        ForEach(oldestFirst ? ["更早", "昨天", "今天"] : ["今天", "昨天", "更早"], id: \.self) { group in
          let records = rows.filter { dateGroup($0.startedAt) == group }
          if !records.isEmpty {
            Section(group) {
              ForEach(records) { record in
                NavigationLink(value: record.id) {
                  VStack(alignment: .leading, spacing: 8) {
                    HStack {
                      Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                      Spacer()
                      Text(DamageFormatting.duration(record.duration)).foregroundStyle(.secondary)
                    }.font(.caption)
                    HStack {
                      Text(DamageFormatting.compact(record.total)).font(.title2.weight(.semibold))
                      Spacer()
                      Text(DamageFormatting.dps(record.total, elapsed: record.duration))
                    }.monospacedDigit()
                    Text(record.partyNames).font(.subheadline).lineLimit(2)
                    if record.status != "completed" {
                      Text("数据不完整").font(.caption).foregroundStyle(.orange)
                    }
                  }.padding(.vertical, 8)
                }
                .tag(record.id)
                .contextMenu {
                  Button("删除此记录", role: .destructive) {
                    pendingDelete = [record.id]
                    confirmDelete = true
                  }
                }
              }
            }
          }
        }
        if hasMore { Button("加载更多") { Task { await load(more: true) } }.disabled(loading) }
        if loading { ProgressView().controlSize(.small) }
      }
      .navigationTitle("战斗历史")
      .searchable(text: $search, prompt: "搜索角色")
      .toolbar {
        Menu("管理") {
          Button("删除所选（\(selected.count)）", role: .destructive) {
            pendingDelete = Array(selected)
            confirmDelete = true
          }.disabled(selected.isEmpty)
          Button("清空历史", role: .destructive) {
            pendingDelete = nil
            confirmDelete = true
          }
          Menu("保留期限") {
            ForEach([0, 7, 30, 90, 365], id: \.self) { days in
              Button((days == 0 ? "永久保留" : "\(days) 天") + (retention == days ? " ✓" : "")) {
                pendingRetention = days
                if days == 0 { Task { await applyRetention() } } else { confirmRetention = true }
              }
            }
          }
        }
        Toggle("最早优先", isOn: $oldestFirst)
        Button("刷新", systemImage: "arrow.clockwise") { Task { await load() } }.disabled(loading)
      }
      .navigationDestination(for: UUID.self) { id in HistoryDetailView(id: id, model: model) }
      .task(id: "\(search)-\(oldestFirst)") { await load() }
      .confirmationDialog("删除战斗记录？", isPresented: $confirmDelete) {
        Button(pendingDelete == nil ? "清空历史" : "删除所选记录", role: .destructive) {
          Task {
            do {
              try await model.store.deleteHistory(ids: pendingDelete)
              selected = []
              await load()
            } catch { self.error = "删除失败，请重试" }
          }
        }
      } message: {
        Text("记录和原始事件将永久删除，当前进行中的战斗不受影响。")
      }
      .confirmationDialog("启用自动清理？", isPresented: $confirmRetention) {
        Button("保留最近 \(pendingRetention) 天", role: .destructive) {
          Task { await applyRetention() }
        }
      } message: {
        Text("立即删除超期历史，之后自动清理。删除后无法恢复。")
      }
    }.frame(minWidth: 900, minHeight: 620)
  }

  private func dateGroup(_ date: Date) -> String {
    if Calendar.current.isDateInToday(date) { return "今天" }
    return Calendar.current.isDateInYesterday(date) ? "昨天" : "更早"
  }

  private func load(more: Bool = false) async {
    let token = UUID()
    requestID = token
    loading = true
    defer { if requestID == token { loading = false } }
    error = nil
    if !more {
      rows = []
      selected = []
    }
    do {
      let page = try await model.store.history(
        search: search, oldestFirst: oldestFirst, offset: rows.count)
      guard requestID == token, !Task.isCancelled else { return }
      rows.append(contentsOf: page)
      hasMore = page.count == 50
    } catch {
      guard requestID == token else { return }
      self.error = "无法读取历史记录"
    }
  }

  private func applyRetention() async {
    do {
      try await model.store.setHistoryRetention(days: pendingRetention)
      retention = pendingRetention
      await load()
    } catch { self.error = "无法修改保留期限，原设置未更改" }
  }
}

struct HistoryDetailView: View {
  let id: UUID
  let model: AppModel
  @State private var record: BattleRecord?
  @State private var selectedID: UInt32?
  @State private var error: String?
  @State private var exporting = false
  @State private var trend: [DamageTrendPoint] = []

  init(id: UUID, model: AppModel, preview: BattleRecord? = nil) {
    self.id = id
    self.model = model
    _record = State(initialValue: preview)
  }

  var body: some View {
    ScrollView {
      if let record {
        VStack(alignment: .leading, spacing: 20) {
          Text(record.startedAt.formatted(date: .abbreviated, time: .standard)).foregroundStyle(
            .secondary)
          HStack {
            HeroMetricCard(
              title: "全队总伤害", value: DamageFormatting.compact(record.snapshot.total), detail: "")
            HeroMetricCard(
              title: "队伍 DPS",
              value: DamageFormatting.dps(record.snapshot.total, elapsed: record.snapshot.elapsed),
              detail: DamageFormatting.duration(record.snapshot.elapsed))
            HeroMetricCard(
              title: "队伍 DPA", value: record.snapshot.dpa.map(DamageFormatting.compact) ?? "—",
              detail: "")
          }
          if record.status != "completed" || record.snapshot.partial {
            InlineStatusBanner(message: "本场数据不完整", warning: true)
          }
          if !record.rawEventsComplete {
            InlineStatusBanner(message: "原始事件保存不完整", warning: true)
          }
          HStack(alignment: .top, spacing: 16) {
            TeamShareChart(snapshot: record.snapshot, selection: $selectedID)
            VStack(spacing: 12) {
              CharacterDamageTable(snapshot: record.snapshot, selection: $selectedID)
              DamageTypeTable(
                snapshot: record.snapshot,
                selected: record.snapshot.characters.first { $0.id == selectedID })
            }.frame(width: 440)
          }
          EnemySection(snapshot: record.snapshot, data: model.gameData, connected: false)
          if !trend.isEmpty {
            Text("累计伤害").font(.headline)
            Chart(trend) { point in
              LineMark(
                x: .value("秒", point.elapsed),
                y: .value("累计伤害", NSDecimalNumber(decimal: point.cumulative).doubleValue))
            }.frame(height: 180).chartXAxisLabel("秒")
          }
        }.padding(24)
      } else if error == nil {
        ProgressView().padding()
      }
      if let error { Text(error).foregroundStyle(.orange).padding() }
    }
    .navigationTitle("战斗详情")
    .toolbar { Button("导出 JSON") { Task { await export() } }.disabled(record == nil || exporting) }
    .task {
      guard record == nil else { return }
      do {
        record = try await model.store.historyDetail(id: id)
        trend = try await model.store.historyTrend(id: id)
        if record == nil { error = "记录不存在" }
      } catch { self.error = "无法读取战斗详情" }
    }
  }

  private func export() async {
    exporting = true
    defer { exporting = false }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.nameFieldStringValue = "battle-\(id.uuidString).json"
    guard await panel.begin() == .OK, let url = panel.url else { return }
    do {
      guard let full = try await model.store.historyDetail(id: id, includeEvents: true) else {
        return
      }
      try await Task.detached(priority: .utility) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(full).write(to: url, options: .atomic)
      }.value
    } catch { self.error = "导出失败" }
  }
}

#Preview("历史") { HistoryView(model: PreviewFactory.ready()) }
#Preview("战斗详情") {
  let record = BattleRecord(
    id: UUID(), startedAt: Date(), status: "completed",
    collectorVersion: "0.2.52", snapshot: PreviewFactory.snapshot())
  HistoryDetailView(id: record.id, model: PreviewFactory.connectedLiveSession(), preview: record)
}
