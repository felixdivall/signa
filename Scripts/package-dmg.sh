#!/bin/sh
# Packages a built Signa.app into a disk image laid out for installing:
# the app on the left, Applications on the right, a backdrop with an arrow.
#
#   Scripts/package-dmg.sh build/Signa.app build/Signa.dmg
#
# Finder keeps a window's layout in the volume's .DS_Store, and the only
# reliable way to write one is to let Finder do it. So this mounts a writable
# image, asks Finder to arrange the window, and converts the result into the
# compressed, read-only image that ships. A Finder window appears for a moment
# while that happens.
#
# The window size and icon positions match Resources/dmg-background.tiff,
# drawn by Scripts/make-dmg-background.swift. Change one, change the other.
set -eu
cd "$(dirname "$0")/.."

APP="${1:?usage: package-dmg.sh <Signa.app> <out.dmg>}"
DMG="${2:?usage: package-dmg.sh <Signa.app> <out.dmg>}"
VOLUME="Signa"
WIDTH=600; HEIGHT=380       # the window's content, in points
TITLE=28                    # the title bar above it, which the bounds include
ICON=128                    # icon size
APP_X=150; APPS_X=450; Y=158 # icon centres

WORK="$(mktemp -d)"
trap 'hdiutil detach -quiet "/Volumes/$VOLUME" 2>/dev/null || true; rm -rf "$WORK"' EXIT

# What goes on the image.
STAGE="$WORK/stage"
mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/"
# Shown as "Signa", not "Signa.app", unless Finder is set to show every extension.
SetFile -a E "$STAGE/Signa.app"
ln -s /Applications "$STAGE/Applications"
cp Resources/dmg-background.tiff "$STAGE/.background/background.tiff"

# A writable image first, with room to spare for Finder's bookkeeping.
RW="$WORK/rw.dmg"
hdiutil create -quiet -volname "$VOLUME" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$RW"
hdiutil detach -quiet "/Volumes/$VOLUME" 2>/dev/null || true
hdiutil attach -quiet -readwrite -noverify -noautoopen "$RW"

# Finder lays the window out. The bounds place it near the top centre of the
# main screen, where a window that opens on its own is expected to be.
osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME"
        open
        set theWindow to container window
        set current view of theWindow to icon view
        set toolbar visible of theWindow to false
        set statusbar visible of theWindow to false
        set bounds of theWindow to {400, 160, 400 + $WIDTH, 160 + $TITLE + $HEIGHT}
        set theOptions to icon view options of theWindow
        set arrangement of theOptions to not arranged
        set icon size of theOptions to $ICON
        set text size of theOptions to 13
        set label position of theOptions to bottom
        set shows item info of theOptions to false
        set shows icon preview of theOptions to true
        set background picture of theOptions to file ".background:background.tiff"
        set position of item "Signa.app" of theWindow to {$APP_X, $Y}
        set position of item "Applications" of theWindow to {$APPS_X, $Y}
        update without registering applications
        delay 1
        close
        open
        delay 1
        close
    end tell
end tell
EOF

# The volume shows Signa's own icon on the desktop and in the Finder sidebar.
# This comes after Finder's turn: Finder removes the icon file while it works.
cp Resources/AppIcon.icns "/Volumes/$VOLUME/.VolumeIcon.icns"
SetFile -a C "/Volumes/$VOLUME"
sync
rm -rf "/Volumes/$VOLUME/.fseventsd" "/Volumes/$VOLUME/.Trashes" 2>/dev/null || true
hdiutil detach -quiet "/Volumes/$VOLUME"

# The image that ships: compressed and read-only.
rm -f "$DMG"
hdiutil convert -quiet "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG"
echo "Packaged $DMG"
