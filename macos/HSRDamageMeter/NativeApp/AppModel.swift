import Foundation
import LiveDomain
import Observation
import VeritasNetworking

@MainActor @Observable
final class AppModel {
  var status: ConnectionStatus = .offline
  var snapshot = LiveSnapshot()
  var version = "—"
  var demo = false
  private(set) var hasCurrentConnectionDamage = false
  let gameData = GameDataLibrary()
  let overlay = OverlayController()
  let store = LiveCombatStore()
  var historyMessage: String?
  private let client = VeritasClient()
  private var connection: Task<Void, Never>?
  private var publication: Task<Void, Never>?
  private var lastRetentionCheck = Date.distantPast
  private var retention: Task<Void, Never>?

  func start() {
    overlay.restore(model: self)
    guard publication == nil, !demo else { return }

    if ProcessInfo.processInfo.arguments.contains("--demo")
      || Bundle.main.object(forInfoDictionaryKey: "HSRPreviewScenario") != nil
    {
      demo = true
      Task { await loadDemo() }
    } else {
      publication = Task { [weak self] in
        while !Task.isCancelled {
          guard let self else { return }
          if retention == nil, Date().timeIntervalSince(lastRetentionCheck) > 3600 {
            lastRetentionCheck = Date()
            retention = Task { [weak self, store] in
              guard let self else { return }
              defer { retention = nil }
              do {
                try await store.setHistoryRetention(
                  days: UserDefaults.standard.integer(forKey: "history.retentionDays"))
              } catch { lastRetentionCheck = Date().addingTimeInterval(-3540) }
            }
          }
          let next = await store.currentSnapshot()
          historyMessage = await store.historyError
          if next != snapshot { snapshot = next }
          try? await Task.sleep(for: .milliseconds(100))
        }
      }
      Task {
        let directory = FileManager.default.urls(
          for: .applicationSupportDirectory, in: .userDomainMask)[0]
          .appendingPathComponent("HSRDamageMeter", isDirectory: true)
        await store.enableHistory(at: directory.appendingPathComponent("battles.sqlite"))
        reconnect()
      }
    }
  }

  func reconnect() {
    connection?.cancel()
    connection = Task { [weak self] in
      guard let self else { return }
      await client.disconnect()
      await store.disconnected()
      await client.run(
        receive: { [weak self, store] event in
          await store.consume(event)
          await self?.trackMenuActivity(event)
          if case .connected(let version) = event { await self?.setVersion(version) }
        },
        status: { [weak self, store] status in
          if status != .connected { await store.disconnected() }
          await self?.setStatus(status)
        })
    }
  }

  func reset() {
    if demo { snapshot = LiveSnapshot() } else { Task { await store.reset() } }
  }
  func prepareForTermination() async {
    publication?.cancel()
    connection?.cancel()
    await client.disconnect()
    await connection?.value
    await retention?.value
    await store.finishHistory()
  }
  private func setVersion(_ value: String) { version = value }
  private func setStatus(_ value: ConnectionStatus) {
    status = value
    if value != .connected { hasCurrentConnectionDamage = false }
  }
  private func trackMenuActivity(_ event: VeritasEvent) {
    switch event {
    case .connected, .lineup, .begin, .end:
      hasCurrentConnectionDamage = false
    case .damage(let value) where value.attacker.team == "Player":
      hasCurrentConnectionDamage = true
    default: break
    }
  }

  private func loadDemo() async {
    snapshot =
      Bundle.main.object(forInfoDictionaryKey: "HSRPreviewScenario") as? String == "large"
      ? PreviewFactory.largeDamageNumbers().snapshot : PreviewFactory.snapshot()
    version = "0.2.52 · 演示"
  }
}
