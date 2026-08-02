import AppKit
import VelloCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            let coordinator = AppCoordinator()
            self.coordinator = coordinator
            coordinator.start()
            Log.app.info("Vello launched")
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            guard let coordinator, coordinator.isRecording else { return .terminateNow }

            let alert = NSAlert()
            alert.messageText = "Stop recording and quit?"
            alert.informativeText = "The recording in progress will be discarded."
            alert.addButton(withTitle: "Discard and Quit")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .warning

            NSApp.activate()
            guard alert.runModal() == .alertFirstButtonReturn else { return .terminateCancel }

            Task {
                await coordinator.stopRecordingForTermination()
                NSApp.reply(toApplicationShouldTerminate: true)
            }
            return .terminateLater
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        TemporaryFiles.purge()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
