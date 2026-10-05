# Signa

Your apps should look the way you want, not the way the latest update decides.

Signa remembers the icon you chose for an application and quietly puts it back
whenever an update replaces it.

## Build and run

Requires macOS 14 or later and the Swift 6 toolchain (Xcode or the Command Line Tools).

```sh
Scripts/build-app.sh        # builds build/Signa.app
open build/Signa.app
swift test                  # runs the test suite
```

To distribute, sign with a Developer ID and notarize:

```sh
SIGNA_SIGNING_IDENTITY="Developer ID Application: …" Scripts/build-app.sh
```

For development, `SIGNA_DATA_DIRECTORY=/some/folder` makes Signa use a throwaway
library and leave the Mac's login items alone.

## Layout

```
Sources/SignaCore/      everything that is not a view
  Models/               ManagedApp, IconAsset
  Storage/              the library file and the icon files, kept apart
  IconEngine/           IconProvider, image → icon rendering, app inspection
  Monitoring/           change monitors and the guardian that restores icons
  Library/              AppLibrary, the one façade the interface talks to
  Utilities/            login item, notifications, drop classification
Sources/Signa/
  App/                  entry point, window and background life cycle, wiring
  UI/                   SwiftUI views and their view model
```

Signa stores its data in `~/Library/Application Support/Signa`: `Library.json`
for the managed applications and `Icons/` for the icon files.
