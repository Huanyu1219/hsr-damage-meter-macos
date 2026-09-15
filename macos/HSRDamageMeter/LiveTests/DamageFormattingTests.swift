import Foundation
import LiveDomain
import XCTest

final class DamageFormattingTests: XCTestCase {
  func testSpecificationExamples() {
    let cases: [(Decimal, String)] = [
      (982, "982"), (1231, "1.23K"), (18231, "18.2K"), (182930, "183K"), (1_520_001, "1.52M"),
      (18_991_200, "19.0M"),
    ]
    for (input, expected) in cases { XCTAssertEqual(DamageFormatting.compact(input), expected) }
  }
  func testUnknownTimeAndZeroDamage() {
    XCTAssertEqual(DamageFormatting.dps(100, elapsed: 0), "—")
    XCTAssertEqual(DamageFormatting.dps(0, elapsed: 10), "0/s")
    XCTAssertEqual(DamageFormatting.duration(83), "01:23")
    XCTAssertEqual(DamageFormatting.duration(3661), "1:01:01")
    XCTAssertEqual(DamageFormatting.duration(.infinity), "—")
    XCTAssertEqual(DamageFormatting.compact(.nan), "—")
  }
  func testBarAndShareHaveDifferentDenominators() {
    XCTAssertEqual(DamageFormatting.ratio(60, to: 60), 1)
    XCTAssertEqual(DamageFormatting.ratio(60, to: 100), 0.6)
    XCTAssertEqual(DamageFormatting.ratio(0, to: 0), 0)
    XCTAssertEqual(DamageFormatting.compact(1_250_000_000), "1.25B")
    XCTAssertEqual(DamageFormatting.compact(1_250_000_000_000), "1.25T")
  }
}
