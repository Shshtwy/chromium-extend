# De-Googled Chromium for Desktop Android: design

Date: 2026-08-14
Status: approved (design), pending implementation plan

## Goal

Produce a local Chromium build for the Pixel Fold that keeps extensions and video playback while
removing Google tracking, telemetry, and AI integration. The result is a personal daily-driver
browser, not a distributable fork.

## Non-goals

- Google account sign-in and Chrome Sync. Previously built as "Phase 2"; abandoned as of
  2026-08-14 and reverted by this work.
- Distribution, signing for others, or reproducible builds.
- Built-in ad blocking. Extensions cover this; adding it would duplicate uBlock Origin.
- Upgrading off Chromium 153.0.7999.0. Rebasing onto a newer Chromium is future work that this
  design deliberately makes cheaper, but is out of scope here.

## Constraints

- **Local only.** Nothing is pushed to GitHub or any other source host, per `BUILDING.md`. Version
  control lives in the Chromium checkout inside the container; the macOS project directory is not
  a git repository and does not need to become one.
- **Disk.** 78 GB free against Chromium's 100 GB recommendation. Check `./builder.sh status`
  before each stage; stop if free space approaches 30 GB.
- **Build host.** x86-64 Ubuntu 22.04 container under Docker Desktop, which has stopped
  unexpectedly twice (2026-08-13, 2026-08-14).

## Must keep

| Capability | Why it must survive |
| --- | --- |
| Extensions (`enable_extensions_core = true`) | Primary requirement. Bitwarden is the reference case. |
| Video playback (`proprietary_codecs`, `ffmpeg_branding = "Chrome"`) | Primary requirement. Already added deliberately. |
| Widevine (`enable_widevine = true`) | DRM. Removing breaks paid streaming. |
| HSTS preload list | Static security asset, no callback. |
| Certificate verification and root store | Not telemetry. |

## Decisions

1. **Chrome Web Store: keep install, remove the update pinger.** Extensions install normally.
   The periodic background update check, which transmits installed extension IDs plus a client
   ID on a timer, is stubbed. Updates happen by reinstalling on demand.
2. **Safe Browsing removed, component updater retained.** `safe_browsing_mode = 0`. Safe Browsing
   is already non-functional without an API key, so the outbound lookups are cost without benefit.
   The component updater stays so CRLSet certificate revocation data keeps refreshing. This leaves
   one periodic Google connection that carries component versions, not browsing history.
3. **Dead UI: remove the big surfaces, stub the rest.** Sign-in, Sync, and Translate entry points
   are deleted outright. Smaller surfaces keep their UI over a no-op backend. This root-causes the
   2026-08-09 Crash 2 rather than patching it.
4. **Approach: versioned patch series** applied to the existing checkout, with pristine originals
   retained for every touched file. Rejected alternatives are recorded below.
5. **Default search engine: DuckDuckGo.** Requires no API key and works without configuration.

## Baseline state (verified 2026-08-14)

Checkout: `/work/chromium/src` in Docker volume `chromium-android-source` (50.02 GB).
Chromium 153.0.7999.0, commit `945b5115`, `is_desktop_android = true`, target `out/PixelFold`.

The checkout is a clean git repository. Total local delta is 7 modified files and 5 untracked
files, 42 insertions and 14 deletions. `/work/chromium/_bad_scm` is a gclient quarantine artifact
holding one bad SwiftShader fetch from 2026-08-10; it is unrelated and can be ignored.

### Critical finding: no API keys

`google_api_key = ""`, `use_official_google_api_keys = ""`, and
`support_external_google_api_key = false`. `USE_OFFICIAL_GOOGLE_API_KEYS` is undefined and there is
no runtime injection path. Every keyed Google service (Safe Browsing lookups, Translate,
spellcheck, Autofill crowdsourcing, the variations seed) is already failing in the current APK.

This reframes the work: most removals delete dead code and stop futile outbound attempts rather
than sacrificing working functionality.

## Approach

### Chosen: versioned patch series

Changes are grouped into ordered stages, each independently buildable.

The checkout at `/work/chromium/src` is already a git repository, so it is the version control
mechanism. At the end of each stage, `git diff` inside the container produces a numbered patch
file, written out through `exchange/` to `patches/NN-<stage>.patch` on the macOS side. Patches are
the durable artifact: reviewable, replayable against a fresh checkout, and rebaseable onto a newer
Chromium.

Pristine copies under `phase2-staging/originals/` remain useful for the Phase 2 revert in Stage 1,
but are superseded by patch files for new work, git already tracks the originals.

This requires no git repository in the macOS project directory and no remote host.

### Rejected

**Patch in place.** Edit the tree directly with no originals kept. Fastest to a working APK, but
changes exist only as modifications to a 50 GB checkout, and moving to a newer Chromium means
starting over.

**Fresh checkout.** Cleanest baseline, but ruled out on disk grounds: 78 GB free against a
100 GB requirement, with the existing volume already consuming 50 GB. A parallel sync risks
wedging the machine.

## Stages

Each stage ends with a build, an install to the Pixel Fold, and the stated checkpoint. Stages are
sequential; several touch overlapping files.

### Stage 1: Revert Phase 2

**Prerequisite completed 2026-08-14.** All retained work is committed to branch `local-patches`
in the checkout, on top of base commit `945b5115`:

- `7458900703`: Fix two Desktop Android crashes from the 2026-08-09 report
- `1edd8e56d1`: Harden extensions menu against a missing toolbar coordinator

One subtlety was resolved while committing: `components/signin/public/android/BUILD.gn` contained
both Phase 2 source registrations and the Phase 1 `NullAccountManagerDelegateTest` registration.
It was split so only the Phase 1 line is committed. A wholesale revert of that file would
otherwise have silently dropped the crash-fix test.

The working tree now contains Phase 2 and nothing else: 3 modified files, 3 untracked files,
9 insertions and 1 deletion. The revert is therefore:

```
git checkout -- .
rm components/signin/public/android/java/src/org/chromium/components/signin/AndroidAccountConsentActivity.java
rm components/signin/public/android/java/src/org/chromium/components/signin/AndroidAccountManagerDelegate.java
rm components/signin/public/android/junit/src/org/chromium/components/signin/AndroidAccountManagerDelegateTest.java
```

Checkpoint: `git status` is clean; builds clean; sign-in falls back to
`NullAccountManagerDelegate`.

### Stage 2: GN flag tier

Split into two builds. `safe_browsing_mode = 0` is the highest-risk flag in the set, the Android
path assumes mode 2, so it goes first and alone, keeping any failure unambiguous.

**Stage 2a.** Append to `out/PixelFold/args.gn` and build:

```
safe_browsing_mode = 0
```

If this fails to compile, resolve or abandon it before proceeding. Do not continue to 2b with a
broken tree.

**Stage 2b.** Append the remainder and build:

```
# AI and on-device model stack
use_mlkit_for_aicore = false
build_with_model_execution = false
enable_glic_internal_resources = false

# XR / Google SDK surfaces
enable_arcore = false
enable_cardboard = false
enable_vr = false
enable_openxr = false

# Network phone-home
enable_reporting = false
enable_service_discovery = false
enable_mdns = false

# Misc
enable_supervised_users = false
enable_offline_pages = false
```

Checkpoint: APK size drops measurably from the 467 MB baseline.

### Stage 3: Network patches

No GN flag exists for these; each needs a source edit. This is the bulk of the effort.

| Target | Location |
| --- | --- |
| Variations seed fetch | `components/variations/variations_url_constants.cc` |
| UMA / UKM upload | `components/metrics` |
| Crash upload (retain local capture) | `components/crash`, Crashpad |
| Default search engine → DuckDuckGo | `components/search_engines/prepopulated_engines.json` |
| Omnibox Google-specific suggest paths | `components/omnibox` |
| Navigation error correction ("link doctor") | `chrome/browser/net` |
| Translate backend | `components/translate` |
| Autofill crowdsourcing upload | `components/autofill` |
| Network time queries | `components/network_time` |

The Cromite and ungoogled-chromium patch sets are used as reference for call sites. They will not
apply cleanly, both target conventional Chrome rather than `is_desktop_android`, but they
materially reduce the risk of missing a call site.

Checkpoint: no unexpected outbound traffic under observation.

### Stage 4: Android manifest

Remove from `chrome/android/java/AndroidManifest.xml` and supporting build files:

- `FirebaseInitProvider`, `ChromeGcmListenerService`, `GCMBackgroundService`,
  `InvalidationGcmUpstreamSender`, and the `com.google.android.c2dm` permission
- `com.google.android.backup.api_key`
- `com.google.android.play.core.assetpacks.*` extraction services
- `com.google.android.gms.cast.framework.*`
- `com.google.android.apps.now.CURRENT_ACCOUNT_ACCESS`

Removing GCM also removes Web Push for all sites. This is accepted as a consequence of dropping
Sync.

Checkpoint: manifest diff contains no `com.google.*` service registrations.

### Stage 5: UI removal

Delete entry points for sign-in, Sync, and Translate.

Checkpoint: the 2026-08-09 Crash 2 reproduction steps no longer reach a sign-in action.

### Stage 6: Chrome Web Store update pinger

Stub the periodic extension update check while leaving the install path intact.

Checkpoint: an extension installs from the Web Store; no periodic update traffic observed.

## Risks

| Risk | Mitigation |
| --- | --- |
| `safe_browsing_mode = 0` unsupported on Android | Build it alone, before the rest of Stage 2 |
| Stage 3 misses a call site | Cross-check against Cromite and ungoogled-chromium patch sets |
| Removing component updater dependencies via Safe Browsing removal | Component updater is explicitly retained; verify it still initializes |
| Disk exhaustion during rebuilds | 78 GB free; check `./builder.sh status` before each stage |
| Docker Desktop stopping mid-build | Observed twice (2026-08-13, 2026-08-14). Container has no restart policy; consider adding one |
| UI removal breaks an unrelated build target | Stage 5 runs after all backend work, so failures are isolated to UI edits |

## Verification

Per stage: build `chrome_public_apk`, install to the Pixel Fold, exercise the stage checkpoint.

End to end, the build must still:

- Install and run a Chrome Web Store extension (Bitwarden as reference)
- Play H.264/AAC video
- Play Widevine-protected content
- Not crash on the two 2026-08-09 reproduction paths

Note that the Pixel Fold was not connected as of 2026-08-14; device testing requires reconnecting it.
