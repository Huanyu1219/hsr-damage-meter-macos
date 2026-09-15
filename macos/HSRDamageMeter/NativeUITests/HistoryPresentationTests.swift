import AppKit
import LiveDomain
import SwiftUI
import XCTest

@testable import NativeApp

@MainActor final class HistoryPresentationTests: XCTestCase {
  func testHistoryDetailMinimumLayout() throws {
    var snapshot = PreviewFactory.snapshot()
    snapshot.active = false
    snapshot.ended = true
    let record = BattleRecord(
      id: UUID(), startedAt: Date(), status: "completed",
      collectorVersion: "0.2.52", snapshot: snapshot)
    let view = NSHostingView(
      rootView: HistoryDetailView(
        id: record.id,
        model: PreviewFactory.connectedLiveSession(), preview: record))
    view.frame = NSRect(x: 0, y: 0, width: 900, height: 760)
    view.layoutSubtreeIfNeeded()
    XCTAssertLessThanOrEqual(view.fittingSize.width, 900)
    let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
    view.cacheDisplay(in: view.bounds, to: bitmap)
    if let path = ProcessInfo.processInfo.environment["HSR_HISTORY_RENDER"] {
      try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        .write(to: URL(fileURLWithPath: path))
    }
  }
}
