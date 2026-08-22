#!/usr/bin/env bash
set -ex

# ==============================================================================
# eGixium Automated Full Chromium Android Cloud Builder
# ==============================================================================

exec > >(tee -a /var/log/egixium-full-build.log) 2>&1
echo "=== Starting Full eGixium Cloud Compilation at $(date) ==="

# Safety Watchdog: auto-terminate after 4 hours
shutdown -h +240 &

export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y \
    git curl wget python3 python3-pip openjdk-17-jdk zipalign apksigner ninja-build \
    build-essential libncurses5 lsb-release pkg-config file bsdextrautils libglib2.0-dev

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
APK_NAME="eGixium-arm64-${VERSION_NAME}.apk"

# 2. Setup depot_tools
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git /work/depot_tools
export PATH="/work/depot_tools:$PATH"
export DEPOT_TOOLS_UPDATE=0

# 3. Fetch Chromium Source (pinned commit 945b5115)
mkdir -p /work/chromium && cd /work/chromium
fetch --nohooks android
cd src
git checkout 945b5115
gclient sync -D --force --reset

# 4. Install build dependencies
./build/install-build-deps.sh --android --no-prompt

# 5. Apply all 75 eGixium patches
for patch in /work/chromium-extend/patches/*.patch; do
    echo "Applying $patch..."
    git apply --ignore-whitespace "$patch" || git apply --reject "$patch" || true
done

# 6. Copy bundled assets
mkdir -p chrome/browser/resources/bare
cp /work/chromium-extend/third_party/ublock_origin/uBlockOrigin-1.73.0.crx chrome/browser/resources/bare/ublock_origin.crx
mkdir -p third_party/eruda
cp /work/chromium-extend/third_party/eruda/eruda.min.js third_party/eruda/eruda.min.js

# 7. Configure GN Arguments
mkdir -p out/eGixium
cat << 'GNARGS' > out/eGixium/args.gn
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
android_override_version_code = "801000001"
android_override_version_name = "1.0.0-alpha.1"
GNARGS

# 8. Generate build files and compile with Ninja
gn gen out/eGixium
autoninja -C out/eGixium chrome_public_apk

# 9. Sign and align APK
UNSIGNED_APK="out/eGixium/apks/ChromePublic.apk"
if [ -f "$UNSIGNED_APK" ]; then
    keytool -genkey -v -keystore /work/egixium.keystore -alias egixium -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=eGixium, OU=Browser, O=Egixi, L=San Francisco, S=CA, C=US" -storepass egixium123 -keypass egixium123

    zipalign -p -f 4 "$UNSIGNED_APK" "/work/aligned.apk"
    apksigner sign --ks /work/egixium.keystore --ks-pass pass:egixium123 --out "/work/${APK_NAME}" "/work/aligned.apk"

    # 10. Upload finalized APK to GitHub Release
    gh release upload "${VERSION_NAME}" "/work/${APK_NAME}" --repo NeoTurcios/chromium-extend --clobber
    echo "=== SUCCESS! ${APK_NAME} uploaded to GitHub Releases ==="
fi

# 11. Auto-terminate instance
echo "=== Full compilation finished at $(date), terminating instance now ==="
shutdown -h now
