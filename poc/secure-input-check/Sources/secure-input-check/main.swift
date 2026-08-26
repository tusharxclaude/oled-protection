import AppKit
import Carbon.HIToolbox

/// Investigates the Logi Options "Secure Input" warning naming OLEDGuard.
/// Two things checked:
/// 1. Does BlackoutController's `.screenSaver`-level key window flip
///    macOS's IsSecureEventInputEnabled()? (No — see below.)
/// 2. Does `makeKeyAndOrderFront` alone, without `NSApp.activate`, make an
///    accessory-policy app the frontmost application? If yes, the
///    `activate(ignoringOtherApps:)` call in BlackoutController is what's
///    stealing frontmost-app status, and is removable.
final class Probe: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("before: IsSecureEventInputEnabled() =", IsSecureEventInputEnabled())

        let screen = NSScreen.main!
        let window = NSWindow(
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

        // Deliberately NOT calling NSApp.activate(ignoringOtherApps: true)
        // here, to isolate makeKeyAndOrderFront's effect on frontmost status.
        window.makeKeyAndOrderFront(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("after makeKeyAndOrderFront (no activate):")
            print("  IsSecureEventInputEnabled() =", IsSecureEventInputEnabled())
            print("  frontmostApplication =", NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")
            print("  NSApp.isActive =", NSApp.isActive)
            print("  window.isKeyWindow =", window.isKeyWindow)
            window.orderOut(nil)
            NSApp.terminate(nil)
        }
    }
}

let app = NSApplication.shared
let delegate = Probe()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
