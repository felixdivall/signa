import Foundation
import SignaCore

/// The one place where concrete implementations are chosen and wired together.
@MainActor
struct AppEnvironment {
    let library: AppLibrary
    let guardian: IconGuardian

    static func live() -> AppEnvironment {
        // A development run can point at a throwaway library. It then also
        // leaves the Mac's login items alone.
        let override = ProcessInfo.processInfo.environment["SIGNA_DATA_DIRECTORY"]
        let directory =
            override.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? URL.applicationSupportDirectory.appendingPathComponent("Signa", isDirectory: true)
        let library = AppLibrary(
            store: JSONLibraryStore(directory: directory),
            assets: FileIconAssetStore(directory: directory),
            renderer: IconRenderer(),
            provider: WorkspaceIconProvider(),
            inspector: BundleAppInspector(),
            administrator: AdministratorIconProvider(helper: Bundle.main.executablePath ?? CommandLine.arguments[0]))
        let guardian = IconGuardian(
            library: library,
            monitors: [FSEventsMonitor(), WorkspaceEventMonitor()],
            loginItem: override == nil ? MainAppLoginItem() : InertLoginItem(),
            notifier: SystemNotifier())
        return AppEnvironment(library: library, guardian: guardian)
    }
}

private struct InertLoginItem: LoginItemControlling {
    func setEnabled(_ enabled: Bool) {}
}
