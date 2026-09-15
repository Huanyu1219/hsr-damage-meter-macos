import AppKit
import Foundation
import ImageIO
import LiveDomain
import Observation

@MainActor @Observable final class GameDataLibrary {
  struct Monster: Codable, Sendable {
    let zh: String?
    let icon: String?
    let child: [UInt32]?
  }
  struct Archive: Codable, Sendable {
    let version: String
    let characters: Data
    let monsters: Data
  }
  var version = "4.5.54"
  var updating = false
  var message: String?
  private var monsters: [String: Monster] = [:]
  private var aliases: [UInt32: String] = [:]
  private var images: [String: NSImage] = [:]
  private var downloads: [String: Task<Data?, Never>] = [:]
  private let directory: URL
  private let loader: (@MainActor (URL) async throws -> Data)?

  init(directory: URL? = nil, loader: (@MainActor (URL) async throws -> Data)? = nil) {
    self.directory =
      directory
      ?? FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("HSRDamageMeter/GameData", isDirectory: true)
    self.loader = loader
    let directory = self.directory
    if let data = try? Data(contentsOf: directory.appendingPathComponent("catalog.json")),
      let saved = try? JSONDecoder().decode(Archive.self, from: data),
      let entries = try? Self.decodeMonsters(saved.monsters),
      (try? CharacterCatalog.install(saved.characters)) != nil
    {
      version = saved.version
      install(entries)
    } else if let entries = try? Self.decodeMonsters(CharacterCatalog.bundledMonsters()) {
      install(entries)
    }
  }

  nonisolated private static func decodeMonsters(_ data: Data) throws -> [String: Monster] {
    let values = try JSONDecoder().decode([String: Monster].self, from: data)
    guard !values.isEmpty else { throw CocoaError(.coderInvalidValue) }
    return values
  }

  private func install(_ entries: [String: Monster]) {
    monsters = entries
    aliases = [:]
    for key in entries.keys.sorted() {
      for id in entries[key]?.child ?? [] { aliases[id] = key }
    }
  }

  func monster(_ id: UInt32?) -> Monster? {
    guard let id else { return nil }
    return monsters[String(id)] ?? aliases[id].flatMap { monsters[$0] }
  }

  static func publishedVersion(_ html: String) throws -> String {
    let pattern = #"https://static\.nanoka\.cc/hsr/([0-9]+\.[0-9]+\.[0-9]+)/character\.json"#
    let regex = try NSRegularExpression(pattern: pattern)
    guard let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
      let range = Range(match.range(at: 1), in: html)
    else { throw CocoaError(.coderInvalidValue) }
    return String(html[range])
  }

  private func fetch(_ url: URL) async throws -> Data {
    let data: Data
    if let loader {
      data = try await loader(url)
    } else {
      data = try await BoundedDownload.fetch(url)
    }
    guard data.count < BoundedDownload.byteLimit else { throw URLError(.dataLengthExceedsMaximum) }
    return data
  }

  func update() async {
    guard !updating else { return }
    updating = true
    message = nil
    defer { updating = false }
    do {
      let html = try await fetch(URL(string: "https://hsr.nanoka.cc/")!)
      let latest = try Self.publishedVersion(String(decoding: html, as: UTF8.self))
      guard latest != version else {
        message = "已是最新版本"
        return
      }
      guard latest.compare(version, options: .numeric) == .orderedDescending else {
        message = "已是最新版本"
        return
      }
      let base = "https://static.nanoka.cc/hsr/\(latest)/"
      let characters = try await fetch(URL(string: base + "character.json")!)
      let monsterData = try await fetch(URL(string: base + "monster.json")!)
      let directory = self.directory
      let entries = try await Task.detached(priority: .utility) {
        let entries = try Self.decodeMonsters(monsterData)
        try CharacterCatalog.validate(characters)
        let archive = Archive(version: latest, characters: characters, monsters: monsterData)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(archive).write(
          to: directory.appendingPathComponent("catalog.json"), options: .atomic)
        try CharacterCatalog.install(characters)
        return entries
      }.value
      install(entries)
      version = latest
      images = [:]
      message = "已更新至 \(latest)"
    } catch { message = "更新失败，继续使用现有数据" }
  }

  func portrait(_ id: UInt32?) async -> NSImage? {
    guard let path = monster(id)?.icon else { return nil }
    let filename = URL(fileURLWithPath: path).lastPathComponent.replacingOccurrences(
      of: ".png", with: ".webp")
    let key = "\(version)-\(filename)"
    let requestedVersion = version
    if let image = images[key] { return image }
    let file = directory.appendingPathComponent(key)
    if let data = try? Data(contentsOf: file, options: .mappedIfSafe),
      data.count < BoundedDownload.byteLimit, let image = Self.thumbnail(data)
    {
      cache(image, key: key)
      return image
    }
    guard let url = URL(string: "https://static.nanoka.cc/assets/hsr/monstermiddleicon/\(filename)")
    else { return nil }
    let download: Task<Data?, Never>
    if let pending = downloads[key] {
      download = pending
    } else {
      download = Task { try? await fetch(url) }
      downloads[key] = download
    }
    let data = await download.value
    downloads[key] = nil
    guard requestedVersion == version, let data, let image = Self.thumbnail(data) else {
      return nil
    }
    cache(image, key: key)
    let directory = self.directory
    await Task.detached(priority: .utility) {
      try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try? data.write(to: file, options: .atomic)
    }.value
    guard requestedVersion == version else { return nil }
    return image
  }

  private func cache(_ image: NSImage, key: String) {
    if images.count >= 128, let oldest = images.keys.sorted().first {
      images.removeValue(forKey: oldest)
    }
    images[key] = image
  }

  static func thumbnail(_ data: Data) -> NSImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int,
      width > 0, height > 0, width <= 16_000_000 / height,
      let image = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceThumbnailMaxPixelSize: 512,
          kCGImageSourceCreateThumbnailWithTransform: true,
        ] as CFDictionary)
    else { return nil }
    return NSImage(cgImage: image, size: .zero)
  }
}
