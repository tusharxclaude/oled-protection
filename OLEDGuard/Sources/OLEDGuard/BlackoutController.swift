import AppKit
import CoreGraphics

/// Shows/hides a pure-black, borderless overlay window on user-selected
/// displays. No fade — OLED pixels switch near-instantly and a fade adds
/// cost with no visual benefit (see SPEC.md Feature 1).
final class BlackoutController {
    /// Fires on Escape, captured by the one overlay window made key.
    /// Fallback dismiss path for when Input Monitoring has lapsed — see
    /// `show(on:)`.
    var onEscape: (() -> Void)?

    private var overlayWindows: [BlackoutWindow] = []
    private let hasInputMonitoringAccess: () -> Bool
    private let activateApp: () -> Void

    var isBlackedOut: Bool { !overlayWindows.isEmpty }
    var windowCount: Int { overlayWindows.count }

    init(
        hasInputMonitoringAccess: @escaping () -> Bool = CGPreflightListenEventAccess,
        activateApp: @escaping () -> Void = { NSApp.activate(ignoringOtherApps: true) }
    ) {
        self.hasInputMonitoringAccess = hasInputMonitoringAccess
        self.activateApp = activateApp
    }

    func show(on screens: [NSScreen]) {
        guard overlayWindows.isEmpty else { return }

        for screen in screens {
            let window = BlackoutWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.backgroundColor = .black
            window.level = .screenSaver
            window.isOpaque = true
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            window.onEscape = { [weak self] in self?.onEscape?() }
            overlayWindows.append(window)
        }

        // Input Monitoring is a hard requirement at launch (IdleClock.start()
        // quits the app if it's missing), so in the overwhelmingly common
        // case the session-level CGEventTap is already delivering every
        // real keyDown/mouseMoved — Escape included — straight to
        // AppDelegate.handleRealInput(), independent of window key status.
        // Grabbing focus here is therefore unnecessary *and* has a real
        // cost: NSApp.activate(ignoringOtherApps:) makes OLEDGuard the
        // system-wide frontmost app for as long as the screen stays
        // blacked out (often hours), and there's no public API for other
        // apps to find who really owns Secure Input — Logitech Options
        // appears to fall back to blaming whichever app is currently
        // frontmost, which pinned it on OLEDGuard. So stay non-key here.
        //
        // Only fall back to grabbing key-window status (needed for plain
        // AppKit keyDown to reach BlackoutWindow.onEscape) if Input
        // Monitoring has lapsed *after* launch — e.g. the user revokes it
        // in System Settings, or a rebuild changes the code signature and
        // TCC silently drops the grant — which leaves the event tap blind.
        if hasInputMonitoringAccess() {
            for window in overlayWindows {
                window.orderFrontRegardless()
            }
        } else {
            activateApp()
            overlayWindows.first?.makeKeyAndOrderFront(nil)
            for window in overlayWindows.dropFirst() {
                window.orderFrontRegardless()
            }
        }
    }

    func hide() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }
}
