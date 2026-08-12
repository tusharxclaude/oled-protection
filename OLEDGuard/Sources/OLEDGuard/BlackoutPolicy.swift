import Foundation

/// Whether the idle blackout should be showing right now. Pure decision
/// logic (SPEC.md Feature 1) — no AppKit, no UserDefaults, no side effects.
/// `AppDelegate.tick()` gathers the inputs and executes the verdict; the
/// display-selection guard and mic-state logging are its concern, not this
/// module's (see SPEC.md Feature 1 exemption + Idle Detection sections).
enum BlackoutPolicy {
    static func shouldBlackout(
        idleInterval: TimeInterval,
        threshold: TimeInterval,
        isPaused: Bool,
        isMicActive: Bool
    ) -> Bool {
        !isPaused && !isMicActive && idleInterval >= threshold
    }

    /// Idle time that builds up while a meeting exempts the blackout
    /// doesn't reflect real inactivity going forward — the clock should
    /// get a fresh window the moment the meeting ends, same reasoning as
    /// the resume-from-pause reset in `AppDelegate`. `previousMicActive`
    /// is `nil` on the very first tick (no meeting to have ended), which
    /// correctly yields `false` here.
    static func shouldResetIdleClockOnMeetingEnd(
        previousMicActive: Bool?, currentMicActive: Bool
    ) -> Bool {
        previousMicActive == true && !currentMicActive
    }

    /// Pause has a fixed lifetime rather than running indefinitely, so a
    /// forgotten pause can't silently disable protection forever. `nil`
    /// means "not paused" — never expired.
    static func isPauseExpired(pauseExpiresAt: Date?, now: Date) -> Bool {
        guard let pauseExpiresAt else { return false }
        return now >= pauseExpiresAt
    }
}
