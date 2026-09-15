import AppKit
import Foundation
import LiveDomain
import XCTest

@testable import NativeApp

@MainActor final class GameDataTests: XCTestCase {
  func testAlreadyCurrentAvoidsDatasetDownloads() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    var calls = 0
    let data = GameDataLibrary(directory: directory) { _ in
      calls += 1
      return Data("https://static.nanoka.cc/hsr/4.5.54/character.json".utf8)
    }
    await data.update()
    XCTAssertEqual(data.message, "已是最新版本")
    XCTAssertEqual(calls, 1)
    XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
  }

  func testUpdateAndFailurePreserveLastArchive() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let originalURL = try XCTUnwrap(CharacterCatalog.portraitURL(for: 1407))
      .deletingLastPathComponent().appendingPathComponent("characters-4.5.54.json")
    let characters = try Data(contentsOf: originalURL)
    defer {
      try? FileManager.default.removeItem(at: directory)
      try? CharacterCatalog.install(characters)
    }
    final class Fixture {
      var latest = "4.5.55"
      var fail = false
    }
    let fixture = Fixture()
    let library = GameDataLibrary(directory: directory) { url in
      if url.host == "hsr.nanoka.cc" {
        return Data("https://static.nanoka.cc/hsr/\(fixture.latest)/character.json".utf8)
      }
      if url.lastPathComponent == "character.json" { return characters }
      return fixture.fail ? Data("invalid".utf8) : CharacterCatalog.bundledMonsters()
    }
    await library.update()
    XCTAssertEqual(library.message, "已更新至 4.5.55")
    let file = directory.appendingPathComponent("catalog.json")
    let saved = try Data(contentsOf: file)
    fixture.latest = "4.5.56"
    fixture.fail = true
    await library.update()
    XCTAssertEqual(library.version, "4.5.55")
    XCTAssertEqual(library.message, "更新失败，继续使用现有数据")
    XCTAssertEqual(try Data(contentsOf: file), saved)
    XCTAssertEqual(GameDataLibrary(directory: directory).version, "4.5.55")
  }
}
