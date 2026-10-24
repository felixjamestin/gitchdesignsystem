import XCTest
@testable import GlitchDesignSystem

final class GlitchHoldPressTests: XCTestCase {
    func testEarlyReleaseCancelsCompletion() {
        var hold = GlitchHoldPress()
        XCTAssertTrue(hold.begin(.keyboard, now: 10))
        XCTAssertFalse(hold.complete(now: 10.49, duration: 0.5))
        XCTAssertTrue(hold.release(.keyboard))
        XCTAssertFalse(hold.complete(now: 11, duration: 0.5))
    }

    func testCompletedHoldFiresOnceUntilReleased() {
        var hold = GlitchHoldPress()
        XCTAssertTrue(hold.begin(.keyboard, now: 10))
        XCTAssertTrue(hold.complete(now: 10.5, duration: 0.5))
        XCTAssertFalse(hold.complete(now: 11, duration: 0.5))
        XCTAssertFalse(hold.begin(.keyboard, now: 11))
        XCTAssertTrue(hold.release(.keyboard))
        XCTAssertTrue(hold.begin(.keyboard, now: 12))
    }

    func testPointerAndKeyboardCannotCompleteOrCancelEachOther() {
        var hold = GlitchHoldPress()
        XCTAssertTrue(hold.begin(.pointer, now: 10))
        XCTAssertFalse(hold.begin(.keyboard, now: 10.1))
        XCTAssertFalse(hold.release(.keyboard))
        XCTAssertTrue(hold.complete(now: 10.5, duration: 0.5))
    }

    func testCancelDropsAPendingHold() {
        var hold = GlitchHoldPress()
        XCTAssertTrue(hold.begin(.keyboard, now: 10))
        hold.cancel()
        XCTAssertFalse(hold.complete(now: 11, duration: 0.5))
        XCTAssertTrue(hold.begin(.pointer, now: 12))
    }
}
