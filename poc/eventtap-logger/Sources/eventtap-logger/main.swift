import CoreGraphics
import Foundation

// POC for SPEC.md open risk #1: does kCGEventSourceUnixProcessID actually
// distinguish real hardware input from Amphetamine's synthetic cursor-jiggle?
//
// Run: swift run
// First launch will need Terminal added under
// System Settings > Privacy & Security > Input Monitoring.

let eventsOfInterest: [CGEventType] = [
    .mouseMoved,
    .leftMouseDown,
    .leftMouseUp,
    .keyDown,
    .flagsChanged,
]

var mask: CGEventMask = 0
for type in eventsOfInterest {
    mask |= (1 << type.rawValue)
}

func callback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let sourcePID = event.getIntegerValueField(.eventSourceUnixProcessID)
    let sourceStateID = event.getIntegerValueField(.eventSourceStateID)
    let sourceUserData = event.getIntegerValueField(.eventSourceUserData)

    let timestamp = DateFormatter.localizedString(
        from: Date(), dateStyle: .none, timeStyle: .medium
    )

    print(
        "[\(timestamp)] type=\(type.rawValue) "
            + "sourcePID=\(sourcePID) "
            + "sourceStateID=\(sourceStateID) "
            + "sourceUserData=\(sourceUserData)"
    )

    // Listen-only: pass every event through unmodified.
    return Unmanaged.passUnretained(event)
}

guard
    let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .listenOnly,
        eventsOfInterest: mask,
        callback: callback,
        userInfo: nil
    )
else {
    print("Failed to create event tap. Grant Terminal Input Monitoring permission in")
    print("System Settings > Privacy & Security > Input Monitoring, then re-run.")
    exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("Listening for mouse/keyboard events. Ctrl-C to stop.")
print("Move the mouse/type normally first, note the sourcePID, then trigger Amphetamine's jiggle.")
CFRunLoopRun()
