import Foundation

/// Decides *when* icons get checked. The library decides *what* happens.
///
/// The guardian keeps the monitors pointed at the applications the user wants
/// kept, waits for an update to finish before touching anything, and only
/// speaks up when it cannot do its job.
@MainActor
public final class IconGuardian {
    private let library: AppLibrary
    private let monitors: [any AppChangeMonitor]
    private let loginItem: any LoginItemControlling
    private let notifier: any UserNotifying
    private let settleInterval: Duration

    private var watched: [WatchedApp]?
    private var listeners: [Task<Void, Never>] = []
    private var pending: [ManagedApp.ID: Task<Void, Never>] = [:]
    private var reported: Set<ManagedApp.ID> = []

    /// - Parameter settleInterval: How long an application must stay quiet
    ///   before its icon is restored, so an update in progress is never disturbed.
    public init(
        library: AppLibrary,
        monitors: [any AppChangeMonitor],
        loginItem: any LoginItemControlling,
        notifier: any UserNotifying,
        settleInterval: Duration = .seconds(3)
    ) {
        self.library = library
        self.monitors = monitors
        self.loginItem = loginItem
        self.notifier = notifier
        self.settleInterval = settleInterval
    }

    /// Whether any application is currently being kept.
    public var isGuarding: Bool {
        library.apps.contains(where: \.isGuarded)
    }

    public func start() {
        library.didChange = { [weak self] in self?.sync() }
        sync()
        for monitor in monitors {
            listeners.append(
                Task { [weak self] in
                    for await change in monitor.changes {
                        self?.handle(change)
                    }
                })
        }
        // Catch up on anything that changed while Signa was not running.
        for app in library.apps where app.isGuarded {
            Task { await self.check(app.id) }
        }
    }

    public func stop() {
        listeners.forEach { $0.cancel() }
        listeners = []
        pending.values.forEach { $0.cancel() }
        pending = [:]
        library.didChange = nil
    }

    private func sync() {
        let guarded = library.apps.filter(\.isGuarded)
            .map { WatchedApp(url: $0.url, bundleIdentifier: $0.bundleIdentifier) }
        guard guarded != watched else { return }
        watched = guarded
        monitors.forEach { $0.watch(guarded) }
        loginItem.setEnabled(!guarded.isEmpty)
    }

    private func handle(_ change: AppChange) {
        for app in library.apps where app.isGuarded {
            switch change {
            case .bundleChanged(let url) where url.path == app.url.path: scheduleCheck(app.id)
            case .applicationLaunched(let identifier) where identifier == app.bundleIdentifier:
                scheduleCheck(app.id)
            case .everythingMayHaveChanged: scheduleCheck(app.id)
            default: break
            }
        }
    }

    /// Every new event pushes the check back, so it runs once things are quiet.
    private func scheduleCheck(_ id: ManagedApp.ID) {
        pending[id]?.cancel()
        pending[id] = Task { [weak self, settleInterval] in
            try? await Task.sleep(for: settleInterval)
            guard !Task.isCancelled, let self else { return }
            self.pending[id] = nil
            await self.check(id)
        }
    }

    private func check(_ id: ManagedApp.ID) async {
        switch await library.reconcile(id) {
        case .needsPermission:
            guard reported.insert(id).inserted, let app = library.app(id) else { return }
            notifier.notify(
                title: "Signa needs your permission",
                body: "\(app.name) was updated. Open Signa to put its icon back.")
        case .needsPassword:
            guard reported.insert(id).inserted, let app = library.app(id) else { return }
            notifier.notify(
                title: "Signa needs your password",
                body: "\(app.name) was updated. Open Signa to put its icon back.")
        case .intact, .restored:
            reported.remove(id)
        case .missing, .notGuarded:
            break
        }
    }
}
