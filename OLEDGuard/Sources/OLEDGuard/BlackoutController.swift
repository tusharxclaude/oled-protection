import AppKit

/// Shows/hides a pure-black, borderless overlay window on user-selected
/// displays. No fade — OLED pixels switch near-instantly and a fade adds
/// cost with no visual benefit (see SPEC.md Feature 1).
final class BlackoutController {
    /// Fires on Escape, captured by the one overlay window made key.
    /// Guaranteed dismiss path — doesn't depend on the CGEventTap.
    var onEscape: (() -> Void)?

    private var overlayWindows: [BlackoutWindow] = []

    var isBlackedOut: Bool { !overlayWindows.isEmpty }
    var windowCount: Int { overlayWindows.count }

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

        // Only one window can be key at a time; keyboard focus isn't tied
        // to a physical screen, so making any single overlay key is enough
        // for Escape to work regardless of which display it's pressed "on."
        NSApp.activate(ignoringOtherApps: true)
        overlayWindows.first?.makeKeyAndOrderFront(nil)
        for window in overlayWindows.dropFirst() {
            window.orderFrontRegardless()
        }
    }

    func hide() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }
}
