import XCTest

@testable import OLEDGuard

final class BlackoutPolicyTests: XCTestCase {
    func testBlacksOutWhenIdlePastThresholdUnpausedAndNoMic() {
        XCTAssertTrue(
            BlackoutPolicy.shouldBlackout(
                idleInterval: 300, threshold: 300, isPaused: false, isMicActive: false
            )
        )
    }

    func testStaysLitWhenBelowThreshold() {
        XCTAssertFalse(
            BlackoutPolicy.shouldBlackout(
                idleInterval: 299, threshold: 300, isPaused: false, isMicActive: false
            )
        )
    }

    func testStaysLitWhenPaused() {
        XCTAssertFalse(
            BlackoutPolicy.shouldBlackout(
                idleInterval: 600, threshold: 300, isPaused: true, isMicActive: false
            )
        )
    }

    func testStaysLitWhenMicActive() {
        XCTAssertFalse(
            BlackoutPolicy.shouldBlackout(
                idleInterval: 600, threshold: 300, isPaused: false, isMicActive: true
            )
        )
    }

    func testResetsIdleClockWhenMeetingEnds() {
        // Dropped off a Teams call: mic was active, now isn't.
        XCTAssertTrue(
            BlackoutPolicy.shouldResetIdleClockOnMeetingEnd(
                previousMicActive: true, currentMicActive: false
            )
        )
    }

    func testDoesNotResetOnFirstTickWithNoPriorMeeting() {
        // App just launched — nil means "nothing to have ended," not "was active."
        XCTAssertFalse(
            BlackoutPolicy.shouldResetIdleClockOnMeetingEnd(
                previousMicActive: nil, currentMicActive: false
            )
        )
    }

    func testDoesNotResetWhenMeetingStarts() {
        XCTAssertFalse(
            BlackoutPolicy.shouldResetIdleClockOnMeetingEnd(
                previousMicActive: false, currentMicActive: true
            )
        )
    }

    func testDoesNotResetWhileStillInMeeting() {
        XCTAssertFalse(
            BlackoutPolicy.shouldResetIdleClockOnMeetingEnd(
                previousMicActive: true, currentMicActive: true
            )
        )
    }

    func testDoesNotResetWhileStillOutOfMeeting() {
        XCTAssertFalse(
            BlackoutPolicy.shouldResetIdleClockOnMeetingEnd(
                previousMicActive: false, currentMicActive: false
            )
        )
    }

    func testNotPausedNeverExpires() {
        XCTAssertFalse(
            BlackoutPolicy.isPauseExpired(pauseExpiresAt: nil, now: Date())
        )
    }

    func testPauseNotYetExpired() {
        let now = Date()
        XCTAssertFalse(
            BlackoutPolicy.isPauseExpired(
                pauseExpiresAt: now.addingTimeInterval(1), now: now
            )
        )
    }

    func testPauseExpiredAtExactDeadline() {
        let now = Date()
        XCTAssertTrue(
            BlackoutPolicy.isPauseExpired(pauseExpiresAt: now, now: now)
        )
    }

    func testPauseExpiredPastDeadline() {
        let now = Date()
        XCTAssertTrue(
            BlackoutPolicy.isPauseExpired(
                pauseExpiresAt: now.addingTimeInterval(-1), now: now
            )
        )
    }
}
