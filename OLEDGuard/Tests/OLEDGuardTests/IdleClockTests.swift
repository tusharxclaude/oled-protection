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
}
