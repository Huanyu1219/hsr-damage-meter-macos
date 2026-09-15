import AppKit
import Observation
import SwiftUI

enum OverlayMode: String, CaseIterable, Identifiable {
  case minimal, compact, detailed
  var id: String { rawValue }
  var label: String {
    switch self {
    case .minimal: "极简"
    case .compact: "紧凑"
    case .detailed: "详细"
    }
  }
  var size: NSSize {
    switch self {
    case .minimal: NSSize(width: 240, height: 190)
    case .compact: NSSize(width: 320, height: 340)
    case .detailed: NSSize(width: 380, height: 360)
    }
  }
}

final class MeterPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  func shouldDrag(at point: NSPoint) -> Bool {
    guard !ignoresMouseEvents else { return false }
    // Leave the top-right mode menu and close button interactive.
    let controls = NSRect(x: frame.width - 86, y: frame.height - 44, width: 86, height: 44)
    return !controls.contains(point)
  }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .leftMouseDown, shouldDrag(at: event.locationInWindow) {
      performDrag(with: event)
      return
    }
    super.sendEvent(event)
  }
}

@MainActor @Observable final class OverlayController: NSObject, NSWindowDelegate {
  private(set) var visible = false
  private(set) var mode: OverlayMode
  private(set) var clickThrough: Bool
  private(set) var allSpaces: Bool
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private(set) var panel: MeterPanel?
  @ObservationIgnored private var configured = false
  @ObservationIgnored private var changingFrame = false

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    mode = OverlayMode(rawValue: defaults.string(forKey: "overlay.mode") ?? "") ?? .compact
    clickThrough = defaults.bool(forKey: "overlay.clickThrough")
    allSpaces = defaults.bool(forKey: "overlay.allSpaces")
    super.init()
    NotificationCenter.default.addObserver(
      self, selector: #selector(screensChanged),
      name: NSApplication.didChangeScreenParametersNotification, object: nil)
  }

  @objc private func screensChanged() {
    guard let panel else { return }
    panel.setFrame(
      Self.clamped(panel.frame, screens: NSScreen.screens.map(\.visibleFrame)), display: visible)
    saveFrame()
  }

  func restore(model: AppModel) {
    guard !configured else { return }
    configured = true
    if defaults.bool(forKey: "overlay.visible") { show(model: model) }
  }

  func prepare(model: AppModel) {
    guard panel == nil else { return }
    let window = MeterPanel(
      contentRect: NSRect(origin: .zero, size: mode.size),
      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    window.title = "伤害浮窗"
    window.level = .floating
    window.isFloatingPanel = true
    window.hidesOnDeactivate = false
    window.isReleasedWhenClosed = false
    window.isMovableByWindowBackground = true
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.contentView = NSHostingView(rootView: OverlayView(model: model, controller: self))
    window.delegate = self
    panel = window
    applyInteraction()
    let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let saved = defaults.string(forKey: "overlay.frame").map(NSRectFromString)
    let origin =
      saved.map { NSPoint(x: $0.minX, y: $0.maxY - mode.size.height) }
      ?? NSPoint(x: screen.maxX - mode.size.width - 24, y: screen.maxY - mode.size.height - 24)
    let frame = Self.clamped(
      NSRect(origin: origin, size: mode.size),
      screens: NSScreen.screens.map(\.visibleFrame))
    window.setFrame(frame, display: false)
  }

  func show(model: AppModel) {
    prepare(model: model)
    if let panel {
      panel.setFrame(
        Self.clamped(panel.frame, screens: NSScreen.screens.map(\.visibleFrame)), display: false)
      panel.orderFrontRegardless()
    }
    visible = true
    defaults.set(true, forKey: "overlay.visible")
  }

  func hide() {
    panel?.orderOut(nil)
    visible = false
    defaults.set(false, forKey: "overlay.visible")
  }

  func setMode(_ value: OverlayMode) {
    mode = value
    defaults.set(value.rawValue, forKey: "overlay.mode")
    guard let panel else { return }
    changingFrame = true
    let frame = NSRect(
      x: panel.frame.minX, y: panel.frame.maxY - value.size.height,
      width: value.size.width, height: value.size.height)
    panel.setFrame(
      Self.clamped(frame, screens: NSScreen.screens.map(\.visibleFrame)), display: true)
    changingFrame = false
    saveFrame()
  }

  func setClickThrough(_ value: Bool) {
    clickThrough = value
    defaults.set(value, forKey: "overlay.clickThrough")
    applyInteraction()
  }

  func setAllSpaces(_ value: Bool) {
    allSpaces = value
    defaults.set(value, forKey: "overlay.allSpaces")
    applyInteraction()
  }

  func recover(model: AppModel) {
    setClickThrough(false)
    show(model: model)
  }

  private func applyInteraction() {
    panel?.ignoresMouseEvents = clickThrough
    panel?.collectionBehavior =
      allSpaces
      ? [.canJoinAllSpaces, .fullScreenAuxiliary] : [.moveToActiveSpace, .fullScreenAuxiliary]
  }

  func windowDidMove(_ notification: Notification) {
    if !changingFrame { saveFrame() }
  }

  private func saveFrame() {
    if let panel { defaults.set(NSStringFromRect(panel.frame), forKey: "overlay.frame") }
  }

  static func clamped(_ frame: NSRect, screens: [NSRect]) -> NSRect {
    guard frame.origin.x.isFinite, frame.origin.y.isFinite else {
      return NSRect(origin: screens.first?.origin ?? .zero, size: frame.size)
    }
    guard
      let screen = screens.max(by: {
        $0.intersection(frame).area < $1.intersection(frame).area
      })
    else { return frame }
    return NSRect(
      x: min(max(frame.minX, screen.minX), max(screen.minX, screen.maxX - frame.width)),
      y: min(max(frame.minY, screen.minY), max(screen.minY, screen.maxY - frame.height)),
      width: frame.width, height: frame.height)
  }
}

extension NSRect {
  fileprivate var area: CGFloat { isNull ? 0 : width * height }
}
