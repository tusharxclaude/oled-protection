import AppKit

/// Fallback dismiss path for when Input Monitoring has lapsed after launch:
/// standard AppKit keyDown handling, independent of the CGEventTap
/// entirely. Only reached when BlackoutController deliberately makes this
/// window key (see its `show(on:)`) — normally the event tap dismisses
/// blackout on any real input, Escape included, without this ever firing.
/// Borderless windows can't become key by default, so that's overridden
/// here.
final class BlackoutWindow: NSWindow {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // kVK_Escape
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}
