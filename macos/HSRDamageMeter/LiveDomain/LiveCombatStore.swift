import Foundation
import VeritasNetworking

public struct LiveCharacter: Codable, Identifiable, Sendable, Equatable {
  public let id: UInt32
  public var name: String
  public var damage: Decimal = 0
  public var isPartyMember = true
  public var hits: Int = 0
  public var maxHit: Decimal = 0
  /// Empty key represents an absent label, never a guessed category.
  public var damageByType: [String: Decimal] = [:]
  public init(id: UInt32, name: String, damage: Decimal = 0, hits: Int = 0, maxHit: Decimal = 0) {
    self.id = id
    self.name = name
    self.damage = damage
    self.hits = hits
    self.maxHit = maxHit
  }
}

public struct LiveSnapshot: Codable, Sendable, Equatable {
  public var characters: [LiveCharacter] = []
  public var total: Decimal = 0
  public var highest: Decimal = 0
  public var elapsed: Double = 0
  public var eventCount = 0
  public var active = false
  public var partial = true
  public var mismatch = false
  public var ended = false
  public var actionValue: Decimal?
  /// Damage per cumulative action value; unavailable for incomplete sessions.
  public var dpa: Decimal? {
    guard !partial, let actionValue, actionValue > 0 else { return nil }
    return total / actionValue
  }
  public var party: [LiveCharacter] { characters.filter(\.isPartyMember) }
  public var unassignedDamage: Decimal {
    characters.filter { !$0.isPartyMember }.reduce(0) { $0 + $1.damage }
  }
  public var enemies: [LiveEnemy] = []
  public var actingEnemy: UInt32?
  public var collectorTotal: Decimal?
  public init() {}
}

/// Decimal preserves incoming JSON decimal values. It cannot recover upstream f64 precision.
public actor LiveCombatStore {
  private var snapshot = LiveSnapshot()
  private var members: [UInt32: LiveCharacter] = [:]
  private var enemies: [UInt32: LiveEnemy] = [:]
  private var enemyFormation: Set<UInt32>?
  private var started: ContinuousClock.Instant?
  private var sawLineup = false
  private var sawBegin = false
  private var hasGap = false
  private var historyDatabase: HistoryWorker?
  private var historyRecord: BattleRecord?
  private var settlementNeedsSave = false
  private var deferredHistory: [BattleRecord] = []
  private var lastCheckpoint = Date.distantPast
  private var collectorVersion = "未知"
  private var historyWrite: Task<Void, Never>?
  private var writingRecord: BattleRecord?
  private var retryAfter = Date.distantPast
  private var writeFailures = 0
  private var historyMaintenance = 0
  public private(set) var historyError: String?

  public init() {}

  public func reset() {
    checkpoint(status: snapshot.ended ? nil : "interrupted")
    if let record = historyRecord,
      settlementNeedsSave || !record.events.isEmpty || writingRecord?.id == record.id
    {
      if deferredHistory.count < 128,
        deferredHistory.reduce(record.events.count, { $0 + $1.events.count }) <= 262_144
      {
        deferredHistory.append(record)
      } else {
        historyError = "历史保存持续失败，部分记录未保存"
      }
    }
    historyRecord = nil
    settlementNeedsSave = false
    snapshot = LiveSnapshot()
    members = [:]
    enemies = [:]
    enemyFormation = nil
    started = nil
    sawLineup = false
    sawBegin = false
    hasGap = false
  }

  public func disconnected() {
    for id in enemies.keys { enemies[id]?.stale = true }
    snapshot.actingEnemy = nil
    if snapshot.active {
      snapshot.partial = true
      hasGap = true
    }
  }

  public func consume(_ event: VeritasEvent) {
    switch event {
    case .connected(let version):
      collectorVersion = version
      // Keep prior values visible until a new session, but never silently resume a complete session.
      if snapshot.active {
        snapshot.partial = true
        hasGap = true
      }
    case .lineup(let avatars):
      // Upstream resets BattleContext here, usually before OnBattleBegin.
      reset()
      sawLineup = true
      snapshot.active = true
      started = .now
      for avatar in avatars {
        members[avatar.id] = LiveCharacter(
          id: avatar.id, name: CharacterCatalog.name(for: avatar.id, fallback: avatar.name))
      }
    case .begin:
      if sawBegin || snapshot.ended {
        reset()
      }
      sawBegin = true
      snapshot.active = true
      snapshot.partial = !sawLineup || hasGap
      if started == nil { started = .now }
    case .damage(let damage):
      guard damage.attacker.team == "Player" else { return }
      if snapshot.ended { reset() }
      if !snapshot.active {
        snapshot.active = true
        snapshot.partial = true
        started = .now
      }
      let id = damage.attacker.uid
      var character = members[id] ?? LiveCharacter(id: id, name: CharacterCatalog.name(for: id))
      if members[id] == nil {
        character.isPartyMember = false
        snapshot.partial = true
        hasGap = true
      }
      character.damage += damage.damage
      character.damageByType[damage.type ?? "", default: 0] += damage.damage
      character.maxHit = max(character.maxHit, damage.damage)
      character.hits += 1
      members[id] = character
      snapshot.total += damage.damage
      snapshot.highest = max(snapshot.highest, damage.damage)
      snapshot.eventCount += 1
      ensureHistory()
      if (historyRecord?.events.count ?? 0) < 8192 {
        historyRecord?.events.append(
          SavedDamage(sequence: snapshot.eventCount, elapsed: elapsed(), event: damage))
      } else {
        historyRecord?.rawEventsComplete = false
        historyError = "历史保存失败，部分原始事件未保存"
      }
      if (historyRecord?.events.count ?? 0) >= 128 { checkpoint() }
    case .actionValue(let value, let owner):
      guard snapshot.active, value >= 0, !value.isNaN else { return }
      snapshot.actingEnemy = owner?.team == "Enemy" ? owner?.uid : nil
      if let prior = snapshot.actionValue, value < prior {
        snapshot.partial = true
        hasGap = true
      }
      snapshot.actionValue = value
    case .enemy(let enemy):
      guard !snapshot.ended else { return }
      var value = enemies[enemy.uid] ?? LiveEnemy(id: enemy.uid)
      value.templateID = enemy.id
      value.name = enemy.name
      // Initialization is not a live HP update: preserve an earlier received change.
      if value.hp == nil { value.hp = enemy.baseStats.properties["CurrentHP"] }
      if value.maxHP == nil { value.maxHP = enemy.baseStats.properties["MaxHP"] }
      value.onField = enemyFormation.map { $0.contains(enemy.uid) }
      enemies[enemy.uid] = value
    case .enemyStat(let stat):
      guard !snapshot.ended, stat.entity.team == "Enemy", !stat.property.value.isNaN,
        stat.property.type == "CurrentHP" || stat.property.type == "MaxHP"
      else { return }
      var value = enemies[stat.entity.uid] ?? LiveEnemy(id: stat.entity.uid)
      if stat.property.type == "CurrentHP" {
        value.hp = max(0, stat.property.value)
        value.stale = false
        if stat.property.value > 0 { value.defeated = false }
      } else {
        value.maxHP = max(0, stat.property.value)
      }
      value.onField = enemyFormation.map { $0.contains(value.id) }
      enemies[value.id] = value
    case .enemyFormation(let entities):
      guard !snapshot.ended else { return }
      enemyFormation = Set(entities.filter { $0.team == "Enemy" }.map(\.uid))
      for id in enemies.keys { enemies[id]?.onField = enemyFormation?.contains(id) }
    case .defeated(let entity):
      guard !snapshot.ended, entity.team == "Enemy" else { return }
      var value = enemies[entity.uid] ?? LiveEnemy(id: entity.uid)
      value.hp = 0
      value.defeated = true
      enemies[entity.uid] = value
      if snapshot.actingEnemy == entity.uid { snapshot.actingEnemy = nil }
    case .turnEnded:
      snapshot.actingEnemy = nil
    case .end(let total, let finalActionValue):
      // The first settlement fixes the clock and final metrics; retries only persist it.
      guard !snapshot.ended else {
        checkpoint()
        return
      }
      snapshot.actingEnemy = nil
      if let value = finalActionValue {
        if let prior = snapshot.actionValue, value < prior { snapshot.partial = true }
        snapshot.actionValue = value
      }
      snapshot.elapsed = elapsed()
      snapshot.active = false
      snapshot.ended = true
      snapshot.collectorTotal = total
      let delta = NSDecimalNumber(decimal: abs(snapshot.total - total)).doubleValue
      let tolerance = max(0.000001, abs(NSDecimalNumber(decimal: total).doubleValue) * 1e-10)
      snapshot.mismatch = delta > tolerance
      if snapshot.mismatch { snapshot.partial = true }
      checkpoint(status: snapshot.partial ? "incomplete" : "completed")
    case .collectorError:
      snapshot.partial = true
      hasGap = true
    case .ignored: break
    }
    if snapshot.active { ensureHistory() }
  }

  public func currentSnapshot() -> LiveSnapshot {
    if Date().timeIntervalSince(lastCheckpoint) >= 0.5 { checkpoint() }
    return makeSnapshot()
  }

  private func makeSnapshot() -> LiveSnapshot {
    var result = snapshot
    result.enemies = enemies.values.sorted { $0.id < $1.id }
    result.characters = members.values.sorted {
      $0.damage == $1.damage ? $0.id < $1.id : $0.damage > $1.damage
    }
    for index in result.characters.indices {
      result.characters[index].name = CharacterCatalog.name(
        for: result.characters[index].id,
        fallback: result.characters[index].name)
    }
    if result.active { result.elapsed = elapsed() }
    return result
  }

  public func enableHistory(at url: URL) async {
    guard historyDatabase == nil else { return }
    let worker = HistoryWorker()
    historyDatabase = worker
    do {
      try await worker.open(url)
      historyError = nil
    } catch {
      historyDatabase = nil
      historyError = "无法打开战斗历史，当前统计仍可使用"
    }
  }

  private func ensureHistory() {
    guard historyDatabase != nil, historyRecord == nil else { return }
    historyRecord = BattleRecord(
      id: UUID(), startedAt: Date(), status: "running",
      collectorVersion: collectorVersion, snapshot: makeSnapshot())
  }

  private func checkpoint(status: String? = nil) {
    guard historyDatabase != nil else { return }
    lastCheckpoint = Date()
    // Capture settlement before any database operation, including deferred writes.
    if let status, var record = historyRecord {
      record.snapshot = makeSnapshot()
      record.status = status
      record.endedAt = Date()
      if status != "completed" { record.snapshot.partial = true }
      historyRecord = record
      settlementNeedsSave = true
    }
    if !settlementNeedsSave { historyRecord?.snapshot = makeSnapshot() }
    startHistoryWrite()
  }

  private func startHistoryWrite() {
    guard historyWrite == nil, historyMaintenance == 0, Date() >= retryAfter,
      let historyDatabase
    else { return }
    let record: BattleRecord
    if let deferred = deferredHistory.first {
      record = deferred
    } else if let current = historyRecord,
      settlementNeedsSave || !current.events.isEmpty || (!snapshot.ended && sawBegin)
    {
      record = current
    } else {
      return
    }
    writingRecord = record
    historyWrite = Task {
      do {
        try await historyDatabase.save(record)
        finishHistoryWrite(record, succeeded: true)
      } catch {
        finishHistoryWrite(record, succeeded: false)
      }
    }
  }

  private func finishHistoryWrite(_ saved: BattleRecord, succeeded: Bool) {
    historyWrite = nil
    writingRecord = nil
    guard succeeded else {
      writeFailures = min(writeFailures + 1, 6)
      retryAfter = Date().addingTimeInterval(min(30, 0.5 * pow(2, Double(writeFailures - 1))))
      historyError = "历史保存失败，正在重试；请检查磁盘空间"
      return
    }
    writeFailures = 0
    retryAfter = .distantPast
    historyError = nil
    let lastSequence = saved.events.last?.sequence ?? 0
    if historyRecord?.id == saved.id {
      historyRecord?.events.removeAll { $0.sequence <= lastSequence }
      if saved.status != "running", historyRecord?.endedAt == saved.endedAt {
        settlementNeedsSave = false
      }
    }
    if let index = deferredHistory.firstIndex(where: { $0.id == saved.id }) {
      if saved.status != "running", deferredHistory[index].endedAt == saved.endedAt {
        deferredHistory.remove(at: index)
      } else {
        deferredHistory[index].events.removeAll { $0.sequence <= lastSequence }
      }
    }
    // One write in flight; retain new events until their own write is acknowledged.
    if !deferredHistory.isEmpty || settlementNeedsSave || (historyRecord?.events.count ?? 0) >= 128
    {
      startHistoryWrite()
    }
  }

  /// History consumers wait for scheduled writes without holding up incoming combat events.
  private func drainHistoryWrites() async {
    checkpoint()
    while let write = historyWrite { await write.value }
  }

  /// Called after the receiver stops, so a normal quit does not abandon buffered events.
  public func finishHistory() async {
    reset()
    retryAfter = .distantPast
    await drainHistoryWrites()
  }

  public func history(search: String = "", oldestFirst: Bool = false, offset: Int = 0) async throws
    -> [BattleSummary]
  {
    guard let historyDatabase else { throw CocoaError(.fileReadUnknown) }
    await drainHistoryWrites()
    return try await historyDatabase.list(search: search, oldestFirst: oldestFirst, offset: offset)
  }

  public func historyDetail(id: UUID, includeEvents: Bool = false) async throws -> BattleRecord? {
    guard let historyDatabase else { throw CocoaError(.fileReadUnknown) }
    await drainHistoryWrites()
    return try await historyDatabase.load(id: id, includeEvents: includeEvents)
  }

  public func historyTrend(id: UUID) async throws -> [DamageTrendPoint] {
    guard let historyDatabase else { throw CocoaError(.fileReadUnknown) }
    await drainHistoryWrites()
    return try await historyDatabase.trend(id: id)
  }

  public func deleteHistory(ids: [UUID]? = nil, before: Date? = nil) async throws {
    guard let historyDatabase else { throw CocoaError(.fileWriteUnknown) }
    await drainHistoryWrites()
    historyMaintenance += 1
    defer {
      historyMaintenance -= 1
      startHistoryWrite()
    }
    let deleted = try await historyDatabase.delete(ids: ids, before: before)
    if let record = historyRecord, deleted.contains(record.id) {
      historyRecord = nil
      settlementNeedsSave = false
    }
    deferredHistory.removeAll { deleted.contains($0.id) }
  }

  public func setHistoryRetention(days: Int) async throws {
    guard [0, 7, 30, 90, 365].contains(days) else { throw CocoaError(.coderInvalidValue) }
    if days > 0 {
      try await deleteHistory(before: Date().addingTimeInterval(-Double(days) * 86400))
    }
  }

  private func elapsed() -> Double {
    guard let started else { return 0 }
    let duration = started.duration(to: .now).components
    return max(0, Double(duration.seconds) + Double(duration.attoseconds) / 1e18)
  }
}
