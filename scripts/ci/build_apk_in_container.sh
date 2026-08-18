#!/usr/bin/env bash
# Builds Chromium Extend's arm64 APK inside the project's Docker container.
set -euo pipefail

readonly CHROMIUM_COMMIT="945b51156108ba94d62f235a75379772da8ced30"
readonly CHROMIUM_ROOT="/work/chromium"
readonly CHROMIUM_SRC="${CHROMIUM_ROOT}/src"
readonly OUTPUT_DIR="ChromiumExtend"

export PATH="${HOME}/depot_tools:${PATH}"

if [[ ! -d "${HOME}/depot_tools/.git" ]]; then
  git clone --depth 1 \
    https://chromium.googlesource.com/chromium/tools/depot_tools.git \
    "${HOME}/depot_tools"
fi

mkdir -p "${CHROMIUM_ROOT}"
cd "${CHROMIUM_ROOT}"
if [[ ! -d "${CHROMIUM_SRC}/.git" ]]; then
  fetch --nohooks --no-history android
fi

cd "${CHROMIUM_SRC}"
git am --abort >/dev/null 2>&1 || true
git fetch --depth 1 origin "${CHROMIUM_COMMIT}"
git checkout --detach "${CHROMIUM_COMMIT}"
git reset --hard "${CHROMIUM_COMMIT}"
git clean -ffd

gclient sync -D --nohooks
if [[ ! -f "${CHROMIUM_ROOT}/.chromium-build-deps-installed" ]]; then
  sudo build/install-build-deps.sh
  touch "${CHROMIUM_ROOT}/.chromium-build-deps-installed"
fi
gclient runhooks

git am /exchange/patches/*.patch

mkdir -p "out/${OUTPUT_DIR}"
cat > "out/${OUTPUT_DIR}/args.gn" <<'EOF'
target_os = "android"
target_cpu = "arm64"
is_component_build = false
is_debug = false

# Chromium Desktop Android
is_desktop_android = true
enable_extensions_core = true

# Multimedia
ffmpeg_branding = "Chrome"
proprietary_codecs = true

# Chromium Extend privacy configuration
use_mlkit_for_aicore = false
enable_glic_internal_resources = false
enable_reporting = false
enable_service_discovery = false
enable_mdns = false
EOF

gn gen "out/${OUTPUT_DIR}"
autoninja -C "out/${OUTPUT_DIR}" -j 12 chrome_public_apk

mkdir -p /exchange/artifacts
cp "out/${OUTPUT_DIR}/apks/ChromePublic.apk" /exchange/artifacts/ChromiumExtend-es-arm64.apk
sha256sum /exchange/artifacts/ChromiumExtend-es-arm64.apk \
  > /exchange/artifacts/ChromiumExtend-es-arm64.apk.sha256

git log -1 --format='%H%n%s' > /exchange/artifacts/chromium-extend-build-commit.txt
printf '%s\n' "${CHROMIUM_COMMIT}" > /exchange/artifacts/chromium-base-commit.txt
