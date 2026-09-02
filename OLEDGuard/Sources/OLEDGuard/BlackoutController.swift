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

    var isBlackedOut: Bool { !overlayWindows.isEmpty }
    var windowCount: Int { overlayWindows.count }
    var isAnyWindowKey: Bool { overlayWindows.contains { $0.isKeyWindow } }

    init(hasInputMonitoringAccess: @escaping () -> Bool = CGPreflightListenEventAccess) {
        self.hasInputMonitoringAccess = hasInputMonitoringAccess
    }

    func show(on screens: [NSScreen]) {
        guard overlayWindows.isEmpty else { return }

        for screen in screens {
            let window = BlackoutWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
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
        // cost: becoming frontmost for as long as the screen stays blacked
        // out (often hours) means any background app that enables macOS
        // Secure Input during that window — there's no public API for
        // other apps to find who really owns it — gets misattributed to
        // whoever is frontmost, which pinned it on OLEDGuard via Logitech
        // Options. So stay non-key here.
        //
        // Only fall back to grabbing key-window status (needed for plain
        // AppKit keyDown to reach BlackoutWindow.onEscape) if Input
        // Monitoring has lapsed *after* launch — e.g. the user revokes it
        // in System Settings, or a rebuild changes the code signature and
        // TCC silently drops the grant — which leaves the event tap blind.
        // BlackoutWindow is a `.nonactivatingPanel`, so even this fallback
        // never activates the app: it can hold key status and receive the
        // Escape keyDown while a different app stays frontmost.
        if hasInputMonitoringAccess() {
            for window in overlayWindows {
                window.orderFrontRegardless()
            }
        } else {
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
