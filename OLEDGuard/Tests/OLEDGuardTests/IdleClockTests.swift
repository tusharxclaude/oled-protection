import XCTest

@testable import OLEDGuard

final class IdleClockTests: XCTestCase {
    func testRealHardwareInputCounts() {
        XCTAssertTrue(IdleClock.isRealHardwareInput(sourcePID: 0, sourceStateID: 1))
    }

    func testSyntheticInputFromOtherProcessIsIgnored() {
        // Amphetamine-shaped: its own PID, combined-session state.
        XCTAssertFalse(IdleClock.isRealHardwareInput(sourcePID: 1234, sourceStateID: 0))
    }

    func testCombinedSessionStateFromRealPIDIsIgnored() {
        XCTAssertFalse(IdleClock.isRealHardwareInput(sourcePID: 0, sourceStateID: 0))
    }

    func testHIDStateFromOtherProcessIsIgnored() {
        XCTAssertFalse(IdleClock.isRealHardwareInput(sourcePID: 1234, sourceStateID: 1))
    }

    func testMarkInputNowResetsIdleInterval() {
        let clock = IdleClock()
        clock.markInputNow()
        XCTAssertLessThan(clock.idleInterval, 1)
    }

    func testSecureInputFallbackResetsClockOnRecentKeyDownDuringSecureInput() {
        var now = Date(timeIntervalSince1970: 1_000)
        let clock = IdleClock(
            now: { now },
            isSecureInputActive: { true },
            secondsSinceLastKeyDown: { 0.2 }
        )
        now = now.addingTimeInterval(200)
        clock.pollSecureInputFallback()
        XCTAssertLessThan(clock.idleInterval, 1)
    }

    func testSecureInputFallbackIgnoredWhenSecureInputNotActive() {
        var now = Date(timeIntervalSince1970: 1_000)
        let clock = IdleClock(
            now: { now },
            isSecureInputActive: { false },
            secondsSinceLastKeyDown: { 0.2 }
        )
        now = now.addingTimeInterval(200)
        clock.pollSecureInputFallback()
        XCTAssertEqual(clock.idleInterval, 200, accuracy: 0.01)
    }

    func testSecureInputFallbackIgnoredWhenKeyDownIsStale() {
        var now = Date(timeIntervalSince1970: 1_000)
        let clock = IdleClock(
            now: { now },
            isSecureInputActive: { true },
            secondsSinceLastKeyDown: { 30 }
        )
        now = now.addingTimeInterval(200)
        clock.pollSecureInputFallback()
        XCTAssertEqual(clock.idleInterval, 200, accuracy: 0.01)
    }

    func testSecureInputFallbackFiresOnRealInputCallback() {
        var now = Date(timeIntervalSince1970: 1_000)
        let clock = IdleClock(
            now: { now },
            isSecureInputActive: { true },
            secondsSinceLastKeyDown: { 0.2 }
        )
        var fired = false
        clock.onRealInput = { fired = true }
        now = now.addingTimeInterval(200)
        clock.pollSecureInputFallback()
        XCTAssertTrue(fired)
    }
}
