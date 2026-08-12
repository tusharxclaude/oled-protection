import AppKit
import XCTest

@testable import OLEDGuard

/// A settable stand-in for wall-clock time, so tests can simulate elapsed
/// idle time and pause-expiry deadlines deterministically.
private final class TestClock {
    var current: Date

    init(_ date: Date = Date()) { current = date }

    func now() -> Date { current }

    func advance(by seconds: TimeInterval) {
        current = current.addingTimeInterval(seconds)
    }
}

final class AppDelegateTests: XCTestCase {
    // AppDelegate's threshold/pause state lives in UserDefaults.standard
    // under these keys (mirroring the private constants in AppDelegate.swift
    // — same convention DisplayPrefsTests uses for DisplayPrefs' key).
    private let thresholdKey = "com.oledguard.idleThresholdSeconds"
    private let pausedKey = "com.oledguard.isPaused"
    private let pauseExpiresAtKey = "com.oledguard.pauseExpiresAt"

    private var savedValues: [String: Any?] = [:]

    override func setUp() {
        super.setUp()
        for key in [thresholdKey, pausedKey, pauseExpiresAtKey] {
            savedValues[key] = UserDefaults.standard.object(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in [thresholdKey, pausedKey, pauseExpiresAtKey] {
            if let value = savedValues[key] ?? nil {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    private func requireScreens() throws -> [NSScreen] {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            throw XCTSkip("No screens available in this environment")
        }
        return screens
    }

    private func makeDelegate(
        clock: TestClock,
        micActive: @escaping () -> Bool,
        screens: [NSScreen]
    ) -> AppDelegate {
        AppDelegate(
            idleClock: IdleClock(now: clock.now),
            blackout: BlackoutController(),
            micActiveProvider: micActive,
            selectedScreensProvider: { screens },
            now: clock.now,
            pauseExpiredNotifier: {}  // avoid touching UNUserNotificationCenter in tests
        )
    }

    func testTickDoesNothingWhenNoDisplaysSelected() {
        let clock = TestClock()
        let delegate = makeDelegate(clock: clock, micActive: { false }, screens: [])

        delegate.tick()

        XCTAssertFalse(delegate.isBlackedOut)
    }

    func testTickBlacksOutAfterIdleThresholdWithoutMeeting() throws {
        let screens = try requireScreens()
        let clock = TestClock()
        UserDefaults.standard.set(TimeInterval(5), forKey: thresholdKey)
        let delegate = makeDelegate(clock: clock, micActive: { false }, screens: screens)

        clock.advance(by: 5)
        delegate.tick()

        XCTAssertTrue(delegate.isBlackedOut)
    }

    func testTickStaysLitWhenMicActiveDespiteIdleTime() throws {
        let screens = try requireScreens()
        let clock = TestClock()
        UserDefaults.standard.set(TimeInterval(5), forKey: thresholdKey)
        let delegate = makeDelegate(clock: clock, micActive: { true }, screens: screens)

        clock.advance(by: 100)
        delegate.tick()

        XCTAssertFalse(delegate.isBlackedOut)
    }

    func testTickResetsIdleClockExactlyWhenMeetingEndsSoLongMeetingDoesNotInstantlyBlackOut() throws {
        // Regression case for the AppDelegate.swift:98-107 wiring: idle time
        // that accumulated *during* a long meeting shouldn't count once the
        // meeting ends — the idle clock should get a fresh window instead of
        // instantly blacking out on the tick right after the call ends.
        let screens = try requireScreens()
        let clock = TestClock()
        UserDefaults.standard.set(TimeInterval(5), forKey: thresholdKey)
        var micActive = true
        let delegate = makeDelegate(clock: clock, micActive: { micActive }, screens: screens)

        delegate.tick()  // establishes lastKnownMicActive = true, no blackout (mic active)
        clock.advance(by: 1000)  // long meeting; idle clock never touched during it
        micActive = false
        delegate.tick()  // meeting ends this tick

        XCTAssertFalse(delegate.isBlackedOut)
    }

    func testTickAppliesPauseExpiryBeforeBlackoutCheckInTheSameTick() throws {
        // Regression case for AppDelegate.swift:94-96: pause expiry and the
        // blackout check happen in the same tick. Expiry gives the idle
        // clock a fresh window (same as manually resuming), so idle time
        // accrued *before* expiry shouldn't cause an immediate blackout.
        let screens = try requireScreens()
        let clock = TestClock()
        UserDefaults.standard.set(TimeInterval(5), forKey: thresholdKey)
        UserDefaults.standard.set(true, forKey: pausedKey)
        UserDefaults.standard.set(clock.now(), forKey: pauseExpiresAtKey)
        let delegate = makeDelegate(clock: clock, micActive: { false }, screens: screens)

        clock.advance(by: 10)  // idle for 10s, well past the 5s threshold
        delegate.tick()  // pause is already expired as of `now()`

        XCTAssertFalse(UserDefaults.standard.bool(forKey: pausedKey))
        XCTAssertFalse(delegate.isBlackedOut)
    }

    func testTickHidesBlackoutOnceRealInputArrives() throws {
        let screens = try requireScreens()
        let clock = TestClock()
        UserDefaults.standard.set(TimeInterval(5), forKey: thresholdKey)
        let idleClock = IdleClock(now: clock.now)
        let delegate = AppDelegate(
            idleClock: idleClock,
            blackout: BlackoutController(),
            micActiveProvider: { false },
            selectedScreensProvider: { screens },
            now: clock.now,
            pauseExpiredNotifier: {}
        )

        clock.advance(by: 5)
        delegate.tick()
        XCTAssertTrue(delegate.isBlackedOut)

        idleClock.markInputNow()
        delegate.tick()

        XCTAssertFalse(delegate.isBlackedOut)
    }
}
