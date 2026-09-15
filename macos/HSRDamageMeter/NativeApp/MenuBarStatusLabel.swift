import AppKit
import LiveDomain
import SwiftUI
import VeritasNetworking

enum MenuBarActivity {
  static func isCollecting(
    snapshot: LiveSnapshot, status: ConnectionStatus,
    freshDamage: Bool, demo: Bool
  ) -> Bool {
    !demo && status == .connected && snapshot.active && !snapshot.ended
      && snapshot.eventCount > 0 && freshDamage
  }
}

struct MenuBarStatusLabel: View {
  let model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  private var collecting: Bool {
    MenuBarActivity.isCollecting(
      snapshot: model.snapshot, status: model.status,
      freshDamage: model.hasCurrentConnectionDamage, demo: model.demo)
  }
  var body: some View {
    Image(nsImage: MenuBarArtwork.image(active: collecting, dark: colorScheme == .dark))
      .renderingMode(.original)
      .accessibilityLabel(collecting ? "HSR Damage Meter，战斗统计中" : "HSR Damage Meter，未在统计")
      .help(
        collecting ? "战斗统计中" : model.demo ? "演示模式" : model.status == .connected ? "等待战斗" : "未连接")
  }
}

@MainActor enum MenuBarArtwork {
  private static var cache: [String: NSImage] = [:]
  static func image(active: Bool, dark: Bool, sourceURL: URL? = nil) -> NSImage {
    let key = "\(active)-\(dark)-\(sourceURL?.path ?? "bundle")"
    if let cached = cache[key] { return cached }
    let result = NSImage(size: NSSize(width: 18, height: 18))
    let source =
      (sourceURL ?? Bundle.main.url(forResource: "MenuBarIcon@2x", withExtension: "png"))
      .flatMap { NSImage(contentsOf: $0) }
      ?? NSImage(systemSymbolName: "flame.fill", accessibilityDescription: nil)!
    for scale in [1, 2] {
      let side = 18 * scale
      let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: side * 4, bitsPerPixel: 32)!
      bitmap.bitmapData!.initialize(repeating: 0, count: side * side * 4)
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
      let bounds = NSRect(x: 0, y: 0, width: side, height: side)
      source.draw(in: bounds)
      let color = dark ? NSColor.white : NSColor.black
      color.withAlphaComponent(active ? 1 : 0.55).setFill()
      bounds.fill(using: .sourceIn)
      if active {
        let point = NSRect(x: 12 * scale, y: 0, width: 6 * scale, height: 6 * scale)
        // A contrast ring separates the badge from the symbol at small sizes.
        (dark ? NSColor.black : NSColor.white).setFill()
        NSBezierPath(ovalIn: point).fill()
        NSColor.systemGreen.setFill()
        NSBezierPath(ovalIn: point.insetBy(dx: CGFloat(scale), dy: CGFloat(scale))).fill()
      }
      NSGraphicsContext.restoreGraphicsState()
      bitmap.size = NSSize(width: 18, height: 18)
      result.addRepresentation(bitmap)
    }
    result.isTemplate = false  // Preserve the green badge; foreground follows menu appearance.
    cache[key] = result
    return result
  }
}
