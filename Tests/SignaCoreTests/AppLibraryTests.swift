import Foundation
import Testing

@testable import SignaCore

@MainActor
@Suite struct AppLibraryTests {
    let scratch = try! Scratch()
    let provider = FakeIconProvider()
    let inspector = FakeInspector()
    let store = MemoryLibraryStore()
    let appURL = URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true)
    let info = AppInfo(bundleIdentifier: "com.example.codex", name: "Codex")

    func makeLibrary() -> AppLibrary {
        AppLibrary(
            store: store, assets: FileIconAssetStore(directory: scratch.url), renderer: IconRenderer(),
            provider: provider, inspector: inspector)
    }

    /// A library with one application that has an applied, kept icon.
    func makeLibraryWithProtectedApp() async throws -> (AppLibrary, ManagedApp.ID) {
        inspector.install(info, at: appURL)
        let library = makeLibrary()
        let id = try library.add(applicationAt: appURL)
        try await library.stageIcon(from: scratch.writeImage(TestImage.opaque(), named: "icon.png"), for: id)
        try await library.apply(id)
        return (library, id)
    }

    @Test func theWholeFlowEndsProtected() async throws {
        inspector.install(info, at: appURL)
        let library = makeLibrary()

        let id = try library.add(applicationAt: appURL)
        #expect(library.app(id)?.status == .needsIcon)
        #expect(library.app(id)?.name == "Codex")

        try await library.stageIcon(from: scratch.writeImage(TestImage.opaque(), named: "icon.png"), for: id)
        #expect(library.app(id)?.status == .readyToApply)
        #expect(await provider.current(for: appURL) == nil)

        try await library.apply(id)
        #expect(library.app(id)?.status == .protected)
        #expect(await provider.current(for: appURL) == library.app(id)?.appliedFingerprint)
        #expect(library.app(id)?.iconAppliedAt != nil)

        // Everything survives a relaunch.
        #expect(makeLibrary().apps == library.apps)
    }

    @Test func addingTwiceKeepsOneEntry() throws {
        inspector.install(info, at: appURL)
        let library = makeLibrary()
        #expect(try library.add(applicationAt: appURL) == library.add(applicationAt: appURL))
        #expect(library.apps.count == 1)
    }

    @Test func refusesThingsItCannotManage() throws {
        let library = makeLibrary()
        #expect(throws: LibraryError.notAnApplication) { try library.add(applicationAt: appURL) }

        inspector.install(info, at: appURL, access: .sealed)
        #expect(throws: LibraryError.protectedBySystem(name: "Codex")) {
            try library.add(applicationAt: appURL)
        }
        #expect(library.apps.isEmpty)
    }

    @Test func restoresTheIconAfterAnUpdate() async throws {
        let (library, id) = try await makeLibraryWithProtectedApp()
        #expect(await library.reconcile(id) == .intact)
        #expect(provider.applyCount == 1)

        provider.simulateUpdate(of: appURL)
        #expect(await library.reconcile(id) == .restored)
        #expect(await provider.current(for: appURL) == library.app(id)?.appliedFingerprint)
        #expect(library.app(id)?.lastRestored != nil)

        // Checking again changes nothing.
        #expect(await library.reconcile(id) == .intact)
        #expect(provider.applyCount == 2)
    }

    @Test func leavesUnprotectedApplicationsAlone() async throws {
        let (library, id) = try await makeLibraryWithProtectedApp()
        library.setKeepAfterUpdates(false, for: id)
        provider.simulateUpdate(of: appURL)

        #expect(await library.reconcile(id) == .notGuarded)
        #expect(await provider.current(for: appURL) == nil)

        // Next time the user looks, the icon is offered again rather than claimed.
        await library.refresh()
        #expect(library.app(id)?.status == .readyToApply)
    }

    @Test func neverWritesIntoADifferentApplication() async throws {
        let (library, id) = try await makeLibraryWithProtectedApp()
        inspector.install(AppInfo(bundleIdentifier: "com.other.app", name: "Codex"), at: appURL)
        provider.simulateUpdate(of: appURL)

        #expect(await library.reconcile(id) == .missing)
        #expect(provider.applyCount == 1)
        #expect(library.app(id)?.status == .missing)

        // When the real application comes back, so does its icon.
        inspector.install(info, at: appURL)
        #expect(await library.reconcile(id) == .restored)
        #expect(library.app(id)?.status == .protected)
    }

    @Test func reportsWhenPermissionIsNeeded() async throws {
        let (library, id) = try await makeLibraryWithProtectedApp()
        provider.simulateUpdate(of: appURL)
        provider.fail(with: .permissionDenied)

        #expect(await library.reconcile(id) == .needsPermission)
        #expect(library.app(id)?.status == .needsPermission)

        provider.fail(with: nil)
        try await library.apply(id)
        #expect(library.app(id)?.status == .protected)
    }

    @Test func restoringTheOriginalKeepsTheCustomIconAtHand() async throws {
        let (library, id) = try await makeLibraryWithProtectedApp()
        let icon = library.app(id)?.customIcon

        try await library.restoreOriginal(id)
        #expect(await provider.current(for: appURL) == nil)
        #expect(library.app(id)?.customIcon == nil)
        #expect(library.app(id)?.stagedIcon == icon)
        #expect(library.app(id)?.iconAppliedAt == nil)
        #expect(library.app(id)?.isGuarded == false)
    }

    @Test func forgettingRemovesTheRecordAndItsIcons() async throws {
        let (library, id) = try await makeLibraryWithProtectedApp()
        let assets = FileIconAssetStore(directory: scratch.url)
        #expect(assets.allIDs().count == 1)

        library.forget(id)
        #expect(library.apps.isEmpty)
        #expect(assets.allIDs().isEmpty)
        // The application itself is untouched.
        #expect(await provider.current(for: appURL) != nil)
    }

    @Test func replacingAStagedIconDiscardsTheOldOne() async throws {
        let (library, id) = try await makeLibraryWithProtectedApp()
        let applied = library.app(id)?.customIcon

        try await library.stageIcon(from: scratch.writeImage(TestImage.cutOut(), named: "new.png"), for: id)
        #expect(library.app(id)?.customIcon == applied)
        #expect(library.app(id)?.status == .readyToApply)
        // The applied icon is still the one being kept until the new one is applied.
        provider.simulateUpdate(of: appURL)
        #expect(await library.reconcile(id) == .restored)

        try await library.apply(id)
        #expect(library.app(id)?.customIcon != applied)
        #expect(FileIconAssetStore(directory: scratch.url).allIDs().count == 1)
    }

    // MARK: - Applications installed for all users

    /// A library where the ordinary provider is refused and the administrator one is available.
    func makeAdministratorLibrary(_ administrator: FakeIconProvider) async throws -> (AppLibrary, ManagedApp.ID) {
        inspector.install(info, at: appURL, access: .administrator)
        provider.fail(with: .needsAdministrator)
        let library = AppLibrary(
            store: store, assets: FileIconAssetStore(directory: scratch.url), renderer: IconRenderer(),
            provider: provider, inspector: inspector, administrator: administrator)
        let id = try library.add(applicationAt: appURL)
        try await library.stageIcon(from: scratch.writeImage(TestImage.opaque(), named: "icon.png"), for: id)
        return (library, id)
    }

    @Test func asksAnAdministratorWhenTheApplicationBelongsToEveryone() async throws {
        let administrator = FakeIconProvider()
        let (library, id) = try await makeAdministratorLibrary(administrator)
        #expect(library.access(for: id) == .administrator)

        try await library.apply(id)
        #expect(administrator.applyCount == 1)
        #expect(library.app(id)?.status == .protected)
        #expect(library.app(id)?.appliedFingerprint == (await administrator.current(for: appURL)))

        try await library.restoreOriginal(id)
        #expect(await administrator.current(for: appURL) == nil)
        #expect(library.app(id)?.customIcon == nil)
    }

    @Test func decliningThePasswordPromptChangesNothing() async throws {
        let administrator = FakeIconProvider()
        administrator.fail(with: .cancelled)
        let (library, id) = try await makeAdministratorLibrary(administrator)

        try await library.apply(id)
        #expect(library.app(id)?.status == .readyToApply)
        #expect(library.app(id)?.issue == nil)
    }

    @Test func neverAsksForAPasswordOnItsOwn() async throws {
        let administrator = FakeIconProvider()
        let (library, id) = try await makeAdministratorLibrary(administrator)
        try await library.apply(id)

        // An update replaces the application while Signa is in the background.
        administrator.simulateUpdate(of: appURL)
        #expect(await library.reconcile(id) == .needsPassword)
        #expect(administrator.applyCount == 1)
        #expect(library.app(id)?.status == .needsPassword)

        // Once the user asks, the icon goes back.
        try await library.apply(id)
        #expect(administrator.applyCount == 2)
        #expect(library.app(id)?.status == .protected)
    }
}
