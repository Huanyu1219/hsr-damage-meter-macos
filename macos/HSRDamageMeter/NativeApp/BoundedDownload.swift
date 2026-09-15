import Foundation

enum BoundedDownload {
  static let byteLimit = 25_000_000

  static func allowed(_ url: URL) -> Bool {
    url.scheme == "https" && ["hsr.nanoka.cc", "static.nanoka.cc"].contains(url.host ?? "")
      && url.user == nil && url.password == nil && (url.port == nil || url.port == 443)
  }

  private final class RedirectPolicy: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
      _ session: URLSession, task: URLSessionTask,
      willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
      completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
      completionHandler(request.url.map { allowed($0) } == true ? request : nil)
    }
  }

  // A nonisolated async operation: byte processing never runs on the UI actor.
  static func fetch(
    _ url: URL, limit: Int = byteLimit,
    configuration: URLSessionConfiguration = .ephemeral
  ) async throws -> Data {
    guard allowed(url), limit > 0 else { throw URLError(.badURL) }
    let session = URLSession(
      configuration: configuration, delegate: RedirectPolicy(), delegateQueue: nil)
    defer { session.invalidateAndCancel() }
    var request = URLRequest(
      url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
    request.setValue("application/json,text/html,image/webp", forHTTPHeaderField: "Accept")
    let (bytes, response) = try await session.bytes(for: request)
    guard let response = response as? HTTPURLResponse, response.statusCode == 200,
      let finalURL = response.url, allowed(finalURL)
    else { throw URLError(.badServerResponse) }
    guard response.expectedContentLength < Int64(limit) else {
      throw URLError(.dataLengthExceedsMaximum)
    }
    var data = Data()
    for try await byte in bytes {
      guard data.count < limit - 1 else { throw URLError(.dataLengthExceedsMaximum) }
      data.append(byte)
    }
    try Task.checkCancellation()
    return data
  }
}
