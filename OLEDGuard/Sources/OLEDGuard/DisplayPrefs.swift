import AppKit

/// Which displays the user has manually marked as OLED. No EDID-based
/// auto-detection (see SPEC.md "Explicitly Cut") — starts empty so nothing
/// blacks out until the user opts a display in.
enum DisplayPrefs {
    private static let key = "com.oledguard.selectedDisplayIDs"

    static func selectedDisplayIDs() -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: key) as? [Int] ?? [])
    }

    static func isSelected(_ screen: NSScreen) -> Bool {
        guard let id = screen.displayID else { return false }
        return selectedDisplayIDs().contains(Int(id))
    }

    static func toggle(_ screen: NSScreen) {
        guard let id = screen.displayID else { return }
        var ids = selectedDisplayIDs()
        if ids.contains(Int(id)) {
            ids.remove(Int(id))
        } else {
            ids.insert(Int(id))
        }
        UserDefaults.standard.set(Array(ids), forKey: key)
    }

    static func selectedScreens() -> [NSScreen] {
        let ids = selectedDisplayIDs()
        return NSScreen.screens.filter { screen in
            guard let id = screen.displayID else { return false }
            return ids.contains(Int(id))
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
