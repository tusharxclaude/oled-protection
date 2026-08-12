import CoreGraphics
import Foundation

/// Tracks time since the last *real* (hardware-sourced) mouse/keyboard event.
/// Validated in poc/eventtap-logger: real hardware input reports
/// sourcePID=0, sourceStateID=1 (kCGEventSourceStateHIDSystemState).
/// Amphetamine's synthetic cursor-jiggle reports its own PID and
/// sourceStateID=0 (kCGEventSourceStateCombinedSessionState), so it's
/// excluded by this filter without needing to track Amphetamine's PID.
final class IdleClock {
    private(set) var lastRealInputDate: Date
    var onRealInput: (() -> Void)?

    /// Injectable for tests that need to simulate elapsed idle time
    /// deterministically; defaults to the real system clock.
    private let now: () -> Date

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private static let eventsOfInterest: [CGEventType] = [
        .mouseMoved, .leftMouseDown, .leftMouseUp,
        .rightMouseDown, .rightMouseUp,
        .leftMouseDragged, .rightMouseDragged,
        .keyDown, .keyUp, .flagsChanged, .scrollWheel,
    ]

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
        self.lastRealInputDate = now()
    }

    var idleInterval: TimeInterval {
        now().timeIntervalSince(lastRealInputDate)
    }

    /// Real hardware input reports sourcePID=0, sourceStateID=1
    /// (kCGEventSourceStateHIDSystemState). Amphetamine's synthetic
    /// cursor-jiggle reports its own PID and sourceStateID=0
    /// (kCGEventSourceStateCombinedSessionState), so it's excluded here
    /// without needing to track Amphetamine's PID. Validated in
    /// poc/eventtap-logger.
    static func isRealHardwareInput(sourcePID: Int64, sourceStateID: Int64) -> Bool {
        sourcePID == 0 && sourceStateID == 1
    }

    /// Manual override path (Escape key, menu item) — bypasses the event
    /// tap entirely, so it works even if the tap has silently stopped
    /// delivering events (e.g. Input Monitoring permission lapsed).
    func markInputNow() {
        lastRealInputDate = now()
    }

    /// Returns false if Input Monitoring permission is missing.
    @discardableResult
    func start() -> Bool {
        var mask: CGEventMask = 0
        for type in Self.eventsOfInterest {
            mask |= (1 << type.rawValue)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: mask,
                callback: { proxy, type, event, refcon in
                    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                        if let refcon {
                            let clock = Unmanaged<IdleClock>.fromOpaque(refcon).takeUnretainedValue()
                            if let tap = clock.tap {
                                CGEvent.tapEnable(tap: tap, enable: true)
                            }
                        }
                        return Unmanaged.passUnretained(event)
                    }

                    let sourcePID = event.getIntegerValueField(.eventSourceUnixProcessID)
                    let sourceStateID = event.getIntegerValueField(.eventSourceStateID)
                    let isRealHardwareInput = IdleClock.isRealHardwareInput(
                        sourcePID: sourcePID, sourceStateID: sourceStateID
                    )

                    if isRealHardwareInput, let refcon {
                        let clock = Unmanaged<IdleClock>.fromOpaque(refcon).takeUnretainedValue()
                        clock.lastRealInputDate = clock.now()
                        clock.onRealInput?()
                    }

                    return Unmanaged.passUnretained(event)
                },
                userInfo: selfPtr
            )
        else {
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }
}
