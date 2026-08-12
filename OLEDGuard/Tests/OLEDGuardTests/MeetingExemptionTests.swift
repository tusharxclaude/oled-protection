import XCTest

@testable import OLEDGuard

final class MeetingExemptionTests: XCTestCase {
    func testActiveWhenInputCapableAndRunning() {
        XCTAssertTrue(
            MeetingExemption.isDeviceActive(hasInputStreams: true, isRunningSomewhere: true)
        )
    }

    func testInactiveWhenNotRunning() {
        XCTAssertFalse(
            MeetingExemption.isDeviceActive(hasInputStreams: true, isRunningSomewhere: false)
        )
    }

    func testInactiveWhenOutputOnlyDeviceIsRunning() {
        // An output-only device (e.g. speakers) reports "running somewhere"
        // too — must be excluded, or playback alone would count as a meeting.
        XCTAssertFalse(
            MeetingExemption.isDeviceActive(hasInputStreams: false, isRunningSomewhere: true)
        )
    }

    func testInactiveWhenNeitherInputCapableNorRunning() {
        XCTAssertFalse(
            MeetingExemption.isDeviceActive(hasInputStreams: false, isRunningSomewhere: false)
        )
    }
}
