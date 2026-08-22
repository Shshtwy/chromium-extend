#!/usr/bin/env bash
set -ex

# ==============================================================================
# eGixium Automated Full Chromium Android Cloud Builder
# ==============================================================================

export HOME=/root
export USER=root
export DEBIAN_FRONTEND=noninteractive

RELEASE_TAG="v1.0.0-alpha.1"

# Guarantee auto-termination and log upload on exit (success or failure)
on_exit() {
    EXIT_CODE=$?
    echo "=== Build finished with code ${EXIT_CODE} at $(date) ==="
    if [ -f /var/log/egixium-full-build.log ]; then
        gh release upload "${RELEASE_TAG}" /var/log/egixium-full-build.log --repo NeoTurcios/chromium-extend --clobber || true
    fi
    echo "Terminating instance now..."
    shutdown -h now
}
trap on_exit EXIT

exec > >(tee -a /var/log/egixium-full-build.log) 2>&1
echo "=== Starting Full eGixium Cloud Compilation at $(date) ==="

# Safety Watchdog: hard timeout at 3.5 hours
shutdown -h +210 &

# Configure Git
git config --global user.name "eGixium Builder"
git config --global user.email "builder@egixi.com"

# Install System Dependencies
apt-get update && apt-get install -y \
    git curl wget python3 python3-pip openjdk-17-jdk zipalign apksigner ninja-build \
    build-essential libncurses5 lsb-release pkg-config file bsdextrautils libglib2.0-dev sudo

# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt-get update && apt-get install -y gh

export GH_TOKEN="__GH_TOKEN__"

# 1. Clone repository
mkdir -p /work && cd /work
git clone https://github.com/NeoTurcios/chromium-extend.git
cd chromium-extend

VERSION_NAME=$(python3 tools/version.py name)
VERSION_CODE=$(python3 tools/version.py code)
RELEASE_TAG="v${VERSION_NAME}"
APK_NAME="eGixium-arm64-${VERSION_NAME}.apk"

# 2. Setup depot_tools
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git /work/depot_tools
export PATH="/work/depot_tools:$PATH"
export DEPOT_TOOLS_UPDATE=0

# 3. Setup .gclient and Shallow Sync pinned commit (945b51156108ba94d62f235a75379772da8ced30)
mkdir -p /work/chromium && cd /work/chromium
cat << 'EOF' > .gclient
solutions = [
  {
    "name": "src",
    "url": "https://chromium.googlesource.com/chromium/src.git@945b51156108ba94d62f235a75379772da8ced30",
    "managed": False,
    "custom_deps": {},
    "custom_vars": {},
  },
]
target_os = ["android"]
EOF

echo "=== Syncing Chromium Android Source (Shallow) ==="
gclient sync --no-history --shallow --delete_unversioned_trees --reset -j$(nproc)

cd /work/chromium/src

# 4. Install build dependencies
echo "=== Installing Android Build Dependencies ==="
./build/install-build-deps.sh --android --no-prompt --no-chromeos-fonts --no-nacl || true

# Run hooks to populate sysroots, toolchains, Java JDK, and Android SDK/NDK
gclient runhooks

# 5. Apply all 75 eGixium patches sequentially
echo "=== Applying 75 eGixium Custom Patches ==="
for patch in $(ls /work/chromium-extend/patches/*.patch | sort -V); do
    echo "Applying $(basename "$patch")..."
    git apply --ignore-whitespace "$patch" || patch -p1 --forward < "$patch" || {
        echo "Failed to apply $patch"
        exit 1
    }
done

# 6. Copy bundled assets
echo "=== Injecting Assets & Third-Party Extensions ==="
mkdir -p chrome/browser/resources/bare
cp /work/chromium-extend/third_party/ublock_origin/uBlockOrigin-1.73.0.crx chrome/browser/resources/bare/ublock_origin.crx
mkdir -p third_party/eruda
cp /work/chromium-extend/third_party/eruda/eruda.min.js third_party/eruda/eruda.min.js

# 7. Configure GN Arguments
echo "=== Configuring GN Build Arguments ==="
mkdir -p out/eGixium
cat << GNARGS > out/eGixium/args.gn
target_os = "android"
target_cpu = "arm64"
is_desktop_android = true
is_official_build = true
is_debug = false
is_java_debug = false
is_component_build = false
dcheck_always_on = false
android_static_analysis = "off"
symbol_level = 0
blink_symbol_level = 0
v8_symbol_level = 0
use_remoteexec = false
use_reclient = false

proprietary_codecs = true
ffmpeg_branding = "Chrome"

use_mlkit_for_aicore = false
enable_glic_internal_resources = false
enable_reporting = false
enable_service_discovery = false
enable_mdns = false
enable_arcore = false
enable_cardboard = false
enable_openxr = false

chrome_public_manifest_package = "org.egixium"
android_override_version_code = "${VERSION_CODE}"
android_override_version_name = "${VERSION_NAME}"
GNARGS

# 8. Generate build files and compile with Ninja
echo "=== Generating GN Ninja Build Files ==="
gn gen out/eGixium

echo "=== Compiling chrome_public_apk with Autoninja ==="
autoninja -C out/eGixium chrome_public_apk

# 9. Sign and align APK
UNSIGNED_APK="out/eGixium/apks/ChromePublic.apk"
if [ ! -f "$UNSIGNED_APK" ]; then
    # Search for alternative apk output path if named differently
    UNSIGNED_APK=$(find out/eGixium/apks -name "*.apk" | head -n 1)
fi

if [ -f "$UNSIGNED_APK" ]; then
    echo "=== Signing and Aligning Final APK ($UNSIGNED_APK) ==="
    keytool -genkey -v -keystore /work/egixium.keystore -alias egixium -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=eGixium, OU=Browser, O=Egixi, L=San Francisco, S=CA, C=US" -storepass egixium123 -keypass egixium123

    zipalign -p -f 4 "$UNSIGNED_APK" "/work/aligned.apk"
    apksigner sign --ks /work/egixium.keystore --ks-pass pass:egixium123 --out "/work/${APK_NAME}" "/work/aligned.apk"

    # 10. Upload finalized APK to GitHub Release
    echo "=== Uploading ${APK_NAME} to GitHub Release ${RELEASE_TAG} ==="
    gh release upload "${RELEASE_TAG}" "/work/${APK_NAME}" --repo NeoTurcios/chromium-extend --clobber
    echo "=== SUCCESS! ${APK_NAME} uploaded to GitHub Releases ==="

    # Telegram notification
    APK_SIZE=$(du -h "/work/${APK_NAME}" | cut -f1)
    TG_MSG="🎉 *Build Complete & Published!*

📱 *APK:* \`${APK_NAME}\`
📦 *Size:* ${APK_SIZE}
🏷 *Release:* \`${RELEASE_TAG}\`
🔗 [Download from GitHub Releases](https://github.com/NeoTurcios/chromium-extend/releases/tag/${RELEASE_TAG})

✨ eGixium Cloud Builder finished successfully."

    curl -s -X POST "https://api.telegram.org/bot8611182352:AAEGuUykvf5VpKO9As4suEwIarkeQqmLH0U/sendMessage" \
      -d chat_id="-1003732911431" \
      -d text="${TG_MSG}" \
      -d parse_mode="Markdown" || true
else
    echo "ERROR: Could not find generated APK in out/eGixium/apks/"
    exit 1
fi
