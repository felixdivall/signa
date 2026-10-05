import Foundation
import Testing

@testable import SignaCore

@MainActor
@Suite struct GuardianTests {
    let scratch = try! Scratch()
    let provider = FakeIconProvider()
    let inspector = FakeInspector()
    let monitor = ManualMonitor()
    let loginItem = RecordingLoginItem()
    let notifier = RecordingNotifier()
    let appURL = URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true)

    func makeProtectedLibrary() async throws -> (AppLibrary, ManagedApp.ID) {
        inspector.install(AppInfo(bundleIdentifier: "com.example.codex", name: "Codex"), at: appURL)
        let library = AppLibrary(
            store: MemoryLibraryStore(), assets: FileIconAssetStore(directory: scratch.url),
            renderer: IconRenderer(), provider: provider, inspector: inspector)
        let id = try library.add(applicationAt: appURL)
        try await library.stageIcon(from: scratch.writeImage(TestImage.opaque(), named: "icon.png"), for: id)
        return (library, id)
    }

    func makeGuardian(for library: AppLibrary) -> IconGuardian {
        IconGuardian(
            library: library, monitors: [monitor], loginItem: loginItem, notifier: notifier,
            settleInterval: .milliseconds(100))
    }

    @Test func watchesOnlyWhatTheUserWantsKept() async throws {
        let (library, id) = try await makeProtectedLibrary()
        let guardian = makeGuardian(for: library)
        guardian.start()
        #expect(monitor.watched.isEmpty)
        #expect(!loginItem.isEnabled)

        try await library.apply(id)
        #expect(monitor.watched.map(\.url.path) == [appURL.path])
        #expect(loginItem.isEnabled)
        #expect(guardian.isGuarding)

        library.setKeepAfterUpdates(false, for: id)
        #expect(monitor.watched.isEmpty)
        #expect(!loginItem.isEnabled)
    }

    @Test func restoresOnceAnUpdateHasSettled() async throws {
        let (library, id) = try await makeProtectedLibrary()
        try await library.apply(id)
        let guardian = makeGuardian(for: library)
        guardian.start()

        provider.simulateUpdate(of: appURL)
        // A burst of events, as a real update produces, leads to a single restore.
        for _ in 0..<5 { monitor.send(.bundleChanged(appURL)) }

        #expect(await eventually { await provider.current(for: appURL) != nil })
        try await Task.sleep(for: .milliseconds(300))
        #expect(provider.applyCount == 2)
        #expect(library.app(id)?.lastRestored != nil)
        #expect(notifier.titles.isEmpty)
    }

    @Test func catchesUpOnLaunch() async throws {
        let (library, id) = try await makeProtectedLibrary()
        try await library.apply(id)
        provider.simulateUpdate(of: appURL)

        let guardian = makeGuardian(for: library)
        guardian.start()
        #expect(await eventually { await provider.current(for: appURL) != nil })
    }

    @Test func speaksUpOnlyWhenItCannotRestore() async throws {
        let (library, id) = try await makeProtectedLibrary()
        try await library.apply(id)
        let guardian = makeGuardian(for: library)
        guardian.start()

        provider.simulateUpdate(of: appURL)
        provider.fail(with: .permissionDenied)
        monitor.send(.applicationLaunched(bundleIdentifier: "com.example.codex"))
        #expect(await eventually { notifier.titles.count == 1 })

        // The same problem is not announced twice.
        monitor.send(.everythingMayHaveChanged)
        try await Task.sleep(for: .milliseconds(400))
        #expect(notifier.titles.count == 1)
        #expect(library.app(id)?.status == .needsPermission)
    }
}
