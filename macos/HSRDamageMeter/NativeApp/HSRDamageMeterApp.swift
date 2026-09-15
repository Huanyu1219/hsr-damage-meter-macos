import AppKit
import SwiftUI

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
  weak var model: AppModel?
  private var terminating = false

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard let model else { return .terminateNow }
    if !terminating {
      terminating = true
      Task {
        await model.prepareForTermination()
        sender.reply(toApplicationShouldTerminate: true)
      }
    }
    return .terminateLater
  }
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
      let icon = NSImage(contentsOf: url)
    {
      NSApp.applicationIconImage = icon
    }
    NSApp.activate(ignoringOtherApps: true)
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main struct HSRDamageMeterApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  @State private var model = AppModel()
  @Environment(\.openWindow) private var openWindow

  var body: some Scene {
    Window("HSR Damage Meter", id: "dashboard") {
      LiveView(model: model).task {
        delegate.model = model
        model.start()
      }
    }.defaultSize(width: 1120, height: 760)
      .commands {
        CommandMenu("战斗面板") {
          Button("打开面板") { openWindow(id: "dashboard") }
            .keyboardShortcut("1", modifiers: [.command])
          Button("战斗历史") { openWindow(id: "history") }
            .keyboardShortcut("2", modifiers: [.command])
          Button(model.overlay.visible ? "隐藏浮窗" : "显示浮窗") {
            if model.overlay.visible {
              model.overlay.hide()
            } else {
              model.overlay.show(model: model)
            }
          }.keyboardShortcut("o", modifiers: [.command, .shift])
          Button("恢复浮窗操作") { model.overlay.recover(model: model) }
            .keyboardShortcut("o", modifiers: [.command, .option])
        }
      }
    Window("战斗历史", id: "history") {
      HistoryView(model: model).task {
        delegate.model = model
        model.start()
      }
    }.defaultSize(width: 1000, height: 720)
    MenuBarExtra {
      Text(model.demo ? "演示模式" : model.status.rawValue)
      Button("打开面板") {
        openWindow(id: "dashboard")
        NSApp.activate(ignoringOtherApps: true)
      }
      Divider()
      Button(model.overlay.visible ? "隐藏浮窗" : "显示浮窗") {
        if model.overlay.visible { model.overlay.hide() } else { model.overlay.show(model: model) }
      }
      Menu("浮窗模式") {
        ForEach(OverlayMode.allCases) { mode in
          Button(mode.label) { model.overlay.setMode(mode) }
        }
      }
      Toggle(
        "鼠标穿透",
        isOn: Binding(
          get: { model.overlay.clickThrough },
          set: { model.overlay.setClickThrough($0) }))
      Button("恢复浮窗操作") { model.overlay.recover(model: model) }
      Toggle(
        "所有桌面显示",
        isOn: Binding(
          get: { model.overlay.allSpaces },
          set: { model.overlay.setAllSpaces($0) }))
      Divider()
      Button("退出") { NSApp.terminate(nil) }.keyboardShortcut("q")
    } label: {
      MenuBarStatusLabel(model: model)
    }
  }
}
