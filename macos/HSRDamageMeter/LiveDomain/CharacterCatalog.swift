import Foundation

public enum CharacterCatalog {
  private struct Entry: Decodable {
    let zh: String?
    let damageType: String?
  }
  private static let bundledEntries: [String: Entry] = {
    guard let url = Bundle.module.url(forResource: "characters-4.5.54", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let decoded = try? JSONDecoder().decode([String: Entry].self, from: data)
    else { return [:] }
    return decoded
  }()

  private final class Overrides: @unchecked Sendable {
    let lock = NSLock()
    var entries: [String: Entry]?
  }
  private static let overrides = Overrides()
  private static var currentEntries: [String: Entry] {
    overrides.lock.lock()
    defer { overrides.lock.unlock() }
    return overrides.entries ?? bundledEntries
  }
  public static func validate(_ data: Data) throws {
    let decoded = try JSONDecoder().decode([String: Entry].self, from: data)
    guard !decoded.isEmpty, decoded.values.contains(where: { $0.zh != nil }) else {
      throw CocoaError(.coderInvalidValue)
    }
  }
  public static func install(_ data: Data) throws {
    try validate(data)
    let decoded = try JSONDecoder().decode([String: Entry].self, from: data)
    guard !decoded.isEmpty else { throw CocoaError(.coderInvalidValue) }
    overrides.lock.lock()
    defer { overrides.lock.unlock() }
    overrides.entries = decoded
  }
  public static func bundledMonsters() -> Data {
    guard let url = Bundle.module.url(forResource: "monsters-4.5.54", withExtension: "json"),
      let data = try? Data(contentsOf: url)
    else { return Data() }
    return data
  }

  public static func portraitURL(for id: UInt32) -> URL? {
    Bundle.module.url(forResource: "portrait-\(id)", withExtension: "png")
  }

  public static func element(for id: UInt32) -> String? {
    currentEntries[String(id)]?.damageType
  }

  public static func name(for id: UInt32, fallback: String? = nil) -> String {
    if let name = currentEntries[String(id)]?.zh, !name.isEmpty { return name }
    if let fallback, !fallback.isEmpty { return fallback }
    return "角色 \(id)"
  }
}
