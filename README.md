# Chromium Extend

A small patch series for **Chromium Desktop Android** that removes Google tracking,
telemetry, and AI integration while keeping browser extensions and video playback working.

Built and used on a Pixel 10 Pro XL. Not affiliated with Google or the Chromium project.

- **Base:** Chromium `153.0.7999.0` (commit `945b5115`)
- **Target:** `is_desktop_android = true`, `target_cpu = "arm64"`
- **Size:** 5 patches, 155 insertions and 24 deletions across 12 files

## Why

Chromium's Desktop Android build supports real browser extensions, which mobile Chrome does
not. That makes it a genuinely better browser to live in — but it still ships Google's AI
stack, phones home on a schedule, and hands your links to other apps. This series fixes that
without forking anything.

## What the patches do

| # | Patch | Effect |
| --- | --- | --- |
| 0001 | Fix two Desktop Android crashes | Extension popup keyboard events and the sign-in Add Account action both crashed the browser |
| 0002 | Harden extensions menu | The menu action crashed when no toolbar coordinator existed |
| 0003 | Extensions toolbar on phone layouts | Extension icons, popups, and pinning were tablet-only; now available at phone widths |
| 0004 | Remove variations and network-time callbacks | Two periodic requests to Google, sent regardless of activity |
| 0005 | Keep web navigations in the browser | `http(s)` links no longer get handed to whichever app claims the domain |

Patches 0001 and 0002 are bug fixes that happen to be prerequisites. 0003 is a usability fix.
0004 and 0005 are the de-Googling.

### Removed by build flag

These go in `args.gn` rather than a patch:

```gn
use_mlkit_for_aicore = false          # ML Kit + AICore (on-device Gemini Nano bridge)
enable_glic_internal_resources = false # Gemini-in-Chrome surface
enable_reporting = false               # Reporting API / Network Error Logging
enable_service_discovery = false       # local device discovery
enable_mdns = false                    # mDNS
```

### What is deliberately kept

| Kept | Why |
| --- | --- |
| Extensions (`enable_extensions_core`) | The entire point of the Desktop Android target |
| Proprietary codecs (`ffmpeg_branding = "Chrome"`) | H.264/AAC video playback |
| Widevine | DRM — removing it breaks paid streaming |
| Component updater | Delivers CRLSet certificate revocation data |
| HSTS preload list | Static security asset, no callback |

## Requirements

- Docker, with at least **32 GB** allocated to the VM. At 16 GB a full build is
  reliably OOM-killed partway through.
- ~100 GB free disk. The Chromium checkout alone is ~50 GB.
- An arm64 Android device for testing.

Builds run in an x86-64 Ubuntu 22.04 container. On Apple Silicon this means Rosetta
emulation, and a full build takes hours.

## Quick start

```bash
./builder.sh build     # build the container image
./builder.sh start     # start it
./builder.sh shell     # get a shell inside
```

Fetch a Chromium checkout at the base commit into the container's `/work/chromium/src`, then
apply the series:

```bash
git am /exchange/patches/*.patch
```

Add the flags above to `out/<name>/args.gn` alongside your platform args, then:

```bash
gn gen out/<name>
autoninja -C out/<name> -j 12 chrome_public_apk
```

See [BUILDING.md](BUILDING.md) for the full workflow, including how files move between the
container and the host.

## Status

**Verified on device.** No crashes across a full session. Extensions install and run
(Bitwarden, uBlock Origin Lite, Dark Reader, Bypass Paywalls Clean), popups open, pinning
works. Both original crash reproductions are gone. The shipped `AndroidManifest.xml` contains
zero references to ML Kit or AICore.

**Not yet verified.** Patch 0005 has not been confirmed against a real in-page link tap —
testing so far used an explicit-component intent, which partly bypasses that code path.
Widevine playback has not been tested since the changes.

## Known limitations

- **Extension popups can be cropped.** Extensions auto-size their popup to content and may
  request a width wider than a phone screen. `kMaxSize` in
  `chrome/browser/ui/android/extensions/extension_action_popup_contents.cc` is hardcoded to
  800dp. Two attempts to bound it failed; the second stopped popups rendering entirely, so
  both were reverted. Needs instrumenting rather than guessing.
- **The omnibox is squeezed** when several extensions are pinned. `ToolbarPhone` has none of
  the `ToolbarWidthConsumer` negotiation `ToolbarTablet` uses. Unpinning all but one extension
  works around it.
- **Patch 0005 is blunt.** All `http(s)` navigations stay in the browser. Some OAuth flows and
  deep links legitimately expect an app handoff and will no longer get one. Explicit schemes
  (`intent://`, `tel:`, `mailto:`, `sms:`) are untouched.
- **Search engine still defaults to Google.** Changeable in Settings; patching the shipped
  default requires going through `regional_capabilities` country logic.

## Not done yet

Each has an exact file and line reference in [docs/stage-1-2.md](docs/stage-1-2.md):

- UMA/UKM and crash upload — the two remaining recurring callbacks
- Safe Browsing — blocked by one un-gated call site in the Android JNI bridge
- Google XR SDKs (ARCore, Cardboard, VrCore, OpenXR) — blocked by three omnibox call sites;
  the flags are coupled in both directions and there is no GN-only configuration that works
- `build_with_model_execution`, `enable_supervised_users`, `enable_offline_pages` — each
  blocked by a single GN `assert()`
- Sign-in, Sync, and New Tab Page Google surfaces still appear in the UI

## Repository layout

```
patches/            the patch series, applied in order
docker/             container image definition
docker-compose.yml  build environment
builder.sh          container wrapper
docs/design.md      design decisions and rationale
docs/stage-1-2.md   execution notes, diagnoses, and results
```

The Chromium checkout, build output, and APKs are not tracked — they live in a Docker volume
and would be far past GitHub's file size limits.

## License

The patches modify Chromium source and are therefore subject to Chromium's
**BSD-3-Clause** license. See the
[Chromium LICENSE](https://chromium.googlesource.com/chromium/src/+/main/LICENSE).

Chromium is a trademark of Google LLC. This project is unaffiliated.
