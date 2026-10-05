import Foundation
import Testing

@testable import SignaCore

@Suite struct StorageTests {
    let scratch = try! Scratch()

    @Test func libraryRoundTripsAndUsesReadableKeys() throws {
        let store = JSONLibraryStore(directory: scratch.url)
        #expect(try store.load().isEmpty)

        var app = ManagedApp(
            bundleIdentifier: "com.example.codex", applicationPath: "/Applications/Codex.app", name: "Codex",
            dateAdded: Date(timeIntervalSince1970: 1_780_000_000))
        app.customIcon = IconAsset.ID(rawValue: "abc123")
        try store.save([app])

        #expect(try store.load() == [app])

        let json = try String(contentsOf: scratch.url.appendingPathComponent("Library.json"), encoding: .utf8)
        for expected in [
            "\"bundleIdentifier\" : \"com.example.codex\"",
            "\"applicationPath\" : \"/Applications/Codex.app\"",
            "\"customIcon\" : \"abc123\"",
            "\"enabled\" : true",
        ] {
            #expect(json.contains(expected))
        }
    }

    @Test func iconsAreStoredApartFromTheLibraryAndDeduplicated() throws {
        let assets = FileIconAssetStore(directory: scratch.url)
        let icon = RenderedIcon(icns: Data("icns".utf8), source: Data("artwork".utf8), sourceExtension: "png")

        let first = try assets.store(icon)
        let second = try assets.store(icon)
        #expect(first == second)
        #expect(assets.allIDs() == [first])
        #expect(try Data(contentsOf: assets.iconURL(for: first)) == icon.icns)
        #expect(assets.sourceURL(for: first)?.pathExtension == "png")
        #expect(assets.iconURL(for: first).path.contains("/Icons/"))

        assets.remove(first)
        #expect(assets.allIDs().isEmpty)
    }

    @Test func statusFollowsWhatTheUserHasDone() {
        var app = ManagedApp(bundleIdentifier: "a", applicationPath: "/A.app", name: "A")
        #expect(app.status == .needsIcon)

        app.stagedIcon = IconAsset.ID(rawValue: "1")
        #expect(app.status == .readyToApply)

        app.customIcon = app.stagedIcon
        app.stagedIcon = nil
        #expect(app.status == .protected)
        #expect(app.isGuarded)

        app.enabled = false
        #expect(app.status == .unprotected)
        #expect(!app.isGuarded)

        app.issue = .needsPermission
        #expect(app.status == .needsPermission)
    }

    @Test func theDockNoteAppliesOnlyToApplicationsOpenedBeforeTheIconChanged() {
        var app = ManagedApp(bundleIdentifier: "a", applicationPath: "/A.app", name: "A")
        let applied = Date(timeIntervalSince1970: 1_780_000_000)
        #expect(!app.awaitsRelaunch(.running(since: applied.addingTimeInterval(-60))))

        app.customIcon = IconAsset.ID(rawValue: "1")
        app.iconAppliedAt = applied
        // Opened before the change: the Dock still shows the old icon.
        #expect(app.awaitsRelaunch(.running(since: applied.addingTimeInterval(-60))))
        // Opened after it, or not open at all: nothing to say.
        #expect(!app.awaitsRelaunch(.running(since: applied.addingTimeInterval(60))))
        #expect(!app.awaitsRelaunch(.notRunning))
        // Unknown launch time: say nothing rather than guess.
        #expect(!app.awaitsRelaunch(.running(since: nil)))
    }
}
