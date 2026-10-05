import Foundation
import Observation

/// Things that can go wrong, phrased for the person using Signa.
public enum LibraryError: LocalizedError, Equatable {
    case notAnApplication
    case protectedBySystem(name: String)
    case unreadableImage
    case needsPermission(name: String)
    case applicationMissing(name: String)
    case couldNotChangeIcon(name: String)
    case refused(name: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .notAnApplication:
            "That doesn't look like an application."
        case .protectedBySystem(let name):
            "macOS protects \(name) from changes, so it can't have a custom icon."
        case .unreadableImage:
            "Signa couldn't read that image."
        case .needsPermission(let name):
            "Signa needs your permission to change \(name)."
        case .applicationMissing(let name):
            "\(name) is no longer where it used to be."
        case .couldNotChangeIcon(let name):
            "The icon for \(name) couldn't be changed."
        case .refused(let name, let reason):
            "macOS wouldn't change \(name): \(reason)"
        }
    }
}

public enum ReconcileOutcome: Equatable, Sendable {
    case notGuarded
    case intact
    case restored
    case missing
    case needsPermission
    /// The application belongs to an administrator; only the user can approve the change.
    case needsPassword
}

/// The single source of truth for managed applications, and the only place
/// that changes them. The interface and the guardian both go through here.
@MainActor
@Observable
public final class AppLibrary {
    public private(set) var apps: [ManagedApp] = []

    /// Called after every change, once it has been saved.
    @ObservationIgnored public var didChange: (() -> Void)?

    @ObservationIgnored private let store: any LibraryStoring
    @ObservationIgnored private let assets: any IconAssetStoring
    @ObservationIgnored private let renderer: any IconRendering
    @ObservationIgnored private let provider: any IconProvider
    /// Used, with the user's password, for applications installed for all users.
    @ObservationIgnored private let administrator: (any IconProvider)?
    @ObservationIgnored private let inspector: any AppInspecting

    public init(
        store: any LibraryStoring,
        assets: any IconAssetStoring,
        renderer: any IconRendering,
        provider: any IconProvider,
        inspector: any AppInspecting,
        administrator: (any IconProvider)? = nil
    ) {
        self.store = store
        self.assets = assets
        self.renderer = renderer
        self.provider = provider
        self.administrator = administrator
        self.inspector = inspector
        do {
            apps = try store.load()
        } catch {
            Log.library.error("Could not read the library: \(error.localizedDescription)")
        }
    }

    public func app(_ id: ManagedApp.ID) -> ManagedApp? {
        apps.first { $0.id == id }
    }

    /// The `.icns` file behind an asset.
    public func iconURL(for asset: IconAsset.ID) -> URL {
        assets.iconURL(for: asset)
    }

    /// What it takes to change this application's icon.
    public func access(for id: ManagedApp.ID) -> AppAccess {
        app(id).map { inspector.access(to: $0.url) } ?? .sealed
    }

    /// The artwork the user originally provided for an asset.
    public func sourceURL(for asset: IconAsset.ID) -> URL? {
        assets.sourceURL(for: asset)
    }

    // MARK: - What the user can do

    /// Starts managing an application. Adding one that is already managed
    /// simply returns it.
    @discardableResult
    public func add(applicationAt url: URL) throws -> ManagedApp.ID {
        let url = url.standardizedFileURL
        guard let info = inspector.info(at: url) else { throw LibraryError.notAnApplication }
        if let existing = apps.first(where: { $0.url.path == url.path }) {
            return existing.id
        }
        guard inspector.access(to: url) != .sealed else {
            throw LibraryError.protectedBySystem(name: info.name)
        }
        let app = ManagedApp(
            bundleIdentifier: info.bundleIdentifier, applicationPath: url.path, name: info.name)
        apps.append(app)
        persist()
        return app.id
    }

    /// Turns an image into an icon and holds it ready for `apply`.
    public func stageIcon(from fileURL: URL, for id: ManagedApp.ID) async throws {
        let asset: IconAsset.ID
        do {
            asset = try await Task.detached(priority: .userInitiated) { [renderer, assets] in
                try assets.store(renderer.makeIcon(from: fileURL))
            }.value
        } catch {
            throw LibraryError.unreadableImage
        }
        update(id) { app in
            app.stagedIcon = asset == app.customIcon ? nil : asset
        }
        collectUnusedAssets()
    }

    /// Puts the chosen icon on the application. For an application installed
    /// for all users this asks for an administrator password first.
    public func apply(_ id: ManagedApp.ID) async throws {
        guard let app = app(id), let asset = app.stagedIcon ?? app.customIcon else { return }
        let iconURL = assets.iconURL(for: asset)
        do {
            let fingerprint: IconFingerprint
            do {
                fingerprint = try await provider.apply(iconAt: iconURL, to: app.url)
            } catch IconError.needsAdministrator {
                guard let administrator else { throw IconError.locked }
                fingerprint = try await administrator.apply(iconAt: iconURL, to: app.url)
            }
            update(id) {
                $0.customIcon = asset
                $0.stagedIcon = nil
                $0.appliedFingerprint = fingerprint
                $0.iconAppliedAt = .now
                $0.issue = nil
            }
            collectUnusedAssets()
        } catch IconError.cancelled {
            // The user changed their mind at the password prompt. Nothing happened.
        } catch let error as IconError {
            throw record(error, for: app)
        }
    }

    /// "Keep after updates".
    public func setKeepAfterUpdates(_ keep: Bool, for id: ManagedApp.ID) {
        update(id) { $0.enabled = keep }
    }

    /// Gives the application its own icon back. The custom icon stays at
    /// hand, staged, so the change is easy to undo.
    public func restoreOriginal(_ id: ManagedApp.ID) async throws {
        guard let app = app(id) else { return }
        do {
            do {
                try await provider.remove(from: app.url)
            } catch IconError.needsAdministrator {
                guard let administrator else { throw IconError.locked }
                try await administrator.remove(from: app.url)
            }
        } catch IconError.cancelled {
            return
        } catch let error as IconError {
            throw record(error, for: app)
        }
        update(id) {
            $0.stagedIcon = $0.stagedIcon ?? $0.customIcon
            $0.customIcon = nil
            $0.appliedFingerprint = nil
            $0.iconAppliedAt = nil
            $0.lastRestored = nil
            $0.issue = nil
        }
    }

    /// Stops managing the application. Whatever icon it has now is left alone.
    public func forget(_ id: ManagedApp.ID) {
        apps.removeAll { $0.id == id }
        persist()
        collectUnusedAssets()
    }

    // MARK: - Keeping icons in place

    /// Checks a kept application and restores its icon if an update removed it.
    @discardableResult
    public func reconcile(_ id: ManagedApp.ID) async -> ReconcileOutcome {
        guard let app = app(id), app.isGuarded, let asset = app.customIcon else { return .notGuarded }

        // Never write into something that is not the application we know.
        guard inspector.info(at: app.url)?.bundleIdentifier == app.bundleIdentifier else {
            update(id) { $0.issue = .missing }
            return .missing
        }

        let current = await provider.current(for: app.url)
        if let current, current == app.appliedFingerprint {
            update(id) { $0.issue = nil }
            return .intact
        }

        do {
            let fingerprint = try await provider.apply(iconAt: assets.iconURL(for: asset), to: app.url)
            update(id) {
                $0.appliedFingerprint = fingerprint
                $0.iconAppliedAt = .now
                $0.lastRestored = .now
                $0.issue = nil
            }
            Log.library.info("Restored the icon of \(app.name, privacy: .public)")
            return .restored
        } catch IconError.applicationNotFound {
            update(id) { $0.issue = .missing }
            return .missing
        } catch IconError.needsAdministrator {
            // A password prompt must never appear on its own. Wait until the user asks.
            update(id) { $0.issue = .needsPassword }
            return .needsPassword
        } catch {
            update(id) { $0.issue = .needsPermission }
            return .needsPermission
        }
    }

    /// Brings every record in line with what is actually on disk. Meant for
    /// moments when the user is looking, such as opening the window.
    public func refresh() async {
        for app in apps {
            if app.isGuarded {
                await reconcile(app.id)
                continue
            }
            guard inspector.info(at: app.url)?.bundleIdentifier == app.bundleIdentifier else {
                update(app.id) { $0.issue = .missing }
                continue
            }
            if app.issue == .missing {
                update(app.id) { $0.issue = nil }
            }
            guard let custom = app.customIcon else { continue }
            if await provider.current(for: app.url) != app.appliedFingerprint {
                // An update replaced the icon while it was not being kept.
                update(app.id) {
                    $0.stagedIcon = $0.stagedIcon ?? custom
                    $0.customIcon = nil
                    $0.appliedFingerprint = nil
                    $0.iconAppliedAt = nil
                }
            }
        }
    }

    // MARK: - Internals

    private func record(_ error: IconError, for app: ManagedApp) -> LibraryError {
        switch error {
        case .permissionDenied:
            update(app.id) { $0.issue = .needsPermission }
            return .needsPermission(name: app.name)
        case .applicationNotFound:
            update(app.id) { $0.issue = .missing }
            return .applicationMissing(name: app.name)
        case .locked, .needsAdministrator:
            return .protectedBySystem(name: app.name)
        case .unreadableIcon, .cancelled:
            return .couldNotChangeIcon(name: app.name)
        case .administratorFailed(let reason):
            return .refused(name: app.name, reason: reason)
        }
    }

    private func update(_ id: ManagedApp.ID, _ change: (inout ManagedApp) -> Void) {
        guard let index = apps.firstIndex(where: { $0.id == id }) else { return }
        var app = apps[index]
        change(&app)
        guard app != apps[index] else { return }
        apps[index] = app
        persist()
    }

    private func persist() {
        do {
            try store.save(apps)
        } catch {
            Log.library.error("Could not save the library: \(error.localizedDescription)")
        }
        didChange?()
    }

    private func collectUnusedAssets() {
        let used = Set(apps.flatMap { [$0.customIcon, $0.stagedIcon].compactMap { $0 } })
        for id in assets.allIDs() where !used.contains(id) {
            assets.remove(id)
        }
    }
}
