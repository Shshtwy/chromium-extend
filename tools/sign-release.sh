#!/usr/bin/env bash
#
# Signs a built APK with Bare's release key.
#
# The key lives outside this repo and the password lives in the macOS login
# keychain, so neither is ever written to a file the build can see, passed into
# the container, or recorded in a shell history. The password is read at the
# moment of signing and handed to apksigner through the environment.
#
#   tools/sign-release.sh path/to/ChromePublic.apk [output.apk]
#
set -euo pipefail

KEYSTORE="${BARE_KEYSTORE:-$HOME/.bare-signing/bare-release.p12}"
ALIAS="${BARE_KEY_ALIAS:-bare-release}"
KC_SERVICE="Bare release keystore"
KC_ACCOUNT="bare-release"

die() { echo "error: $*" >&2; exit 1; }

[ $# -ge 1 ] || die "usage: $0 <input.apk> [output.apk]"
IN="$1"
[ -f "$IN" ] || die "no such APK: $IN"
[ -f "$KEYSTORE" ] || die "no keystore at $KEYSTORE (set BARE_KEYSTORE)"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_NAME="$(python3 "$ROOT/tools/version.py" name)"
OUT="${2:-${IN%.apk}-signed.apk}"

# Prefer the newest build-tools we can find.
SDK="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
APKSIGNER="${BARE_APKSIGNER:-$(ls -1d "$SDK"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1)}"
[ -n "$APKSIGNER" ] && [ -x "$APKSIGNER" ] || die "apksigner not found under $SDK"

echo "signing $(basename "$IN")  ->  $(basename "$OUT")   [Bare $VERSION_NAME]"
cp "$IN" "$OUT"

# minSdk is 29, so the v1 JAR signature buys nothing and only adds size. v3
# carries the rotation record, which is what would let this key be replaced one
# day without orphaning every install.
BARE_KS_PW="$(security find-generic-password -a "$KC_ACCOUNT" -s "$KC_SERVICE" -w)" \
  "$APKSIGNER" sign \
    --ks "$KEYSTORE" \
    --ks-key-alias "$ALIAS" \
    --ks-pass env:BARE_KS_PW \
    --v1-signing-enabled false \
    --v2-signing-enabled true \
    --v3-signing-enabled true \
    "$OUT"

"$APKSIGNER" verify --print-certs --verbose "$OUT" | grep -Ei "Verified using|Signer #1 certificate (DN|SHA-256)"

echo
echo "sha256  $(shasum -a 256 "$OUT" | cut -d' ' -f1)"
echo "size    $(du -h "$OUT" | cut -f1)"
