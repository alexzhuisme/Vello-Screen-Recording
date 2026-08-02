import AppKit

@main
enum VelloMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        // Vello lives in the menu bar; the dock icon only appears while a window is open.
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
