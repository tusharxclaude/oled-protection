import Foundation
import ServiceManagement

/// User choice, not silently defaulted (see SPEC.md Architecture) — surfaced
/// as a menu toggle rather than a first-run onboarding step for this MVP.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("LaunchAtLogin toggle failed: \(error)")
        }
    }
}
