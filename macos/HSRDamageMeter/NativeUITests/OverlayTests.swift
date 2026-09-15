import AppKit
import SwiftUI
import XCTest

@testable import NativeApp

@MainActor final class OverlayTests: XCTestCase {
  func testPanelPoliciesAndSettingsRestore() throws {
    let suite = "HSR.OverlayTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = PreviewFactory.connectedLiveSession()
    let controller = OverlayController(defaults: defaults)
    controller.prepare(model: model)  // Configure only; never display a window.
    let panel = try XCTUnwrap(controller.panel)
    defer {
      panel.contentView = nil
      panel.close()
    }
    XCTAssertFalse(panel.isVisible)
    XCTAssertFalse(panel.canBecomeKey)
    XCTAssertFalse(panel.canBecomeMain)
    XCTAssertFalse(panel.hidesOnDeactivate)
    XCTAssertEqual(panel.level, .floating)
    let dragPoints = [
      NSPoint(x: 20, y: 20), NSPoint(x: 40, y: 180),
      NSPoint(x: 150, y: 220), NSPoint(x: 200, y: 90),
    ]
    XCTAssertTrue(dragPoints.allSatisfy { panel.shouldDrag(at: $0) })
    XCTAssertFalse(
      panel.shouldDrag(at: NSPoint(x: panel.frame.width - 20, y: panel.frame.height - 20)))
    controller.setClickThrough(true)
    XCTAssertTrue(panel.ignoresMouseEvents)
    XCTAssertFalse(dragPoints.contains { panel.shouldDrag(at: $0) })
    controller.setClickThrough(false)
    XCTAssertFalse(panel.ignoresMouseEvents)
    XCTAssertTrue(dragPoints.allSatisfy { panel.shouldDrag(at: $0) })
    controller.setAllSpaces(true)
    XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
    controller.setAllSpaces(false)
    XCTAssertFalse(panel.collectionBehavior.contains(.canJoinAllSpaces))
    controller.setMode(.detailed)
    XCTAssertEqual(panel.frame.size, OverlayMode.detailed.size)
    XCTAssertNotNil(defaults.string(forKey: "overlay.frame"))
    let restored = OverlayController(defaults: defaults)
    XCTAssertEqual(restored.mode, .detailed)
    XCTAssertFalse(restored.clickThrough)
    controller.hide()
    XCTAssertFalse(defaults.bool(forKey: "overlay.visible"))
  }

  func testDisconnectedMonitorPositionIsRecovered() {
    let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
    let lost = NSRect(x: 4000, y: -1000, width: 320, height: 360)
    let frame = OverlayController.clamped(lost, screens: [screen])
    XCTAssertTrue(screen.contains(frame))
    let secondary = NSRect(x: -1920, y: 0, width: 1920, height: 1080)
    let saved = NSRect(x: -500, y: 600, width: 320, height: 360)
    XCTAssertEqual(OverlayController.clamped(saved, screens: [screen, secondary]), saved)
  }

  func testAllModesRenderOffscreen() throws {
    let suite = "HSR.OverlayRender.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let controller = OverlayController(defaults: defaults)
    let model = PreviewFactory.connectedLiveSession()
    for mode in OverlayMode.allCases {
      controller.setMode(mode)
      let view = NSHostingView(rootView: OverlayView(model: model, controller: controller))
      view.frame = NSRect(origin: .zero, size: mode.size)
      view.layoutSubtreeIfNeeded()
      XCTAssertLessThanOrEqual(view.fittingSize.width, mode.size.width + 1)
      XCTAssertLessThanOrEqual(view.fittingSize.height, mode.size.height + 1)
      let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
      view.cacheDisplay(in: view.bounds, to: bitmap)
      if let directory = ProcessInfo.processInfo.environment["HSR_OVERLAY_RENDER"] {
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
          .write(
            to: URL(fileURLWithPath: directory).appendingPathComponent(
              "overlay-\(mode.rawValue).png"))
      }
    }
  }
}
