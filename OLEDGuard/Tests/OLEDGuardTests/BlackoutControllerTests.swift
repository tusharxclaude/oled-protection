import AppKit
import XCTest

@testable import OLEDGuard

final class BlackoutControllerTests: XCTestCase {
    private func requireScreens() throws -> [NSScreen] {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            throw XCTSkip("No screens available in this environment")
        }
        return screens
    }

    func testShowCreatesOneWindowPerScreenAndMarksBlackedOut() throws {
        let screens = try requireScreens()
        let controller = BlackoutController()

        controller.show(on: screens)

        XCTAssertTrue(controller.isBlackedOut)
        XCTAssertEqual(controller.windowCount, screens.count)

        controller.hide()
    }

    func testShowIsNoOpWhenAlreadyBlackedOut() throws {
        let screens = try requireScreens()
        let controller = BlackoutController()

        controller.show(on: screens)
        let countAfterFirstShow = controller.windowCount
        controller.show(on: screens)

        XCTAssertEqual(controller.windowCount, countAfterFirstShow)

        controller.hide()
    }

    func testHideWhenNotShownIsNoOp() {
        let controller = BlackoutController()

        controller.hide()

        XCTAssertFalse(controller.isBlackedOut)
        XCTAssertEqual(controller.windowCount, 0)
    }

    func testHideClearsAllWindows() throws {
        let screens = try requireScreens()
        let controller = BlackoutController()

        controller.show(on: screens)
        controller.hide()

        XCTAssertFalse(controller.isBlackedOut)
        XCTAssertEqual(controller.windowCount, 0)
    }

    func testEscapeKeyDownFiresOnEscapeExactlyOnce() throws {
        let window = BlackoutWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        var escapeFireCount = 0
        window.onEscape = { escapeFireCount += 1 }

        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: 53  // kVK_Escape
            )
        )
        window.keyDown(with: event)

        XCTAssertEqual(escapeFireCount, 1)
    }

    func testNonEscapeKeyDownDoesNotFireOnEscape() throws {
        let window = BlackoutWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        var escapeFireCount = 0
        window.onEscape = { escapeFireCount += 1 }

        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                characters: "a",
                charactersIgnoringModifiers: "a",
                isARepeat: false,
                keyCode: 0  // kVK_ANSI_A
            )
        )
        window.keyDown(with: event)

        XCTAssertEqual(escapeFireCount, 0)
    }
}
