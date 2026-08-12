import AppKit

/// Guaranteed dismiss path: standard AppKit keyDown handling, independent
/// of the CGEventTap/Input Monitoring permission entirely. Borderless
/// windows can't become key by default, so that's overridden here.
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
