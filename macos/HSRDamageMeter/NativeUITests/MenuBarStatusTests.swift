import AppKit
import LiveDomain
import XCTest

@testable import NativeApp

@MainActor final class MenuBarStatusTests: XCTestCase {
  func testGreenBadgeRequiresCurrentCombatData() {
    var snapshot = LiveSnapshot()
    snapshot.active = true
    XCTAssertFalse(
      MenuBarActivity.isCollecting(
        snapshot: snapshot, status: .connected, freshDamage: true, demo: false))
    snapshot.eventCount = 1
    XCTAssertTrue(
      MenuBarActivity.isCollecting(
        snapshot: snapshot, status: .connected, freshDamage: true, demo: false))
    XCTAssertFalse(
      MenuBarActivity.isCollecting(
        snapshot: snapshot, status: .offline, freshDamage: true, demo: false))
    XCTAssertFalse(
      MenuBarActivity.isCollecting(
        snapshot: snapshot, status: .connected, freshDamage: false, demo: false))
    XCTAssertFalse(
      MenuBarActivity.isCollecting(
        snapshot: snapshot, status: .connected, freshDamage: true, demo: true))
    snapshot.ended = true
    XCTAssertFalse(
      MenuBarActivity.isCollecting(
        snapshot: snapshot, status: .connected, freshDamage: true, demo: false))
  }

  func testRealArtworkSizesAndBadgeColors() throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Assets/MenuBarIcon@2x.png")
    XCTAssertNotNil(NSImage(contentsOf: url))
    for dark in [false, true] {
      for active in [false, true] {
        let icon = MenuBarArtwork.image(active: active, dark: dark, sourceURL: url)
        XCTAssertEqual(icon.size, NSSize(width: 18, height: 18))
        let bitmap = try XCTUnwrap(icon.representations.last as? NSBitmapImageRep)
        XCTAssertEqual(bitmap.pixelsWide, 36)
        var green = 0
        for y in 0..<36 {
          for x in 0..<36 {
            let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
            if color.greenComponent > color.redComponent + 0.15 && color.alphaComponent > 0.5 {
              green += 1
            }
          }
        }
        XCTAssertEqual(green > 0, active)
        if let directory = ProcessInfo.processInfo.environment["HSR_MENU_RENDER"] {
          try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(
              to: URL(fileURLWithPath: directory).appendingPathComponent(
                "menu-\(dark ? "dark" : "light")-\(active ? "active" : "idle").png"))
        }
      }
    }
  }
}
