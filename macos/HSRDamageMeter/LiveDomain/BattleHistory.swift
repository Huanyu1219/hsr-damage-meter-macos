import Foundation
import SQLite3
import VeritasNetworking

public struct SavedDamage: Codable, Sendable {
  public let sequence: Int
  public let elapsed: Double
  public let event: VeritasDamage
}

public struct BattleRecord: Codable, Sendable, Identifiable {
  public var schemaVersion = 1
  public var rawEventsComplete = true
  public var id: UUID
  public var startedAt: Date
  public var endedAt: Date?
  public var status: String
  public var collectorVersion: String
  public var gameVersion: String?  // The current wire protocol does not report this.
  public var loadoutID: UUID?  // Reserved for a separately verified equipment import.
  public var snapshot: LiveSnapshot
  public var events: [SavedDamage] = []

  public init(
    id: UUID, startedAt: Date, status: String, collectorVersion: String, snapshot: LiveSnapshot
  ) {
    self.id = id
    self.startedAt = startedAt
    self.status = status
    self.collectorVersion = collectorVersion
    self.snapshot = snapshot
  }
}

public struct BattleSummary: Identifiable, Sendable {
  public let id: UUID
  public let startedAt: Date
  public let status: String
  public let duration: Double
  public let total: Decimal
  public let partyNames: String
}

public struct DamageTrendPoint: Identifiable, Sendable {
  public let id: Int
  public let elapsed: Double
  public let cumulative: Decimal
}

/// Owned by HistoryWorker; never shared across executors.
final class BattleHistoryDatabase {
  private var db: OpaquePointer?
  private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
  enum Failure: Error { case database(String) }

  init(url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard
      sqlite3_open_v2(
        url.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
        == SQLITE_OK
    else {
      let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Cannot open history"
      if let db { sqlite3_close(db) }
      db = nil
      throw Failure.database(message)
    }
    sqlite3_busy_timeout(db, 500)
    do {
      try execute("PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;")
      try execute("BEGIN IMMEDIATE")
      try execute(
        """
        CREATE TABLE IF NOT EXISTS app_settings(key TEXT PRIMARY KEY, value TEXT NOT NULL);
        INSERT OR IGNORE INTO app_settings VALUES('schema_version','1');
        CREATE TABLE IF NOT EXISTS sessions(
          id TEXT PRIMARY KEY, started REAL NOT NULL, status TEXT NOT NULL,
          duration REAL NOT NULL, total TEXT NOT NULL, names TEXT NOT NULL, snapshot BLOB NOT NULL);
        CREATE INDEX IF NOT EXISTS sessions_started ON sessions(started);
        CREATE TABLE IF NOT EXISTS damage_events(
          session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
          sequence INTEGER NOT NULL, payload BLOB NOT NULL, PRIMARY KEY(session_id,sequence));
        """)
      let version = try statement("SELECT value FROM app_settings WHERE key='schema_version'")
      defer { sqlite3_finalize(version) }
      guard sqlite3_step(version) == SQLITE_ROW, string(version, 0) == "1" else {
        throw Failure.database("Unsupported history schema version")
      }
      try execute("UPDATE sessions SET status='interrupted' WHERE status='running';")
      try execute("COMMIT")
    } catch {
      try? execute("ROLLBACK")
      sqlite3_close(db)
      db = nil
      throw error
    }
  }
  deinit { if let db { sqlite3_close(db) } }

  private func execute(_ sql: String) throws {
    guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw failure() }
  }
  private func failure() -> Failure { .database(String(cString: sqlite3_errmsg(db))) }
  private func statement(_ sql: String) throws -> OpaquePointer {
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
      throw failure()
    }
    return stmt
  }
  private func text(_ value: String, at index: Int32, in stmt: OpaquePointer) throws {
    guard value.utf8.count <= Int(Int32.max),
      value.withCString({ sqlite3_bind_text(stmt, index, $0, -1, transient) }) == SQLITE_OK
    else { throw failure() }
  }
  private func blob(_ data: Data, at index: Int32, in stmt: OpaquePointer) throws {
    guard !data.isEmpty, data.count <= Int(Int32.max) else {
      throw Failure.database("Invalid history payload size")
    }
    let result = data.withUnsafeBytes {
      sqlite3_bind_blob(stmt, index, $0.baseAddress, Int32(data.count), transient)
    }
    guard result == SQLITE_OK else { throw failure() }
  }
  private func string(_ stmt: OpaquePointer, _ column: Int32) -> String {
    sqlite3_column_text(stmt, column).map { String(cString: $0) } ?? ""
  }
  private func data(_ stmt: OpaquePointer, _ column: Int32) throws -> Data {
    let size = Int(sqlite3_column_bytes(stmt, column))
    guard sqlite3_column_type(stmt, column) == SQLITE_BLOB, size > 0, size <= 64_000_000,
      let bytes = sqlite3_column_blob(stmt, column)
    else { throw Failure.database("Invalid history payload") }
    return Data(bytes: bytes, count: size)
  }
  private func finish(_ stmt: OpaquePointer) throws {
    guard sqlite3_step(stmt) == SQLITE_DONE else { throw failure() }
  }

  func save(_ record: BattleRecord) throws {
    try execute("BEGIN IMMEDIATE")
    do {
      let stmt = try statement(
        "INSERT INTO sessions VALUES(?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET status=excluded.status,duration=excluded.duration,total=excluded.total,names=excluded.names,snapshot=excluded.snapshot"
      )
      defer { sqlite3_finalize(stmt) }
      var snapshot = record
      snapshot.events = []
      try text(record.id.uuidString, at: 1, in: stmt)
      sqlite3_bind_double(stmt, 2, record.startedAt.timeIntervalSince1970)
      try text(record.status, at: 3, in: stmt)
      sqlite3_bind_double(stmt, 4, record.snapshot.elapsed)
      try text(record.snapshot.total.description, at: 5, in: stmt)
      try text(record.snapshot.characters.map(\.name).joined(separator: " · "), at: 6, in: stmt)
      try blob(try JSONEncoder().encode(snapshot), at: 7, in: stmt)
      try finish(stmt)
      let eventStmt = try statement("INSERT OR IGNORE INTO damage_events VALUES(?,?,?)")
      defer { sqlite3_finalize(eventStmt) }
      for event in record.events {
        sqlite3_reset(eventStmt)
        sqlite3_clear_bindings(eventStmt)
        try text(record.id.uuidString, at: 1, in: eventStmt)
        sqlite3_bind_int64(eventStmt, 2, Int64(event.sequence))
        try blob(try JSONEncoder().encode(event), at: 3, in: eventStmt)
        try finish(eventStmt)
      }
      try execute("COMMIT")
    } catch {
      try? execute("ROLLBACK")
      throw error
    }
  }

  func list(search: String, oldestFirst: Bool, offset: Int) throws -> [BattleSummary] {
    let direction = oldestFirst ? "ASC" : "DESC"
    let stmt = try statement(
      "SELECT id,started,status,duration,total,names FROM sessions WHERE status!='running' AND (?='' OR instr(names,?)>0) ORDER BY started \(direction),id \(direction) LIMIT 50 OFFSET ?"
    )
    defer { sqlite3_finalize(stmt) }
    try text(search, at: 1, in: stmt)
    try text(search, at: 2, in: stmt)
    sqlite3_bind_int64(stmt, 3, Int64(max(0, offset)))
    var result: [BattleSummary] = []
    var step = sqlite3_step(stmt)
    while step == SQLITE_ROW {
      guard let id = UUID(uuidString: string(stmt, 0)), let total = Decimal(string: string(stmt, 4))
      else { throw failure() }
      result.append(
        BattleSummary(
          id: id, startedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
          status: string(stmt, 2), duration: sqlite3_column_double(stmt, 3), total: total,
          partyNames: string(stmt, 5)))
      step = sqlite3_step(stmt)
    }
    guard step == SQLITE_DONE else { throw failure() }
    return result
  }

  func load(id: UUID, includeEvents: Bool = false) throws -> BattleRecord? {
    let stmt = try statement("SELECT snapshot,status FROM sessions WHERE id=?")
    defer { sqlite3_finalize(stmt) }
    try text(id.uuidString, at: 1, in: stmt)
    let step = sqlite3_step(stmt)
    if step == SQLITE_DONE { return nil }
    guard step == SQLITE_ROW else { throw failure() }
    var record = try JSONDecoder().decode(BattleRecord.self, from: data(stmt, 0))
    guard record.schemaVersion == 1 else {
      throw Failure.database("Unsupported battle record version")
    }
    record.status = string(stmt, 1)
    if record.status != "completed" { record.snapshot.partial = true }
    record.snapshot.active = false
    if includeEvents {
      let events = try statement(
        "SELECT payload FROM damage_events WHERE session_id=? ORDER BY sequence")
      defer { sqlite3_finalize(events) }
      try text(id.uuidString, at: 1, in: events)
      var eventStep = sqlite3_step(events)
      while eventStep == SQLITE_ROW {
        record.events.append(try JSONDecoder().decode(SavedDamage.self, from: data(events, 0)))
        eventStep = sqlite3_step(events)
      }
      guard eventStep == SQLITE_DONE else { throw failure() }
    }
    return record
  }

  func trend(id: UUID) throws -> [DamageTrendPoint] {
    guard let record = try load(id: id) else { return [] }
    guard record.snapshot.elapsed.isFinite, record.snapshot.elapsed >= 0 else {
      throw Failure.database("Invalid battle duration")
    }
    let width = max(1, record.snapshot.elapsed / 120)
    var bins: [Int: Decimal] = [:]
    let stmt = try statement(
      "SELECT payload FROM damage_events WHERE session_id=? ORDER BY sequence")
    defer { sqlite3_finalize(stmt) }
    try text(id.uuidString, at: 1, in: stmt)
    var step = sqlite3_step(stmt)
    while step == SQLITE_ROW {
      let event = try JSONDecoder().decode(SavedDamage.self, from: data(stmt, 0))
      guard event.elapsed.isFinite, event.elapsed >= 0 else {
        throw Failure.database("Invalid event timestamp")
      }
      let bin = Int(min(119, event.elapsed / width))
      bins[bin, default: 0] += event.event.damage
      step = sqlite3_step(stmt)
    }
    guard step == SQLITE_DONE else { throw failure() }
    guard let last = bins.keys.max() else { return [] }
    var total: Decimal = 0
    var points = [DamageTrendPoint(id: -1, elapsed: 0, cumulative: 0)]
    for index in 0...last {
      total += bins[index] ?? 0
      points.append(
        DamageTrendPoint(
          id: index,
          elapsed: min(record.snapshot.elapsed, Double(index + 1) * width), cumulative: total))
    }
    return points
  }

  @discardableResult
  func delete(ids: [UUID]?, before: Date? = nil) throws -> Set<UUID> {
    try execute("BEGIN IMMEDIATE")
    do {
      let sql =
        ids != nil
        ? "DELETE FROM sessions WHERE status!='running' AND id=?"
        : "DELETE FROM sessions WHERE status!='running' AND started<?"
      let stmt = try statement(sql + " RETURNING id")
      defer { sqlite3_finalize(stmt) }
      var deleted: Set<UUID> = []
      func collectDeleted() throws {
        var step = sqlite3_step(stmt)
        while step == SQLITE_ROW {
          guard let id = UUID(uuidString: string(stmt, 0)) else { throw failure() }
          deleted.insert(id)
          step = sqlite3_step(stmt)
        }
        guard step == SQLITE_DONE else { throw failure() }
      }
      if let ids {
        for id in ids {
          sqlite3_reset(stmt)
          try text(id.uuidString, at: 1, in: stmt)
          try collectDeleted()
        }
      } else {
        sqlite3_bind_double(stmt, 1, (before ?? .distantFuture).timeIntervalSince1970)
        try collectDeleted()
      }
      try execute("COMMIT")
      return deleted
    } catch {
      try? execute("ROLLBACK")
      throw error
    }
  }
}
