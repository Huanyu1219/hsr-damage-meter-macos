import AppKit
import Foundation
import XCTest

@testable import NativeApp

private final class DownloadFixture: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    let url = request.url!
    let headers = url.path == "/header" ? ["Content-Length": "100"] : [:]
    let response = HTTPURLResponse(
      url: url, statusCode: 200, httpVersion: "HTTP/1.1",
      headerFields: headers)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    for _ in 0..<(url.path == "/stream" ? 10 : 1) {
      client?.urlProtocol(self, didLoad: Data([1, 2, 3]))
    }
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

final class DownloadTests: XCTestCase {
  func testDeclaredAndStreamingDownloadLimits() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [DownloadFixture.self]
    let data = try await BoundedDownload.fetch(
      URL(string: "https://static.nanoka.cc/small")!,
      limit: 8, configuration: configuration)
    XCTAssertEqual(data, Data([1, 2, 3]))
    for path in ["header", "stream"] {
      do {
        _ = try await BoundedDownload.fetch(
          URL(string: "https://static.nanoka.cc/\(path)")!,
          limit: 8, configuration: configuration)
        XCTFail("Oversized response was accepted")
      } catch {
        XCTAssertEqual((error as? URLError)?.code, .dataLengthExceedsMaximum)
      }
    }
  }

  func testDownloadOriginPolicy() {
    for value in [
      "http://static.nanoka.cc/a", "https://static.nanoka.cc.evil.test/a",
      "https://localhost/a", "https://user@static.nanoka.cc/a", "https://static.nanoka.cc:444/a",
    ] {
      XCTAssertFalse(BoundedDownload.allowed(URL(string: value)!))
    }
    XCTAssertTrue(BoundedDownload.allowed(URL(string: "https://static.nanoka.cc/a")!))
  }

  @MainActor func testArtworkRejectsInvalidDataAndDownsamples() throws {
    XCTAssertNil(GameDataLibrary.thumbnail(Data("not an image".utf8)))
    let bitmap = try XCTUnwrap(
      NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 1024,
        pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
    let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    let image = try XCTUnwrap(GameDataLibrary.thumbnail(data))
    XCTAssertLessThanOrEqual(image.size.width, 512)
    XCTAssertLessThanOrEqual(image.size.height, 512)
  }
}
