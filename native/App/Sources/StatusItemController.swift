import AppKit
import VelloCapture
import VelloCore

/// The menu bar item. Mirrors Kap's behaviour: while recording, a left click stops,
/// Option-click pauses, and a right click opens the menu.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var durationTimer: Timer?
    private var state: RecordingState = .idle

    var onNewRecording: (() -> Void)?
    var onStop: (() -> Void)?
    var onTogglePause: (() -> Void)?
    var onPreferences: (() -> Void)?
    var onAbout: (() -> Void)?
    var onQuit: (() -> Void)?
    var elapsedProvider: (() -> TimeInterval)?

    private let settings: Settings

    init(settings: Settings) {
        self.settings = settings
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
        }
        apply(state: .idle)
    }

    isolated deinit {
        durationTimer?.invalidate()
    }

    func apply(state: RecordingState) {
        self.state = state

        guard let button = statusItem.button else { return }

        switch state {
        case .idle, .starting, .stopping:
            button.image = Self.symbol("record.circle", accessibility: "Vello")
            button.contentTintColor = nil
            button.title = ""
            stopDurationTimer()
        case .recording:
            button.image = Self.symbol("record.circle.fill", accessibility: "Recording")
            button.contentTintColor = .systemRed
            startDurationTimer()
        case .paused:
            button.image = Self.symbol("pause.circle.fill", accessibility: "Paused")
            button.contentTintColor = .systemOrange
            stopDurationTimer()
            updateDurationTitle()
        }
    }

    private static func symbol(_ name: String, accessibility: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: accessibility)
        image?.isTemplate = false
        return image
    }

    // MARK: - Duration readout

    private func startDurationTimer() {
        guard durationTimer == nil else { return }
        updateDurationTitle()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateDurationTitle() }
        }
        RunLoop.main.add(timer, forMode: .common)
        durationTimer = timer
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    private func updateDurationTitle() {
        let elapsed = elapsedProvider?() ?? 0
        statusItem.button?.title = " \(formatDuration(elapsed))"
    }

    // MARK: - Clicks

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        let opensMenu = event.type == .rightMouseUp || event.modifierFlags.contains(.control)

        switch state {
        case .idle, .starting, .stopping:
            present(idleMenu())
        case .recording:
            if opensMenu {
                present(recordingMenu())
            } else if event.modifierFlags.contains(.option) {
                onTogglePause?()
            } else {
                onStop?()
            }
        case .paused:
            if opensMenu {
                present(recordingMenu())
            } else {
                onTogglePause?()
            }
        }
    }

    /// Attaching the menu and re-clicking gives the correct highlight behaviour.
    private func present(_ menu: NSMenu) {
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Menus

    private func idleMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(item(title: "New Recording", key: "n") { [weak self] in self?.onNewRecording?() })
        menu.addItem(.separator())
        menu.addItem(item(title: "About Vello") { [weak self] in self?.onAbout?() })
        menu.addItem(item(title: "Preferences…", key: ",") { [weak self] in self?.onPreferences?() })
        menu.addItem(.separator())
        menu.addItem(microphoneMenuItem())
        menu.addItem(.separator())
        menu.addItem(item(title: "Quit Vello", key: "q") { [weak self] in self?.onQuit?() })

        return menu
    }

    private func recordingMenu() -> NSMenu {
        let menu = NSMenu()

        let duration = NSMenuItem(
            title: formatDuration(elapsedProvider?() ?? 0),
            action: nil,
            keyEquivalent: ""
        )
        duration.isEnabled = false
        menu.addItem(duration)
        menu.addItem(.separator())

        let pauseTitle = state == .paused ? "Resume Recording" : "Pause Recording"
        menu.addItem(item(title: pauseTitle) { [weak self] in self?.onTogglePause?() })
        menu.addItem(item(title: "Stop Recording") { [weak self] in self?.onStop?() })

        return menu
    }

    private func microphoneMenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "Microphone", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let off = item(title: "Off") { [weak self] in self?.settings.recordAudio = false }
        off.state = settings.recordAudio ? .off : .on
        submenu.addItem(off)
        submenu.addItem(.separator())

        let defaultName = CaptureDevices.defaultAudioInputDevice()?.name ?? "System Default"
        let systemDefault = item(title: "System Default (\(defaultName))") { [weak self] in
            self?.settings.recordAudio = true
            self?.settings.audioInputDeviceID = systemDefaultAudioDeviceID
        }
        systemDefault.state = settings.recordAudio
            && settings.audioInputDeviceID == systemDefaultAudioDeviceID ? .on : .off
        submenu.addItem(systemDefault)

        for device in CaptureDevices.audioInputDevices() {
            let deviceItem = item(title: device.name) { [weak self] in
                self?.settings.recordAudio = true
                self?.settings.audioInputDeviceID = device.id
            }
            deviceItem.state = settings.recordAudio && settings.audioInputDeviceID == device.id ? .on : .off
            submenu.addItem(deviceItem)
        }

        parent.submenu = submenu
        return parent
    }

    private func item(title: String, key: String = "", action: @escaping () -> Void) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: #selector(performBlock(_:)), keyEquivalent: key)
        menuItem.target = self
        menuItem.representedObject = BlockWrapper(action)
        return menuItem
    }

    @objc private func performBlock(_ sender: NSMenuItem) {
        (sender.representedObject as? BlockWrapper)?.action()
    }
}

private final class BlockWrapper {
    let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
}
