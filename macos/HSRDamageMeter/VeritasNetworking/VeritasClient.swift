import Foundation

public enum ConnectionStatus: String, Sendable {
  case offline = "Collector 未连接"
  case connecting = "正在连接"
  case connected = "Collector 已连接"
  case incompatible = "Collector 版本未适配"
}

/// Minimal Engine.IO v4 / Socket.IO default-namespace text-event client.
/// No arbitrary hosts, binary events, gameplay commands, or unbounded event queues.
public actor VeritasClient {
  private var socket: URLSessionWebSocketTask?
  private let session: URLSession
  private var generation = 0
  private var lastMessage = ContinuousClock.now
  private var timeout: Double = 10
  private let port: UInt16

  public init(port: UInt16 = 1305) {
    self.port = port
    let configuration = URLSessionConfiguration.ephemeral
    configuration.connectionProxyDictionary = [:]
    session = URLSession(configuration: configuration)
  }

  public func disconnect() {
    generation += 1
    socket?.cancel(with: .goingAway, reason: nil)
    socket = nil
  }

  public func run(
    receive: @Sendable @escaping (VeritasEvent) async -> Void,
    status: @Sendable @escaping (ConnectionStatus) async -> Void
  ) async {
    generation += 1
    let current = generation
    var failures = 0
    let delays = [0, 1, 2, 5, 10]
    while !Task.isCancelled && generation == current {
      if failures > 0 {
        do { try await Task.sleep(for: .seconds(delays[min(failures, 4)])) } catch { return }
      }
      guard generation == current, !Task.isCancelled else { return }
      await status(.connecting)
      let ws = session.webSocketTask(
        with: URL(string: "ws://127.0.0.1:\(port)/socket.io/?EIO=4&transport=websocket")!)
      ws.maximumMessageSize = 4_194_304
      socket = ws
      timeout = 10
      lastMessage = .now
      ws.resume()
      let watchdog = Task { [weak self] in
        while !Task.isCancelled {
          do { try await Task.sleep(for: .seconds(1)) } catch { return }
          await self?.checkHeartbeat(ws)
        }
      }
      var verified = false
      do {
        while !Task.isCancelled && generation == current {
          let message = try await ws.receive()
          guard generation == current, !Task.isCancelled else { break }
          lastMessage = .now
          guard case .string(let text) = message else { throw CocoaError(.coderReadCorrupt) }
          switch try SocketFrame.decode(text) {
          case .open(let heartbeatTimeout):
            timeout = heartbeatTimeout
            try await ws.send(.string("40"))
          case .ping(let payload): try await ws.send(.string("3" + payload))
          case .event(let event):
            if case .connected(let version) = event {
              guard version == "0.2.52" else {
                await status(.incompatible)
                ws.cancel(with: .normalClosure, reason: nil)
                watchdog.cancel()
                return
              }
              verified = true
              failures = 0
              await receive(event)
              await status(.connected)
            } else if verified {
              // Await processing: preserve receive order without accumulating Tasks per event.
              await receive(event)
            }
          case .closed: throw URLError(.networkConnectionLost)
          default: break
          }
        }
      } catch {
        // User-facing state is intentionally independent of raw socket errors.
      }
      watchdog.cancel()
      ws.cancel(with: .goingAway, reason: nil)
      guard generation == current, !Task.isCancelled else { return }
      await status(.offline)
      failures += 1
    }
  }

  private func checkHeartbeat(_ ws: URLSessionWebSocketTask) {
    guard socket === ws else { return }
    if lastMessage.duration(to: .now) > .seconds(timeout) {
      ws.cancel(with: .goingAway, reason: nil)
    }
  }
}
