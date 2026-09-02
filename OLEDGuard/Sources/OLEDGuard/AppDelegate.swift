import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let idleClock: IdleClock
    private let blackout: BlackoutController
    private var pollTimer: Timer?
    private var statusItem: NSStatusItem?
    private var lastKnownMicActive: Bool?

    /// Real system dependencies by default; overridable so `tick()`'s
    /// orchestration (meeting-end idle reset, pause-expiry-then-blackout
    /// ordering, show/hide edge-triggering) can run deterministically in
    /// tests instead of against live CoreAudio/AppKit/wall-clock state.
    private let micActiveProvider: () -> Bool
    private let selectedScreensProvider: () -> [NSScreen]
    private let now: () -> Date
    private let pauseExpiredNotifier: () -> Void

    var isBlackedOut: Bool { blackout.isBlackedOut }

    private static let thresholdKey = "com.oledguard.idleThresholdSeconds"
    private static let pausedKey = "com.oledguard.isPaused"
    private static let pauseExpiresAtKey = "com.oledguard.pauseExpiresAt"
    private static let availableThresholds: [TimeInterval] = [60, 300, 600, 1800]

    /// Pause auto-expires rather than running indefinitely, so a forgotten
    /// pause can't silently leave OLED protection off forever.
    private static let pauseDuration: TimeInterval = 30 * 60
    private static let extendPauseActionIdentifier = "com.oledguard.extendPause"
    private static let pauseExpiredCategoryIdentifier = "com.oledguard.pauseExpired"

    init(
        idleClock: IdleClock = IdleClock(),
        blackout: BlackoutController = BlackoutController(),
        micActiveProvider: @escaping () -> Bool = MeetingExemption.isMicrophoneActive,
        selectedScreensProvider: @escaping () -> [NSScreen] = DisplayPrefs.selectedScreens,
        now: @escaping () -> Date = Date.init,
        pauseExpiredNotifier: @escaping () -> Void = AppDelegate.postPauseExpiredNotification
    ) {
        self.idleClock = idleClock
        self.blackout = blackout
        self.micActiveProvider = micActiveProvider
        self.selectedScreensProvider = selectedScreensProvider
        self.now = now
        self.pauseExpiredNotifier = pauseExpiredNotifier
        super.init()
    }

    private var idleThreshold: TimeInterval {
        get {
            let stored = UserDefaults.standard.double(forKey: Self.thresholdKey)
            return stored > 0 ? stored : 300
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.thresholdKey) }
    }

    private var isPaused: Bool {
        get { UserDefaults.standard.bool(forKey: Self.pausedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.pausedKey) }
    }

    private var pauseExpiresAt: Date? {
        get { UserDefaults.standard.object(forKey: Self.pauseExpiresAtKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.pauseExpiresAtKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "◐"
        statusItem = item

        rebuildMenu()
        setUpNotifications()

        idleClock.onRealInput = { [weak self] in
            DispatchQueue.main.async { self?.handleRealInput() }
        }
        blackout.onEscape = { [weak self] in
            DispatchQueue.main.async { self?.dismissBlackoutManually() }
        }

        guard idleClock.start() else {
            presentPermissionAlert()
            return
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(rebuildMenu),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func setUpNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let extendAction = UNNotificationAction(
            identifier: Self.extendPauseActionIdentifier,
            title: "Extend 30 more minutes",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.pauseExpiredCategoryIdentifier,
            actions: [extendAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])

        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                NSLog("[OLEDGuard] notification authorization failed: \(error)")
            }
        }
    }

    func tick() {
        let selectedScreens = selectedScreensProvider()
        guard !selectedScreens.isEmpty else { return }

        idleClock.pollSecureInputFallback()

        if isPaused, BlackoutPolicy.isPauseExpired(pauseExpiresAt: pauseExpiresAt, now: now()) {
            expirePause()
        }

        let micActive = micActiveProvider()
        if micActive != lastKnownMicActive {
            if BlackoutPolicy.shouldResetIdleClockOnMeetingEnd(
                previousMicActive: lastKnownMicActive, currentMicActive: micActive
            ) {
                idleClock.markInputNow()
            }
            NSLog("[OLEDGuard] meeting exemption active: \(micActive)")
            lastKnownMicActive = micActive
        }

        let shouldBlackout = BlackoutPolicy.shouldBlackout(
            idleInterval: idleClock.idleInterval,
            threshold: idleThreshold,
            isPaused: isPaused,
            isMicActive: micActive
        )

        if shouldBlackout, !blackout.isBlackedOut {
            blackout.show(on: selectedScreens)
        } else if !shouldBlackout, blackout.isBlackedOut {
            blackout.hide()
        }
    }

    private func handleRealInput() {
        if blackout.isBlackedOut {
            blackout.hide()
        }
    }

    /// Escape key or menu item — always works, independent of the
    /// CGEventTap/Input Monitoring permission.
    @objc private func dismissBlackoutManually() {
        idleClock.markInputNow()
        blackout.hide()
    }

    private func presentPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Input Monitoring Permission Needed"
        alert.informativeText =
            "OLED Guard needs Input Monitoring access to detect real keyboard/mouse "
            + "activity (and ignore Amphetamine's synthetic cursor-jiggle). "
            + "Grant it in System Settings > Privacy & Security > Input Monitoring, "
            + "then relaunch OLED Guard."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn,
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        {
            NSWorkspace.shared.open(url)
        }
        NSApp.terminate(nil)
    }

    /// Also re-run on `NSApplication.didChangeScreenParametersNotification`
    /// (see `applicationDidFinishLaunching`) so a display attached/detached
    /// after launch shows up in "OLED Displays" without a relaunch.
    @objc private func rebuildMenu() {
        let menu = NSMenu()

        menu.addItem(withTitle: "OLED Displays", action: nil, keyEquivalent: "").isEnabled = false
        for screen in NSScreen.screens {
            let name = screen.localizedName
            let menuItem = NSMenuItem(
                title: name, action: #selector(toggleDisplay(_:)), keyEquivalent: ""
            )
            menuItem.target = self
            menuItem.state = DisplayPrefs.isSelected(screen) ? .on : .off
            menuItem.representedObject = screen
            menu.addItem(menuItem)
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Blackout After", action: nil, keyEquivalent: "").isEnabled = false
        for threshold in Self.availableThresholds {
            let minutes = Int(threshold / 60)
            let menuItem = NSMenuItem(
                title: "\(minutes) min", action: #selector(setThreshold(_:)), keyEquivalent: ""
            )
            menuItem.target = self
            menuItem.state = idleThreshold == threshold ? .on : .off
            menuItem.representedObject = threshold
            menu.addItem(menuItem)
        }

        menu.addItem(.separator())
        let launchItem = NSMenuItem(
            title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())
        let pauseItem = NSMenuItem(
            title: "Pause Blackout", action: #selector(togglePaused), keyEquivalent: ""
        )
        pauseItem.target = self
        pauseItem.state = isPaused ? .on : .off
        menu.addItem(pauseItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit OLED Guard", action: #selector(quit), keyEquivalent: "q")
            .target = self

        statusItem?.menu = menu
    }

    @objc private func toggleDisplay(_ sender: NSMenuItem) {
        guard let screen = sender.representedObject as? NSScreen else { return }
        DisplayPrefs.toggle(screen)
        // Defensive: this menu click is itself real HID input the event
        // tap already saw, but an AX-driven click (e.g. scripted via
        // System Events) wouldn't register with the tap's hardware-source
        // filter, so a display newly opted in wouldn't get a fresh window.
        idleClock.markInputNow()
        rebuildMenu()
    }

    @objc private func setThreshold(_ sender: NSMenuItem) {
        guard let threshold = sender.representedObject as? TimeInterval else { return }
        idleThreshold = threshold
        rebuildMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
        rebuildMenu()
    }

    @objc private func togglePaused() {
        isPaused.toggle()
        if isPaused {
            pauseExpiresAt = Date().addingTimeInterval(Self.pauseDuration)
            blackout.hide()
        } else {
            pauseExpiresAt = nil
            // Resuming shouldn't instantly re-blackout because idle time
            // built up while paused — give it a fresh idle window.
            idleClock.markInputNow()
        }
        rebuildMenu()
    }

    /// Fires from `tick()` once `pauseExpiresAt` has passed — not a user
    /// action, so unlike the other toggles it has to rebuild the menu
    /// itself to keep the "Pause Blackout" checkmark from going stale.
    private func expirePause() {
        isPaused = false
        pauseExpiresAt = nil
        idleClock.markInputNow()
        pauseExpiredNotifier()
        rebuildMenu()
    }

    private func extendPause() {
        isPaused = true
        pauseExpiresAt = Date().addingTimeInterval(Self.pauseDuration)
        blackout.hide()
        rebuildMenu()
    }

    private static func postPauseExpiredNotification() {
        let content = UNMutableNotificationContent()
        content.title = "OLED Guard"
        content.body = "Pause expired after 30 minutes — blackout protection has resumed."
        content.categoryIdentifier = pauseExpiredCategoryIdentifier
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("[OLEDGuard] failed to deliver pause-expired notification: \(error)")
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == Self.extendPauseActionIdentifier {
            DispatchQueue.main.async { [weak self] in
                self?.extendPause()
            }
        }
        completionHandler()
    }
}
