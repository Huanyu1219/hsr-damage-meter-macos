import AppKit
import LiveDomain
import SwiftUI
import XCTest

@testable import NativeApp

@MainActor final class PresentationTests: XCTestCase {
  func testNanokaLiveVersionAndArtwork() async throws {
    guard ProcessInfo.processInfo.environment["HSR_NANOKA_TEST"] == "1" else {
      throw XCTSkip("Set HSR_NANOKA_TEST=1 for the public Nanoka integration check")
    }
    let library = GameDataLibrary()
    await library.update()
    XCTAssertTrue(library.message == "已是最新版本" || library.message?.hasPrefix("已更新至") == true)
    let image = await library.portrait(1_002_011)
    XCTAssertNotNil(image)
  }
  func testNanokaVersionAndMonsterCatalog() throws {
    XCTAssertEqual(
      try GameDataLibrary.publishedVersion(
        #"data-url="https://static.nanoka.cc/hsr/4.5.54/character.json""#), "4.5.54")
    XCTAssertThrowsError(try GameDataLibrary.publishedVersion("invalid"))
    XCTAssertEqual(GameDataLibrary().monster(1_002_011)?.zh, "冰锋")
    XCTAssertThrowsError(try CharacterCatalog.validate(Data("{}".utf8)))
  }
  func testPortraitAssetsDecode() throws {
    XCTAssertEqual(CharacterCatalog.element(for: 1407), "Quantum")
    XCTAssertEqual(CharacterCatalog.element(for: 1413), "Ice")
    XCTAssertNil(CharacterCatalog.element(for: 999999))
    for id: UInt32 in [1310, 1413, 1415, 1409] {
      let url = try XCTUnwrap(CharacterCatalog.portraitURL(for: id))
      let image = try XCTUnwrap(NSImage(contentsOf: url))
      XCTAssertGreaterThan(image.size.width, 0)
      XCTAssertGreaterThan(image.size.height, 0)
    }
    XCTAssertNil(CharacterCatalog.portraitURL(for: 999999))
  }

  func testPreviewTotalsAndLargeNumbers() {
    let standard = PreviewFactory.connectedLiveSession()
    XCTAssertEqual(
      standard.snapshot.characters.reduce(0) { $0 + $1.damage }, standard.snapshot.total)
    XCTAssertEqual(
      DamageBreakdown.categories(standard.snapshot.characters).reduce(0) { $0 + $1.damage },
      standard.snapshot.total)
    let large = PreviewFactory.largeDamageNumbers()
    XCTAssertEqual(large.snapshot.total, Decimal(Int64.max))
    XCTAssertFalse(DamageFormatting.compact(large.snapshot.total).contains("inf"))
    standard.reset()
    XCTAssertEqual(standard.snapshot.total, 0)
    XCTAssertTrue(standard.snapshot.characters.isEmpty)
  }

  func testOffscreenMinimumWindowLayout() throws {
    // No screen capture, live app control, or game connection. Render an isolated NSHostingView.
    let view = NSHostingView(rootView: LiveView(model: PreviewFactory.connectedLiveSession()))
    view.frame = NSRect(x: 0, y: 0, width: 900, height: 620)
    view.layoutSubtreeIfNeeded()
    XCTAssertEqual(view.bounds.width, 900)
    XCTAssertEqual(view.bounds.height, 620)
    let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
    view.cacheDisplay(in: view.bounds, to: bitmap)
    XCTAssertGreaterThan(bitmap.pixelsWide, 0)
    // Optional artifact for a user to inspect without any computer-use session.
    if let path = ProcessInfo.processInfo.environment["HSR_RENDER_OUTPUT"] {
      let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
      try png.write(to: URL(fileURLWithPath: path))
    }
  }

  func testEnemyCardsOffscreen() throws {
    let view = NSHostingView(
      rootView: EnemySection(
        snapshot: PreviewFactory.snapshot(),
        data: GameDataLibrary(), connected: true))
    view.frame = NSRect(x: 0, y: 0, width: 852, height: 180)
    view.layoutSubtreeIfNeeded()
    let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
    view.cacheDisplay(in: view.bounds, to: bitmap)
    if let path = ProcessInfo.processInfo.environment["HSR_ENEMY_RENDER_OUTPUT"] {
      try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        .write(to: URL(fileURLWithPath: path))
    }
  }
}
