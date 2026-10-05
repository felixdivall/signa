import Foundation
import Testing

@testable import SignaCore

/// These run against the real macOS mechanisms, on throwaway applications.
@MainActor
@Suite(.serialized) struct RealSystemTests {
    let scratch = try! Scratch()

    func makeIconFile() throws -> URL {
        let icon = try IconRenderer().makeIcon(from: scratch.writeImage(TestImage.opaque(), named: "art.png"))
        let file = scratch.url.appendingPathComponent("icon.icns")
        try icon.icns.write(to: file)
        return file
    }

    @Test func appliesReadsAndRemovesARealIcon() async throws {
        let app = try scratch.makeApp()
        let provider = WorkspaceIconProvider()
        #expect(await provider.current(for: app) == nil)

        let fingerprint = try await provider.apply(iconAt: makeIconFile(), to: app)
        #expect(await provider.current(for: app) == fingerprint)
        // The application's own contents are not touched.
        #expect(try FileManager.default.contentsOfDirectory(atPath: app.path).sorted() == ["Contents", "Icon\r"])

        try await provider.remove(from: app)
        #expect(await provider.current(for: app) == nil)
    }

    /// Finder only notices a changed custom icon when the old one is taken off first.
    @Test func replacingAnAppliedIconInstallsTheNewOne() async throws {
        let app = try scratch.makeApp(named: "Twice")
        let provider = WorkspaceIconProvider()
        let first = try await provider.apply(iconAt: makeIconFile(), to: app)

        let other = try IconRenderer().makeIcon(from: scratch.writeImage(TestImage.cutOut(), named: "other.png"))
        let otherFile = scratch.url.appendingPathComponent("other.icns")
        try other.icns.write(to: otherFile)
        let second = try await provider.apply(iconAt: otherFile, to: app)

        #expect(second != first)
        #expect(await provider.current(for: app) == second)
    }

    /// The administrator path hands the job to Signa's helper mode.
    /// Run here as the current user, on a throwaway application.
    @Test func theAdministratorPathInstallsReplacesAndRemovesAnIcon() async throws {
        let app = try scratch.makeApp(named: "Shared App")
        // The helper is Signa's own program; the build puts it next to the tests.
        let helper = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/debug/Signa").path
        try #require(FileManager.default.isExecutableFile(atPath: helper))
        let provider = AdministratorIconProvider(shell: UnprivilegedShell(), helper: helper)

        let first = try await provider.apply(iconAt: makeIconFile(), to: app)
        #expect(await WorkspaceIconProvider().current(for: app) == first)
        #expect(try FileManager.default.contentsOfDirectory(atPath: app.path).sorted() == ["Contents", "Icon\r"])

        let other = try IconRenderer().makeIcon(from: scratch.writeImage(TestImage.cutOut(), named: "other.png"))
        let otherFile = scratch.url.appendingPathComponent("other.icns")
        try other.icns.write(to: otherFile)
        let second = try await provider.apply(iconAt: otherFile, to: app)
        #expect(second != first)

        try await provider.remove(from: app)
        #expect(await provider.current(for: app) == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: app.path) == ["Contents"])

        await #expect(throws: IconError.cancelled) {
            try await AdministratorIconProvider(shell: DecliningShell(), helper: helper).apply(iconAt: makeIconFile(), to: app)
        }
    }

    @Test func tellsApartOpenSharedAndSealedApplications() throws {
        let app = try scratch.makeApp(named: "Mine")
        #expect(WorkspaceIconProvider.access(to: app) == .open)
        // Part of macOS: nobody can change it.
        #expect(WorkspaceIconProvider.access(to: URL(fileURLWithPath: "/System/Applications/Calculator.app")) == .sealed)
        // Owned by the system administrator, outside the sealed system: a password would do it.
        #expect(WorkspaceIconProvider.access(to: URL(fileURLWithPath: "/Library/Preferences")) == .administrator)
    }

    @Test func reportsMissingAndLockedApplications() async throws {
        let provider = WorkspaceIconProvider()
        let icon = try makeIconFile()

        await #expect(throws: IconError.applicationNotFound) {
            try await provider.apply(iconAt: icon, to: scratch.url.appendingPathComponent("Nope.app"))
        }

        let app = try scratch.makeApp(named: "Locked")
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: app.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: app.path) }
        await #expect(throws: IconError.locked) { try await provider.apply(iconAt: icon, to: app) }
        #expect(BundleAppInspector().access(to: app) == .sealed)
    }

    @Test func inspectorReadsApplicationsAndRejectsEverythingElse() throws {
        let app = try scratch.makeApp(named: "Reader", identifier: "test.signa.reader")
        #expect(BundleAppInspector().info(at: app) == AppInfo(bundleIdentifier: "test.signa.reader", name: "Reader"))
        #expect(BundleAppInspector().info(at: scratch.url) == nil)
        #expect(DroppedItem(app) == .application(app))

        let image = try scratch.writeImage(TestImage.opaque(), named: "pic.png")
        #expect(DroppedItem(image) == .image(image))
        #expect(DroppedItem(scratch.url) == .unsupported)
    }

    /// The whole promise, end to end: a real file watcher, a real icon, and an
    /// "update" that replaces the application three different ways.
    @Test func putsTheIconBackWhenAnApplicationIsReplaced() async throws {
        let app = try scratch.makeApp()
        let library = AppLibrary(
            store: MemoryLibraryStore(), assets: FileIconAssetStore(directory: scratch.url),
            renderer: IconRenderer(), provider: WorkspaceIconProvider(), inspector: BundleAppInspector())
        let id = try library.add(applicationAt: app)
        try await library.stageIcon(from: scratch.writeImage(TestImage.opaque(), named: "art.png"), for: id)
        try await library.apply(id)

        let guardian = IconGuardian(
            library: library, monitors: [FSEventsMonitor()], loginItem: RecordingLoginItem(),
            notifier: RecordingNotifier(), settleInterval: .milliseconds(500))
        guardian.start()
        try await Task.sleep(for: .seconds(1))  // let the watcher attach

        let provider = WorkspaceIconProvider()
        func iconIsBack() async -> Bool {
            let current = await provider.current(for: app)
            return current != nil && current == library.app(id)?.appliedFingerprint
        }

        // The changes are made by other processes, as real updates are.
        // 1. Swapped for a new copy, the way most updaters do it.
        let update = try scratch.makeApp(in: "Staging")
        try run("/bin/mv", app.path, scratch.url.appendingPathComponent("Old.app").path)
        try run("/bin/mv", update.path, app.path)
        #expect(await provider.current(for: app) == nil)
        #expect(await eventually { await iconIsBack() })

        // 2. Deleted and copied fresh.
        let fresh = try scratch.makeApp(in: "Staging")
        try run("/bin/rm", "-rf", app.path)
        try run("/bin/cp", "-R", fresh.path, app.path)
        #expect(await eventually { await iconIsBack() })

        // 3. Cleaned up in place.
        try run("/bin/rm", app.appendingPathComponent("Icon\r").path)
        #expect(await provider.current(for: app) == nil)
        #expect(await eventually { await iconIsBack() })

        #expect(library.app(id)?.status == .protected)
        guardian.stop()
    }

    private func run(_ tool: String, _ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }
}
