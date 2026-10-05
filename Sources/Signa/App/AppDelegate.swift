import AppKit
import SignaCore

/// Owns the application's life cycle: a normal app while its window is open,
/// an invisible background presence while icons are being kept.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: AppEnvironment?
    private var model: LibraryViewModel?
    private var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let environment = AppEnvironment.live()
        self.environment = environment
        model = LibraryViewModel(library: environment.library, runningApps: WorkspaceRunningApps())
        NSApp.mainMenu = MainMenu.make()
        environment.guardian.start()

        if launchedAtLogin {
            // Started by macOS, not by the user: stay out of sight, or leave
            // entirely if there is nothing to keep.
            if !environment.guardian.isGuarding { NSApp.terminate(nil) }
            return
        }
        showMainWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showMainWindow()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        environment?.guardian.isGuarding != true
    }

    @objc func addApplication(_ sender: Any?) {
        showMainWindow()
        model?.chooseApplication()
    }

    private func showMainWindow() {
        guard let model else { return }
        NSApp.setActivationPolicy(.regular)
        if windowController == nil {
            windowController = MainWindowController(model: model) { [weak self] in
                self?.mainWindowDidClose()
            }
        }
        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        Task { await model.refresh() }
    }

    private func mainWindowDidClose() {
        windowController = nil
        model?.windowDidClose()
        // Keep working, without a Dock icon, for as long as there are icons to keep.
        if environment?.guardian.isGuarding == true {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private var launchedAtLogin: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
            event.eventID == kAEOpenApplication
        else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}
