# Blackout window stays non-key when Input Monitoring is granted

Logitech Options started warning that OLEDGuard was "preventing your device from functioning properly" via its Secure Input diagnostic. Investigation (see `poc/secure-input-check`) ruled out the obvious cause — a `.screenSaver`-level key window does not flip `IsSecureEventInputEnabled()` on macOS 14.8.7 — and confirmed OLEDGuard never calls any Secure Input API. It also confirmed `BlackoutController.show()`'s `NSApp.activate(ignoringOtherApps: true)` genuinely makes the accessory-policy app the system-wide frontmost application for as long as the screen stays blacked out. Apple's TN2150 states there is no public API to find which process owns Secure Input, so third-party tools are left guessing; the most likely heuristic is "blame the frontmost app," which OLEDGuard was forcibly becoming every idle cycle.

Grabbing key-window status turned out to be unnecessary in the common case: Input Monitoring is a hard requirement at launch (`IdleClock.start()` quits the app if it's missing), so the session-level CGEventTap is already delivering every real keyDown — Escape included — to `AppDelegate.handleRealInput()` regardless of window key status. The AppKit `keyDown` path in `BlackoutWindow` only matters if Input Monitoring lapses *after* launch (user revokes it, or a rebuild changes the code signature and TCC silently drops the grant).

## Considered Options

- **Keep always activating + grabbing key window** — rejected: steals frontmost-app status for the entire blackout duration for no functional benefit in the common case, and is the likely cause of Logitech Options' misattributed Secure Input warning.
- **Remove the AppKit keyDown fallback entirely** — rejected: would leave the user with no way to dismiss blackout if Input Monitoring lapses mid-session, trading a compatibility fix for a real usability regression.
- **Only activate/grab key window when `CGPreflightListenEventAccess()` reports Input Monitoring is missing** — chosen: preserves the guaranteed-dismiss fallback for the rare permission-lapse case while leaving the app non-key (and not frontmost) in the normal case.
