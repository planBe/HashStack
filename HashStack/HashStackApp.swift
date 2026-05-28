import SwiftUI

@main
struct HashStackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu-bar-only utility (LSUIElement). The Settings scene satisfies
        // SwiftUI's App lifecycle without creating a primary window; the
        // status bar item — owned by AppDelegate — is the only user-facing
        // surface.
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = StatusBarController()
        self.statusBarController = controller

        // ⌥⇧⌘H opens the popover from anywhere — see HotkeyManager for chord audit.
        self.hotkeyManager = HotkeyManager { [weak controller] in
            controller?.togglePopover(nil)
        }
    }
}
