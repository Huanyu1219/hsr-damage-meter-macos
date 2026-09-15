import Foundation

/// All SQLite work is isolated from the combat reducer and the main actor.
actor HistoryWorker {
  private var database: BattleHistoryDatabase?

  func open(_ url: URL) throws {
    database = try BattleHistoryDatabase(url: url)
  }

  private func connection() throws -> BattleHistoryDatabase {
    guard let database else { throw CocoaError(.fileReadUnknown) }
    return database
  }

  func save(_ record: BattleRecord) throws { try connection().save(record) }

  func list(search: String, oldestFirst: Bool, offset: Int) throws -> [BattleSummary] {
    try connection().list(search: search, oldestFirst: oldestFirst, offset: offset)
  }

  func load(id: UUID, includeEvents: Bool) throws -> BattleRecord? {
    try connection().load(id: id, includeEvents: includeEvents)
  }

  func trend(id: UUID) throws -> [DamageTrendPoint] { try connection().trend(id: id) }

  func delete(ids: [UUID]?, before: Date?) throws -> Set<UUID> {
    try connection().delete(ids: ids, before: before)
  }
}
