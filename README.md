# Chromium Extend <img src="assets/chromium-logo.svg" width="52" align="right" alt="">

A small patch series for **Chromium Desktop Android** that removes Google tracking,
telemetry, and AI integration while keeping browser extensions and video playback working.

Built and used on a Pixel 10 Pro XL. Not affiliated with Google or the Chromium project.

- **Base:** Chromium `153.0.7999.0` (commit `945b5115`)
- **Target:** `is_desktop_android = true`, `target_cpu = "arm64"`
- **Size:** 10 patches, 225 insertions across 18 files

## What you get

**🧩 Real browser extensions on your phone.** Password managers, ad blockers, dark mode — the same
extensions you'd use on a desktop. Tap an extension's icon and its window opens properly, and you
can pin the ones you use most to the toolbar.

**🔗 Links open in the browser, not in apps.** Tapping a Reddit or YouTube result keeps you in the
browser instead of throwing you into their app mid-read. Phone numbers and email links still open
the right app, as they should.

**📵 De-Googled!** No background check-ins to Google, and nothing about the forms you fill in gets
sent off for analysis. Google's built-in AI features are removed entirely, not just switched off.

**🧹 No dead Google UI.** Settings opens straight to what you can actually change — no sign-in
prompts, no Google services page, no password manager row that only says it stopped working.

**🎬 Video still works.** Ordinary video plays, and so does paid streaming like Netflix and Spotify —
usually the first thing to break in a privacy-focused browser.

**🛡️ Still safe to browse.** Protections against fake certificates and downgraded connections are
deliberately kept. Privacy here doesn't come at the cost of security.

**🐛 Two crashes fixed.** The stock build crashes when you open an extension's window, and again if
you tap sign-in. Both are fixed.

## Screenshots

| | |
| --- | --- |
| <img src="assets/screenshots/01-browsing.png" width="260"> | <img src="assets/screenshots/02-extensions-menu.png" width="260"> |
| **Extension icons in the toolbar.** Pinned extensions sit beside the address bar. | **The extensions menu on a phone.** Per-site permissions and *Pin to toolbar* — upstream only offers this at tablet widths. |
| <img src="assets/screenshots/03-extension-popup.png" width="260"> | <img src="assets/screenshots/04-settings.png" width="260"> |
| **An extension's own window.** Dark Reader running from the toolbar, exactly as on a desktop. | **Settings opens straight to Basics.** No sign-in row, no Google services page. |

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
| 0006 | Stop Autofill crowdsourcing uploads | Form structure was uploaded to Google to train its field-classification heuristics |
| 0007 | Remove the GCM push channel | Google Cloud Messaging services, the c2dm permission and the Firebase receiver |
| 0008 | Guard omnibox vector icon calls | Unblocks disabling the Google XR SDKs, which previously broke the build |
| 0009 | Hide Google Password Manager and sign-in promo | Both were permanently non-functional and advertised as broken |
| 0010 | Remove the "You and Google" settings section | Sign-in and Google services entries, neither of which can work here |

Patches 0001 and 0002 are bug fixes that happen to be prerequisites. 0003 is a usability fix.
0004 through 0010 are the de-Googling.

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

Patch 0005 is confirmed against a real in-page link tap: following a Reddit result from a search
page keeps you in the browser, with Reddit's own "Open App" prompt left unused.

**Not fully verified.** Widevine is *detected* — a DRM test page reports `widevine` as the
available key system — but actual protected playback has not been exercised end to end.

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
- **Passkeys (WebAuthn) do not work.** `Fido.FIDO2_PRIVILEGED_API` is restricted to
  Google-signed browsers, so a self-built Chromium is refused with `ApiException: 17`. This is
  inherent to building Chromium yourself, not caused by any patch here — verified by
  reproducing it on an earlier build.
- **Web Push is gone**, as a consequence of removing the GCM channel in patch 0007.

## Not done yet

Each has an exact file and line reference in [docs/stage-1-2.md](docs/stage-1-2.md):

- Safe Browsing — blocked by one un-gated call site in the Android JNI bridge
- Google XR SDKs (ARCore, Cardboard, VrCore, OpenXR) — blocked by three omnibox call sites;
  the flags are coupled in both directions and there is no GN-only configuration that works
- `build_with_model_execution`, `enable_supervised_users`, `enable_offline_pages` — each
  blocked by a single GN `assert()`
- The New Tab Page still carries Google branding, an AI Mode button and Discover
- The first-run screen still promotes sign-in, and claims usage and crash data are sent to
  Google — which is untrue in this build
- ARCore, Cardboard and Daydream manifest entries persist from library manifests, though their
  code is gone

### Already inert — no work needed

Worth knowing before anyone patches them: a public (non-Chrome-branded) Chromium build already
sends no usage metrics, no URL-keyed metrics and no crash reports, because upstream withholds
those endpoints from forks. Translate is likewise disabled without a Google API key. Details and
evidence are in [docs/stage-1-2.md](docs/stage-1-2.md).

## Repository layout

```
patches/            the patch series, applied in order
docker/             container image definition
docker-compose.yml  build environment
builder.sh          container wrapper
assets/             logo used in this README
docs/design.md      design decisions and rationale
docs/stage-1-2.md   execution notes, diagnoses, and results
```

The Chromium checkout, build output, and APKs are not tracked — they live in a Docker volume
and would be far past GitHub's file size limits.

## License

The patches modify Chromium source and are therefore subject to Chromium's
**BSD-3-Clause** license. See the
[Chromium LICENSE](https://chromium.googlesource.com/chromium/src/+/main/LICENSE).

`assets/chromium-logo.svg` is from
[Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Chromium_Logo.svg), in the public
domain under `PD-textlogo` (simple geometric shapes, below the threshold of originality).
Public domain covers copyright only — the mark itself remains a trademark, and it is used here
to identify the upstream project this patches, not to suggest endorsement.

Chromium is a trademark of Google LLC. This project is unaffiliated.
