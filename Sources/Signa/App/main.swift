import AppKit

// Started by the administrator path to change one icon, not to show the app.
if ElevatedHelper.isRequested { ElevatedHelper.run() }

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
