import AppKit

@main
enum VelloMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        // A menu-bar-only app has no ordinary windows to keep it alive. Prevent
        // macOS from automatically terminating Vello while its status item is idle.
        ProcessInfo.processInfo.disableAutomaticTermination("Vello is a menu bar application")
        // Vello lives in the menu bar; the dock icon only appears while a window is open.
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
