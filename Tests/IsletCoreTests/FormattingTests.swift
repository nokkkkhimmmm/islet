import XCTest
@testable import IsletCore

final class FormattingTests: XCTestCase {
    func testTokenCountsUseCompactUnits() {
        XCTAssertEqual(Formatting.tokens(0), "0")
        XCTAssertEqual(Formatting.tokens(812), "812")
        XCTAssertEqual(Formatting.tokens(1_000), "1k")
        XCTAssertEqual(Formatting.tokens(45_300), "45.3k")
        XCTAssertEqual(Formatting.tokens(1_200_000), "1.2M")
    }

    func testWholeNumbersDropTheDecimal() {
        XCTAssertEqual(Formatting.tokens(45_000), "45k")
        XCTAssertEqual(Formatting.tokens(2_000_000), "2M")
    }

    func testElapsedTime() {
        let now = Date()
        XCTAssertEqual(Formatting.elapsed(since: now, now: now), "now")
        XCTAssertEqual(Formatting.elapsed(since: now.addingTimeInterval(-30), now: now), "30s")
        XCTAssertEqual(Formatting.elapsed(since: now.addingTimeInterval(-300), now: now), "5m")
        XCTAssertEqual(Formatting.elapsed(since: now.addingTimeInterval(-7_200), now: now), "2h")
    }

    func testRemainingTimeIsNilOnceElapsed() {
        let now = Date()
        XCTAssertNil(Formatting.remaining(until: now.addingTimeInterval(-1), now: now))
        XCTAssertEqual(Formatting.remaining(until: now.addingTimeInterval(600), now: now), "10m left")
        XCTAssertEqual(Formatting.remaining(until: now.addingTimeInterval(7_200), now: now), "2h left")
    }

    func testRateLimitWindowsAreNamedByDuration() {
        XCTAssertEqual(Formatting.windowName(minutes: 300), "5h limit")
        XCTAssertEqual(Formatting.windowName(minutes: 10_080), "Weekly limit")
        XCTAssertEqual(Formatting.windowName(minutes: nil), "Usage")
    }
}
