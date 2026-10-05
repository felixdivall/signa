import AppKit
import Observation
import SignaCore

/// Everything the interface needs to show and do. Views render this and
/// forward what the user does; they hold no logic of their own.
@MainActor
@Observable
final class LibraryViewModel {
    struct Notice: Identifiable, Equatable {
        let id = UUID()
        let text: String
    }

    let library: AppLibrary

    var selection: ManagedApp.ID?
    var notice: Notice?
    /// The application the user is being asked to confirm forgetting.
    var forgetCandidate: ManagedApp?
    private(set) var busy: Set<ManagedApp.ID> = []

    /// Changes whenever any application opens or quits, so views that depend on that redraw.
    private var runningAppsRevision = 0

    @ObservationIgnored private let runningApps: any RunningAppChecking
    @ObservationIgnored private let images = NSCache<NSString, NSImage>()
    @ObservationIgnored private var noticeDismissal: Task<Void, Never>?
    @ObservationIgnored private var workspaceObservers: [any NSObjectProtocol] = []

    init(library: AppLibrary, runningApps: any RunningAppChecking) {
        self.library = library
        self.runningApps = runningApps
        selection = library.apps.first?.id

        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspaceObservers.append(
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.runningAppsRevision += 1 }
                })
        }
    }

    var apps: [ManagedApp] { library.apps }

    var selectedApp: ManagedApp? {
        selection.flatMap { library.app($0) }
    }

    var protectedCount: Int {
        apps.count(where: \.isGuarded)
    }

    func isBusy(_ app: ManagedApp) -> Bool {
        busy.contains(app.id)
    }

    /// Whether changing this application's icon asks for an administrator password.
    func needsAdministrator(_ app: ManagedApp) -> Bool {
        library.access(for: app.id) == .administrator
    }

    /// True while the application is open and was opened before its icon was
    /// applied, which is when the Dock still shows the previous icon.
    func awaitsRelaunch(_ app: ManagedApp) -> Bool {
        _ = runningAppsRevision
        return app.awaitsRelaunch(runningApps.state(ofApplicationAt: app.url))
    }

    // MARK: - Adding and choosing

    /// Handles anything dropped on the window, or on one application's row.
    @discardableResult
    func handleDrop(_ urls: [URL], onto target: ManagedApp.ID? = nil) -> Bool {
        var target = target
        var image: URL?
        var sawUnsupported = false

        for url in urls {
            switch DroppedItem(url) {
            case .application(let url):
                if let id = add(applicationAt: url), urls.count > 1 || target == nil { target = id }
            case .image(let url):
                image = image ?? url
            case .unsupported:
                sawUnsupported = true
            }
        }

        if let image {
            guard let id = target ?? selection else {
                show("Drop an app first, then the image you want as its icon.")
                return false
            }
            selection = id
            stageIcon(from: image, for: id)
        } else if sawUnsupported {
            show("Signa works with apps and images.")
            return false
        }
        return true
    }

    func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose an App"
        panel.prompt = "Add"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach { add(applicationAt: $0) }
    }

    func chooseImage(for app: ManagedApp) {
        let panel = NSOpenPanel()
        panel.title = "Choose an Icon"
        panel.prompt = "Choose"
        panel.allowedContentTypes = DroppedItem.imageTypes
        guard panel.runModal() == .OK, let url = panel.url else { return }
        stageIcon(from: url, for: app.id)
    }

    @discardableResult
    private func add(applicationAt url: URL) -> ManagedApp.ID? {
        do {
            let id = try library.add(applicationAt: url)
            selection = id
            return id
        } catch {
            show(error)
            return nil
        }
    }

    private func stageIcon(from url: URL, for id: ManagedApp.ID) {
        perform(on: id) { try await self.library.stageIcon(from: url, for: id) }
    }

    // MARK: - Acting on an application

    func apply(_ app: ManagedApp) {
        perform(on: app.id) { try await self.library.apply(app.id) }
    }

    func setKeepAfterUpdates(_ keep: Bool, for app: ManagedApp) {
        library.setKeepAfterUpdates(keep, for: app.id)
    }

    func restoreOriginal(_ app: ManagedApp) {
        perform(on: app.id) { try await self.library.restoreOriginal(app.id) }
    }

    func forget(_ app: ManagedApp) {
        let index = apps.firstIndex { $0.id == app.id }
        library.forget(app.id)
        if selection == app.id {
            // Stay near where the user was in the list.
            selection = index.flatMap { apps.indices.contains($0) ? apps[$0].id : apps.last?.id }
        }
    }

    func showInFinder(_ app: ManagedApp) {
        NSWorkspace.shared.activateFileViewerSelecting([app.url])
    }

    func openPermissionSettings() {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles")
        else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Life cycle

    func refresh() async {
        await library.refresh()
        if selectedApp == nil { selection = apps.first?.id }
    }

    func windowDidClose() {
        images.removeAllObjects()
        notice = nil
    }

    // MARK: - Images

    /// The icon the application ships with.
    func originalIcon(of app: ManagedApp) -> NSImage {
        cached("original:\(app.applicationPath)") { AppIconReader.originalIcon(of: app.url) }
    }

    /// A finished icon from Signa's storage.
    func icon(for asset: IconAsset.ID) -> NSImage? {
        cached("icon:\(asset)") { NSImage(contentsOf: self.library.iconURL(for: asset)) }
    }

    /// The artwork the user provided for an asset.
    func artwork(for asset: IconAsset.ID) -> NSImage? {
        cached("artwork:\(asset)") {
            self.library.sourceURL(for: asset).flatMap { NSImage(contentsOf: $0) }
        }
    }

    private func cached(_ key: String, _ load: () -> NSImage) -> NSImage {
        if let image = images.object(forKey: key as NSString) { return image }
        let image = load()
        images.setObject(image, forKey: key as NSString)
        return image
    }

    private func cached(_ key: String, _ load: () -> NSImage?) -> NSImage? {
        if let image = images.object(forKey: key as NSString) { return image }
        guard let image = load() else { return nil }
        images.setObject(image, forKey: key as NSString)
        return image
    }

    // MARK: - Internals

    private func perform(on id: ManagedApp.ID, _ work: @escaping () async throws -> Void) {
        busy.insert(id)
        Task {
            defer { busy.remove(id) }
            do {
                try await work()
            } catch {
                show(error)
            }
        }
    }

    private func show(_ error: any Error) {
        // Permission problems get their own explanation next to the application.
        if case LibraryError.needsPermission = error { return }
        show(error.localizedDescription)
    }

    private func show(_ text: String) {
        let notice = Notice(text: text)
        self.notice = notice
        noticeDismissal?.cancel()
        noticeDismissal = Task {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled, self.notice == notice { self.notice = nil }
        }
    }
}
