import CoreAudio
import Foundation

/// Approximates "in a meeting" (not "media is playing") by checking whether
/// any input device is actively captured. Public CoreAudio API, chosen over
/// the private MediaRemote framework the spec originally considered, since
/// MediaRemote would also exempt e.g. watching a video.
///
/// Checks every input-capable device, not just the system default — a
/// meeting app can be using a mic that isn't the macOS default input.
///
/// Assumption to verify: Teams/Zoom/etc. keep the input device open even
/// when locally muted (common, for near-instant unmute) — if an app instead
/// releases the device on mute, muted meetings won't be exempted.
enum MeetingExemption {
    static func isMicrophoneActive() -> Bool {
        allDeviceIDs().contains { deviceID in
            isDeviceActive(hasInputStreams: hasInputStreams(deviceID), isRunningSomewhere: isRunningSomewhere(deviceID))
        }
    }

    /// A device counts toward the meeting exemption only if it's capable of
    /// input at all (output-only devices report "running" too) and is
    /// currently capturing. Pulled out as a pure function so the decision
    /// is unit-testable without a real CoreAudio device.
    static func isDeviceActive(hasInputStreams: Bool, isRunningSomewhere: Bool) -> Bool {
        hasInputStreams && isRunningSomewhere
    }

    private static func allDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var propertySize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize
        )
        guard sizeStatus == noErr, propertySize > 0 else { return [] }

        let count = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        let dataStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceIDs
        )
        guard dataStatus == noErr else { return [] }
        return deviceIDs
    }

    private static func hasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var propertySize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &propertySize)
        return status == noErr && propertySize > 0
    }

    private static func isRunningSomewhere(_ deviceID: AudioDeviceID) -> Bool {
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &isRunning)
        return status == noErr && isRunning != 0
    }
}
