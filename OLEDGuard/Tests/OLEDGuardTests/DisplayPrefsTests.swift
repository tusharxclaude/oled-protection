import AppKit
import XCTest

@testable import OLEDGuard

final class DisplayPrefsTests: XCTestCase {
    private let key = "com.oledguard.selectedDisplayIDs"
    private var savedValue: Any?

    override func setUp() {
        super.setUp()
        savedValue = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
    }

    override func tearDown() {
        if let savedValue {
            UserDefaults.standard.set(savedValue, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
        super.tearDown()
    }

    private func requireScreen() throws -> NSScreen {
        guard let screen = NSScreen.screens.first else {
            throw XCTSkip("No screens available in this environment")
        }
        return screen
    }

    func testDefaultIsEmpty() {
        XCTAssertTrue(DisplayPrefs.selectedDisplayIDs().isEmpty)
    }

    func testToggleSelectsThenDeselects() throws {
        let screen = try requireScreen()

        XCTAssertFalse(DisplayPrefs.isSelected(screen))

        DisplayPrefs.toggle(screen)
        XCTAssertTrue(DisplayPrefs.isSelected(screen))

        DisplayPrefs.toggle(screen)
        XCTAssertFalse(DisplayPrefs.isSelected(screen))
    }

    func testSelectionPersistsAcrossReads() throws {
        let screen = try requireScreen()

        DisplayPrefs.toggle(screen)

        // A fresh read (simulating relaunch) should see the same selection.
        XCTAssertTrue(DisplayPrefs.isSelected(screen))
    }

    func testSelectedScreensReturnsOnlySelectedOnes() throws {
        let screen = try requireScreen()

        DisplayPrefs.toggle(screen)
        let selected = DisplayPrefs.selectedScreens()

        XCTAssertEqual(selected.count, 1)
        XCTAssertTrue(selected.first === screen)
    }

    func testSelectedScreensIgnoresStoredIDWithNoMatchingLiveScreen() {
        // Simulates the known gap: a display ID surviving in prefs after
        // the display was disconnected, reconnected on a different port,
        // or swapped through a dock. Should degrade to "not selected,"
        // not crash.
        UserDefaults.standard.set([999_999_999], forKey: key)

        XCTAssertTrue(DisplayPrefs.selectedScreens().isEmpty)
    }
}
