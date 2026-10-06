#!/bin/sh
# Builds, signs, notarizes and packages Signa for distribution.
#
#   Scripts/release.sh                      # writes build/Signa.dmg
#
# Needs a Developer ID Application certificate in the keychain and a
# notarization login stored once with
#   xcrun notarytool store-credentials signa-notary --apple-id … --team-id … --password …
#
#   SIGNA_SIGNING_IDENTITY   the certificate, by name or SHA-1 fingerprint
#   SIGNA_NOTARY_PROFILE     the stored login (default: signa-notary)
#
# The fingerprint rather than the name, because a keychain can hold several
# certificates with the same name and codesign refuses to guess between them.
set -eu
cd "$(dirname "$0")/.."

: "${SIGNA_SIGNING_IDENTITY:=F7A8C382E5AAF6D3B9ADDC63806EF507A38F3386}"
: "${SIGNA_NOTARY_PROFILE:=signa-notary}"
export SIGNA_SIGNING_IDENTITY

APP="build/Signa.app"
DMG="build/Signa.dmg"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"

echo "Building Signa $VERSION"
Scripts/build-app.sh
codesign --verify --strict --verbose=1 "$APP"

# A disk image holding the app and a shortcut to Applications, so installing
# is one drag.
echo "Packaging"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname "Signa" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
codesign --timestamp --sign "$SIGNA_SIGNING_IDENTITY" "$DMG"

# Apple scans the image and records its verdict; stapling attaches that
# verdict to the file so Gatekeeper can read it offline.
echo "Notarizing (this usually takes a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$SIGNA_NOTARY_PROFILE" --wait
xcrun stapler staple -q "$DMG"

# The same check Gatekeeper makes when somebody opens the download.
spctl --assess --type open --context context:primary-signature -v "$DMG"
echo "Ready: $DMG ($(du -h "$DMG" | cut -f1))"
