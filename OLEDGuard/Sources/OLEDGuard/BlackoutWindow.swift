import AppKit

/// Fallback dismiss path for when Input Monitoring has lapsed after launch:
/// standard AppKit keyDown handling, independent of the CGEventTap
/// entirely. Only reached when BlackoutController deliberately makes this
/// window key (see its `show(on:)`) — normally the event tap dismisses
/// blackout on any real input, Escape included, without this ever firing.
///
/// Subclasses NSPanel with `.nonactivatingPanel` so that becoming key
/// window never activates the app (see BlackoutController.show(on:) doc
/// comment) — nonactivating panels can hold key status and receive
/// keyDown while a different app stays frontmost. Borderless windows/
/// panels still never become key by default though, so `canBecomeKey`
/// still has to be overridden for the fallback path to receive Escape.
final class BlackoutWindow: NSPanel {
    var onEscape: (() -> Void)?

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: style.union(.nonactivatingPanel),
            backing: backingStoreType,
            defer: flag
        )
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // kVK_Escape
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}
