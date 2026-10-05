import Foundation
import ServiceManagement

/// Controls whether Signa starts quietly when the user logs in.
public protocol LoginItemControlling: Sendable {
    func setEnabled(_ enabled: Bool)
}

/// Registers the application itself, so there is no separate helper to
/// install, update or keep in sync.
public struct MainAppLoginItem: LoginItemControlling {
    public init() {}

    public func setEnabled(_ enabled: Bool) {
        // Only a real application bundle can be registered.
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled { try service.register() }
            } else if service.status == .enabled {
                try service.unregister()
            }
        } catch {
            Log.system.error("Could not update the login item: \(error.localizedDescription)")
        }
    }
}
