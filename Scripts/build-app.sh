#!/bin/sh
# Builds Signa.app into ./build.
#
#   Scripts/build-app.sh
#   SIGNA_SIGNING_IDENTITY="Developer ID Application: …" Scripts/build-app.sh
#
# Without an identity the app is signed with a development certificate that
# lives in ./.signing and is created on first use. macOS ties the permissions a
# user grants (App Management, login item) to the signature, so a stable one
# keeps them across rebuilds. An unsigned-style "ad hoc" signature changes with
# every build and silently loses them.
set -eu
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)"
APP="build/Signa.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Signa" "$APP/Contents/MacOS/Signa"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

if [ -n "${SIGNA_SIGNING_IDENTITY:-}" ]; then
    codesign --force --options runtime --sign "$SIGNA_SIGNING_IDENTITY" "$APP"
else
    KEYCHAIN="$PWD/.signing/signa-dev.keychain-db"
    PASSWORD="signa-dev"
    if [ ! -f "$KEYCHAIN" ]; then
        # A self-signed certificate that is good for signing code and nothing else.
        mkdir -p .signing
        WORK="$(mktemp -d)"
        cat > "$WORK/cert.conf" <<'CONF'
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = Signa Development
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CONF
        /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -keyout "$WORK/key.pem" -out "$WORK/cert.pem" \
            -days 3650 -config "$WORK/cert.conf" 2>/dev/null
        /usr/bin/openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -name "Signa Development" \
            -out "$WORK/identity.p12" -passout "pass:$PASSWORD"
        security create-keychain -p "$PASSWORD" "$KEYCHAIN"
        security set-keychain-settings "$KEYCHAIN"
        security unlock-keychain -p "$PASSWORD" "$KEYCHAIN"
        security import "$WORK/identity.p12" -k "$KEYCHAIN" -P "$PASSWORD" -T /usr/bin/codesign >/dev/null
        security set-key-partition-list -S apple-tool:,apple: -s -k "$PASSWORD" "$KEYCHAIN" >/dev/null
        rm -rf "$WORK"
        echo "Created a development signing certificate in .signing/"
    fi
    security unlock-keychain -p "$PASSWORD" "$KEYCHAIN"
    IDENTITY="$(security find-identity -p codesigning "$KEYCHAIN" | awk '/Signa Development/ { print $2; exit }')"
    # codesign only finds the certificate while its keychain is on the search list.
    # Put it there for the one command and take it off again whatever happens.
    SEARCH="$(security list-keychains -d user | sed 's/^ *"//; s/"$//')"
    restore() { printf '%s\n' "$SEARCH" | tr '\n' '\0' | xargs -0 security list-keychains -d user -s; }
    trap restore EXIT
    printf '%s\n%s\n' "$SEARCH" "$KEYCHAIN" | tr '\n' '\0' | xargs -0 security list-keychains -d user -s
    codesign --force --options runtime --sign "$IDENTITY" "$APP"
fi
echo "Built $APP"
