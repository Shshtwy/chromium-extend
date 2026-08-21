# Stages 1–2: revert Phase 2, then strip Google surfaces via GN flags

> Steps use checkbox (`- [ ]`) syntax so they can be worked through in order.
> `$PROJECT_ROOT` is the directory containing `builder.sh`; `$DEVICE` is the
> `adb -s` serial of the test device.

**Goal:** Remove the abandoned Phase 2 Google account integration, then strip every Google AI, XR, and phone-home surface that can be disabled with a GN build flag, producing a Chromium APK that still runs extensions and plays video.

**Architecture:** Work happens inside the `chromium-android-builder` container against the git checkout at `/work/chromium/src`, currently on branch `local-patches`. Stage 1 discards uncommitted Phase 2 work (everything worth keeping is already committed). Stage 2 appends GN flags to `out/PixelFold/args.gn`, split into two builds so the riskiest flag fails in isolation. The macOS side keeps a mirror of `args.gn` under `local-src/` as the durable record, since `out/` is not tracked by git.

**Tech Stack:** Chromium 153.0.7999.0, GN + autoninja, Robolectric JUnit, Docker Desktop (x86-64 Ubuntu 22.04 under Rosetta), Android arm64 target.

---

## Scope

This plan covers **Stage 1 and Stage 2 only** from `docs/design.md`.

Stages 3–6 (network source patches, Android manifest, UI removal, Web Store update pinger) are
**deliberately excluded**. Writing them to this standard requires locating exact call sites first,
and inventing file paths would produce a plan that fails on contact. A discovery pass unblocks
them; that pass is the natural follow-on once Stage 2 lands.

Stages 1–2 stand alone: they produce a working, installable APK with a measurable reduction in
Google integration.

## Preconditions

- Docker Desktop running. It has stopped unexpectedly twice (2026-08-13, 2026-08-14). If a build
  dies mid-task, check `docker info` before assuming a compile error.
- At least 40 GB free on the macOS volume. Check with `./builder.sh status`.
- Container running: `./builder.sh start`
- Checkout on branch `local-patches` at commit `1edd8e56d1`.

## File Structure

| File | Responsibility | Change |
| --- | --- | --- |
| `/work/chromium/src/out/PixelFold/args.gn` | Live build configuration inside container | Modify: append flags |
| `local-src/out/PixelFold/args.gn` | macOS-side mirror; the durable record of build config | Modify: keep in sync |
| `/work/chromium/src/components/signin/public/android/BUILD.gn` | Signin Java + junit source registration | Revert to HEAD |
| `/work/chromium/src/chrome/android/java/AndroidManifest.xml` | Chrome Android manifest | Revert to HEAD |
| `/work/chromium/src/components/signin/.../AccountManagerFacadeProvider.java` | Chooses the account delegate | Revert to HEAD |
| `/work/chromium/src/components/signin/.../AndroidAccountConsentActivity.java` | Phase 2 consent UI | Delete |
| `/work/chromium/src/components/signin/.../AndroidAccountManagerDelegate.java` | Phase 2 account backend | Delete |
| `/work/chromium/src/components/signin/.../AndroidAccountManagerDelegateTest.java` | Phase 2 test | Delete |
| `exchange/stage2-manifest.txt` | Extracted manifest for verification | Create |

All container commands below assume this prefix from the macOS project directory:

```bash
cd "$PROJECT_ROOT" && ./builder.sh exec bash -lc '<command>'
```

For brevity, tasks show only the inner `<command>`.

---

## Task 1: Establish the test baseline

Before changing anything, confirm the two retained crash-fix tests currently pass. If they are
already failing, that is a pre-existing problem to solve before it gets blamed on the revert.

**Files:**
- Test: `/work/chromium/src/components/signin/public/android/junit/src/org/chromium/components/signin/NullAccountManagerDelegateTest.java`
- Test: `/work/chromium/src/chrome/android/junit/src/org/chromium/chrome/browser/ChromeTabbedActivityUnitTest.java`

- [ ] **Step 1: Confirm the starting commit**

```
cd /work/chromium/src && git log --oneline -2 && git status --short
```

Expected: HEAD is `1edd8e56d1`. Status lists exactly 3 modified and 3 untracked files, all under
`components/signin/` or `chrome/android/java/AndroidManifest.xml`.

- [ ] **Step 2: Build the components junit test binary**

```
cd /work/chromium/src && autoninja -C out/PixelFold components_junit_tests
```

Expected: build succeeds. This is a large target; allow time on first run.

- [ ] **Step 3: Run the Crash 2 regression test**

```
cd /work/chromium/src && out/PixelFold/bin/run_components_junit_tests -f "*NullAccountManagerDelegateTest*"
```

Expected: PASS. This test asserts `createAddAccountIntent` returns null through the callback
instead of throwing `UnsupportedOperationException`.

- [ ] **Step 4: Build the chrome junit test binary**

```
cd /work/chromium/src && autoninja -C out/PixelFold chrome_junit_tests
```

Expected: build succeeds.

- [ ] **Step 5: Run the extensions menu test**

```
cd /work/chromium/src && out/PixelFold/bin/run_chrome_junit_tests -f "*ChromeTabbedActivityUnitTest*"
```

Expected: PASS.

- [ ] **Step 6: Record the baseline APK size**

```
ls -l /work/chromium/src/out/PixelFold/apks/ChromePublic.apk 2>/dev/null || echo "no prior APK in out/"
```

Expected: either a byte count to compare against later, or the "no prior APK" message. If absent,
the reference baseline is `exchange/ChromePublic-account-signin-codecs-extension-fix-153.0.7999.0.apk`
at 467 MB.

---

## Task 2: Revert Phase 2

Everything worth keeping is committed. The revert is therefore a discard, not a merge. There is
nothing to commit at the end of this task.

**Files:**
- Modify: `/work/chromium/src/chrome/android/java/AndroidManifest.xml` (revert)
- Modify: `/work/chromium/src/components/signin/public/android/BUILD.gn` (revert)
- Modify: `/work/chromium/src/components/signin/public/android/java/src/org/chromium/components/signin/AccountManagerFacadeProvider.java` (revert)
- Delete: `/work/chromium/src/components/signin/public/android/java/src/org/chromium/components/signin/AndroidAccountConsentActivity.java`
- Delete: `/work/chromium/src/components/signin/public/android/java/src/org/chromium/components/signin/AndroidAccountManagerDelegate.java`
- Delete: `/work/chromium/src/components/signin/public/android/junit/src/org/chromium/components/signin/AndroidAccountManagerDelegateTest.java`

- [ ] **Step 1: Archive the Phase 2 work before discarding it**

Phase 2 took two days and was validated on-device. It is being abandoned, not proven wrong. Keep
a copy in case it is ever wanted.

```
cd /work/chromium/src && git diff > /exchange/phase2-abandoned-2026-08-14.patch && cp components/signin/public/android/java/src/org/chromium/components/signin/AndroidAccountConsentActivity.java components/signin/public/android/java/src/org/chromium/components/signin/AndroidAccountManagerDelegate.java components/signin/public/android/junit/src/org/chromium/components/signin/AndroidAccountManagerDelegateTest.java /exchange/
```

Expected: no output. Verify on the macOS side that `exchange/phase2-abandoned-2026-08-14.patch`
and the three `.java` files exist.

- [ ] **Step 2: Discard the tracked Phase 2 modifications**

```
cd /work/chromium/src && git checkout -- .
```

Expected: no output.

- [ ] **Step 3: Delete the untracked Phase 2 files**

```
cd /work/chromium/src && rm components/signin/public/android/java/src/org/chromium/components/signin/AndroidAccountConsentActivity.java components/signin/public/android/java/src/org/chromium/components/signin/AndroidAccountManagerDelegate.java components/signin/public/android/junit/src/org/chromium/components/signin/AndroidAccountManagerDelegateTest.java
```

Expected: no output.

- [ ] **Step 4: Verify the tree is clean**

```
cd /work/chromium/src && git status --short && echo "---clean above this line---"
```

Expected: nothing between the command and the marker line. Any remaining entry means a Phase 2
file was missed.

- [ ] **Step 5: Confirm the null delegate is active again**

```
cd /work/chromium/src && grep -n "delegate = new" components/signin/public/android/java/src/org/chromium/components/signin/AccountManagerFacadeProvider.java
```

Expected: `delegate = new NullAccountManagerDelegate();`

- [ ] **Step 6: Confirm the Phase 1 test survived the revert**

This is the specific failure mode the pre-commit split was designed to prevent.

```
cd /work/chromium/src && grep -n "NullAccountManagerDelegateTest" components/signin/public/android/BUILD.gn
```

Expected: one line registering
`junit/src/org/chromium/components/signin/NullAccountManagerDelegateTest.java`. If this returns
nothing, the split failed and the test is orphaned. Stop and fix before continuing.

---

## Task 3: Verify the revert builds and tests pass

**Files:** none modified.

- [ ] **Step 1: Regenerate the build files**

```
cd /work/chromium/src && gn gen out/PixelFold
```

Expected: `Done. Made NNNN targets from ...`

- [ ] **Step 2: Rebuild and rerun the components test**

```
cd /work/chromium/src && autoninja -C out/PixelFold components_junit_tests && out/PixelFold/bin/run_components_junit_tests -f "*NullAccountManagerDelegateTest*"
```

Expected: PASS, same as Task 1 Step 3.

- [ ] **Step 3: Rebuild and rerun the chrome test**

```
cd /work/chromium/src && autoninja -C out/PixelFold chrome_junit_tests && out/PixelFold/bin/run_chrome_junit_tests -f "*ChromeTabbedActivityUnitTest*"
```

Expected: PASS, same as Task 1 Step 5.

- [ ] **Step 4: Build the APK**

```
cd /work/chromium/src && autoninja -C out/PixelFold chrome_public_apk
```

Expected: build succeeds. This is the long one.

- [ ] **Step 5: Copy the reverted APK out for reference**

```
cp /work/chromium/src/out/PixelFold/apks/ChromePublic.apk /exchange/ChromePublic-degoogle-stage1-153.0.7999.0.apk
```

Expected: no output. This is the pre-flag baseline that Stage 2 is measured against.

---

## Task 4: Stage 2a, remove Safe Browsing

`safe_browsing_mode = 0` is applied alone because the Android build path assumes mode 2. If it
fails, the failure must be unambiguous.

**Files:**
- Modify: `/work/chromium/src/out/PixelFold/args.gn`
- Modify: `local-src/out/PixelFold/args.gn` (macOS mirror)

- [ ] **Step 1: Back up the working args.gn**

```
cp /work/chromium/src/out/PixelFold/args.gn /exchange/args.gn.stage1-backup
```

Expected: no output.

- [ ] **Step 2: Append the flag**

```
cd /work/chromium/src && printf '\n# de-Google: Safe Browsing removed (stage 2a)\nsafe_browsing_mode = 0\n' >> out/PixelFold/args.gn && tail -3 out/PixelFold/args.gn
```

Expected: the comment and `safe_browsing_mode = 0` echoed back.

- [ ] **Step 3: Regenerate; this is where failure is most likely**

```
cd /work/chromium/src && gn gen out/PixelFold
```

Expected: `Done. Made NNNN targets from ...`

If this fails with an unresolved dependency on a Safe Browsing target, the mode-0 path is not
supported for `is_desktop_android` in this Chromium version. Do not attempt to patch around it in
this task. Restore with `cp /exchange/args.gn.stage1-backup /work/chromium/src/out/PixelFold/args.gn`,
rerun `gn gen out/PixelFold`, record the error, and continue to Task 5 without this flag.

- [ ] **Step 4: Build the APK**

```
cd /work/chromium/src && autoninja -C out/PixelFold chrome_public_apk
```

Expected: build succeeds.

- [ ] **Step 5: Confirm the APK shrank**

```
ls -l /work/chromium/src/out/PixelFold/apks/ChromePublic.apk
```

Expected: smaller than the Task 3 Step 5 artifact. Record both numbers.

- [ ] **Step 6: Update the macOS mirror**

Copy the live config out rather than hand-editing, so the two files cannot drift.

```
cp /work/chromium/src/out/PixelFold/args.gn /exchange/args.gn.current
```

Then on the macOS side:

```bash
cp "$PROJECT_ROOT/exchange/args.gn.current" "$PROJECT_ROOT/local-src/out/PixelFold/args.gn"
```

Expected: no output. Verify with `tail -3 "$PROJECT_ROOT/local-src/out/PixelFold/args.gn"`; it should end with `safe_browsing_mode = 0`.

---

## Task 5: Stage 2b, remove AI, XR, and remaining phone-home flags

**Files:**
- Modify: `/work/chromium/src/out/PixelFold/args.gn`
- Modify: `local-src/out/PixelFold/args.gn` (macOS mirror)

- [ ] **Step 1: Append the remaining flags**

```
cd /work/chromium/src && cat >> out/PixelFold/args.gn <<'EOF'

# de-Google: AI and on-device model stack (stage 2b)
use_mlkit_for_aicore = false
build_with_model_execution = false
enable_glic_internal_resources = false

# de-Google: XR / Google SDK surfaces
enable_arcore = false
enable_cardboard = false
enable_vr = false
enable_openxr = false

# de-Google: network phone-home
enable_reporting = false
enable_service_discovery = false
enable_mdns = false

# de-Google: misc
enable_supervised_users = false
enable_offline_pages = false
EOF
tail -20 out/PixelFold/args.gn
```

Expected: all thirteen flags echoed back.

- [ ] **Step 2: Regenerate**

```
cd /work/chromium/src && gn gen out/PixelFold
```

Expected: `Done. Made NNNN targets from ...`

If this fails, bisect: remove the four XR flags first and regenerate, since `enable_vr = false`
with `enable_arcore = true` is the most likely inconsistent combination.

- [ ] **Step 3: Build the APK**

```
cd /work/chromium/src && autoninja -C out/PixelFold chrome_public_apk
```

Expected: build succeeds.

- [ ] **Step 4: Update the macOS mirror**

```
cp /work/chromium/src/out/PixelFold/args.gn /exchange/args.gn.current
```

Then on the macOS side:

```bash
cp "$PROJECT_ROOT/exchange/args.gn.current" "$PROJECT_ROOT/local-src/out/PixelFold/args.gn"
```

Expected: no output. Verify the two files match with:

```bash
diff "$PROJECT_ROOT/exchange/args.gn.current" "$PROJECT_ROOT/local-src/out/PixelFold/args.gn" && echo "in sync"
```

---

## Task 6: Verify the removals actually took effect

A successful build does not prove the code is gone. This task checks the artifact directly.

**Files:**
- Create: `exchange/stage2-manifest.txt`

- [ ] **Step 1: Copy out the final APK**

```
cp /work/chromium/src/out/PixelFold/apks/ChromePublic.apk /exchange/ChromePublic-degoogle-stage2-153.0.7999.0.apk
```

Expected: no output.

- [ ] **Step 2: Compare sizes**

On the macOS side:

```bash
ls -lh "$PROJECT_ROOT/exchange/"ChromePublic-degoogle-stage*.apk
```

Expected: the stage2 APK is meaningfully smaller than stage1. Dropping ML Kit, AICore, ARCore,
Cardboard, and OpenXR should be visible. If the sizes are within a megabyte of each other, the
flags did not take effect. Investigate before proceeding.

- [ ] **Step 3: Extract the shipped manifest**

The aapt2 binary is at `third_party/android_build_tools/aapt2/cipd/aapt2` (verified 2026-08-14).

```
cd /work/chromium/src && third_party/android_build_tools/aapt2/cipd/aapt2 dump xmltree out/PixelFold/apks/ChromePublic.apk --file AndroidManifest.xml > /exchange/stage2-manifest.txt && wc -l /exchange/stage2-manifest.txt
```

Expected: a line count in the thousands, written to `exchange/stage2-manifest.txt`.

- [ ] **Step 4: Confirm the AI and XR components are gone**

On the macOS side:

```bash
grep -icE "mlkit|aicore|ar\.core|cardboard|vrcore|openxr" "$PROJECT_ROOT/exchange/stage2-manifest.txt"
```

Expected: `0`. Any nonzero count means a component survived. Identify which and why before
declaring Stage 2 complete.

- [ ] **Step 5: Confirm what must still be present**

```bash
grep -icE "extension" "$PROJECT_ROOT/exchange/stage2-manifest.txt"
```

Expected: nonzero. Extensions are a hard requirement; if this is `0`, a flag removed more than
intended.

- [ ] **Step 6: Device verification**

Target device changed. The project was built against a Pixel Fold; the connected device as of
2026-08-14 is a **Pixel 10 Pro XL** (`mustang`), over wireless adb at `$DEVICE`.

| Property | Value | Note |
| --- | --- | --- |
| ABI | `arm64-v8a` | Matches `target_cpu = "arm64"` |
| Android | 17 (SDK 37) | Build targets SDK 36, forward-compatible |
| Screen | 1344x2992 @ 480dpi | 448dp wide, **phone layout**, not tablet |
| Installed | 153.0.7999.0, code 799900074, 2026-08-12 16:56 | The Aug 12 extension-fix APK |

Two consequences:

1. **adb lists this device twice** (explicit IP plus an mDNS TLS entry), so bare `adb` commands
   fail with "more than one device". Always pass `-s $DEVICE`.
2. **At 448dp this is a phone layout**, below Chromium's tablet threshold. The extensions toolbar
   coordinator will not be created, so this device exercises the *fallback* path added in commit
   `1edd8e56d1`, not the coordinator path the Fold hit. Good coverage, but it does not validate
   the Fold path.

The currently installed build is the correct pre-de-Google baseline for A/B comparison.

```bash
adb -s $DEVICE install -r "$PROJECT_ROOT/exchange/ChromePublic-degoogle-stage2-153.0.7999.0.apk"
```

Then confirm by hand:

1. Browser launches and loads a page.
2. An H.264/AAC video plays.
3. A Widevine-protected stream plays.
4. The extensions menu opens without crashing (the Crash 1 path, via the fallback branch).
5. No sign-in crash when opening settings (the Crash 2 path).

Capture any crash with:

```bash
adb -s $DEVICE logcat -d -b crash > "$PROJECT_ROOT/exchange/stage2-crash.log"
```

---

## Execution results (2026-08-14/15)

### Tasks 1-3: passed

Both crash-fix regression tests pass identically before and after the Phase 2 revert:
`NullAccountManagerDelegateTest` 2/2, `ChromeTabbedActivityUnitTest` 4/4 (each sharded across
API 29 and API 36). The `components/signin/public/android/BUILD.gn` split held: the Phase 1 test
registration survived `git checkout -- .` while the Phase 2 lines were dropped.

Stage 1 baseline APK: **489,491,956 bytes**. That is 8,227 bytes smaller than the 2026-08-12
build, consistent with three small Phase 2 Java classes leaving the APK.

Phase 2 archived at `exchange/phase2-abandoned-2026-08-14.patch` plus three `.java` files.

### Task 4: `safe_browsing_mode = 0` ABANDONED, diagnosed

`gn gen` **succeeded** (62,705 targets vs 62,728 baseline, 23 Safe Browsing targets dropped
cleanly). The ninja build then failed on exactly one file:

```
chrome/browser/safe_browsing/android/safe_browsing_bridge.cc:109:26
error: no member named 'safe_browsing_service' in 'BrowserProcess'
      g_browser_process->safe_browsing_service())
```

One un-gated call site: the Android JNI bridge calls `BrowserProcess::safe_browsing_service()`
unconditionally, but that method is compiled out at mode 0. This is a **one-file source patch**,
not a structural blocker. Guard the call site or exclude the file when mode is 0. Cromite carries
an equivalent patch. Moved to Stage 3.

### Task 5: 5 of 12 flags APPLIED, FINAL

Applied and verified in a shipping APK: `use_mlkit_for_aicore`,
`enable_glic_internal_resources`, `enable_reporting`, `enable_service_discovery`, `enable_mdns`.

Final APK: **487,924,549 bytes**, down 1,567,407 from the 489,491,956 Stage 1 baseline.
Manifest verification: `mlkit` 0 occurrences, `aicore` 0 occurrences, `extension` retained.

#### The XR group is coupled both ways: DEFERRED TO STAGE 3

`enable_arcore`, `enable_cardboard`, and `enable_openxr` initially appeared to apply cleanly
because `gn gen` accepted them. They do not survive a full build. There is **no GN-only
configuration** that removes Google's XR SDKs on Android.

`enable_vr` is not independent: its default is derived
(`device/vr/buildflags/buildflags.gni:36`):

```gn
enable_vr = enable_openxr || enable_cardboard || enable_arcore || (is_linux && ...)
```

**Direction 1: backends off (so `enable_vr` auto-false):** compilation fails.

```
searchbox_handler.cc:897 / :969  no member named 'GetVectorIcon' in 'AutocompleteMatch'
omnibox_edit_model.cc:1947       no member named 'GetVectorIcon' in 'AutocompleteMatch'
```

Both declarations sit behind `#if (!BUILDFLAG(IS_ANDROID) || BUILDFLAG(ENABLE_VR)) && !BUILDFLAG(IS_IOS)`
at `components/omnibox/browser/autocomplete_match.h:378` and
`components/omnibox/browser/actions/omnibox_action.h:24`. On Android that reduces to `ENABLE_VR`
alone, so the methods vanish while the omnibox calls them un-gated.

**Direction 2: backends off plus `enable_vr = true` forced:** JNI registration fails.

```
Failed JNI assertion!
Our native library depends on generate_jnis which reference Java files that we
do not include in our final dex.
Unneeded Java files:
  components/webxr/android/java/src/org/chromium/components/webxr/XrActivityListener.java
  components/webxr/android/java/src/org/chromium/components/webxr/XrSessionCoordinator.java
```

Forcing VR on generates native WebXR JNI bindings whose Java classes are excluded from the dex
because the backends are off.

Removing the XR SDKs therefore requires the omnibox source patch first. Until then, `ar.core`,
`cardboard`, `vrcore`, and `openxr` remain in the shipped manifest (6/8/1/2 occurrences).

Note that both failures surface only deep into compilation or dexing, hours after `gn gen`
succeeds. **`gn gen` accepting a flag is not evidence the flag works.**

#### Superseded note

An earlier revision of this document recorded the XR group as applied and `enable_vr` as a
separate abandonment. Both were wrong; the section above is authoritative.

#### Original diagnosis detail (retained)

The first compile failure observed was:

```
chrome/browser/ui/webui/cr_components/searchbox/searchbox_handler.cc:897:13
error: no member named 'GetVectorIcon' in 'AutocompleteMatch'
chrome/browser/ui/webui/cr_components/searchbox/searchbox_handler.cc:969:60
error: no member named 'GetVectorIcon' in 'OmniboxAction'
```

Root cause. Both declarations sit behind the same guard:

```c
#if (!BUILDFLAG(IS_ANDROID) || BUILDFLAG(ENABLE_VR)) && !BUILDFLAG(IS_IOS)
```

- `components/omnibox/browser/autocomplete_match.h:378`
- `components/omnibox/browser/actions/omnibox_action.h:24` (defines `SUPPORT_PEDALS_VECTOR_ICONS`)

On Android, `!IS_ANDROID` is false, so the condition reduces to `ENABLE_VR` alone. Setting
`enable_vr = false` deletes both `GetVectorIcon` declarations, but `searchbox_handler.cc` calls
them un-gated. Same failure class as Safe Browsing: a disabled flag compiles a method out from
under an unconditional caller.

`enable_arcore`, `enable_cardboard`, and `enable_openxr` are unaffected and remain applied.

Three more abandoned, all **GN `assert()` failures** rather than compile errors: the build config
was refused outright:

| Flag | Assert location |
| --- | --- |
| `build_with_model_execution` | `chrome/browser/ai/BUILD.gn:9` |
| `enable_supervised_users` | `chrome/test/BUILD.gn:57` |
| `enable_offline_pages` | `chrome/browser/offline_pages/BUILD.gn:7` |

`enable_supervised_users` is the softest of the three: its assert lives in **test** code, not
browser code, so it may be removable without touching anything that ships.
`build_with_model_execution` is the highest-value recovery: it is the framework the built-in AI
features hang off, a larger prize than the ML Kit bridge alone.

`gn gen` with the 9 applied flags: **62,392 targets** (down 336 from 62,728), confirming the flags
took effect at config level.

### Infrastructure finding: Docker memory was the real bottleneck

Three consecutive builds died with `spawn-helper: read: connection reset by peer`. This was
diagnosed as **memory exhaustion, not a code or agent failure**: the container peaked at
13.4 GiB of 15.6 GiB with 126 MiB free while running 12 parallel compile jobs. Chromium C++ under
Rosetta consumes 1-2 GB per job.

Docker Desktop's allocation was raised from 15.6 GiB to **31.3 GiB** on 2026-08-15. At `-j 12` the
build now sits at 11.9 GiB (38%) with ample headroom. Earlier tasks survived only because they
were largely cached (2,003 steps); the Stage 2b rebuild invalidated 25,189 steps and ran far more
jobs concurrently.

Note that raising the Docker memory setting restarts the Docker VM and kills any running build.

### Added to Stage 3 scope

Four items, each with a precise diagnosis, in addition to the network patches already planned:

1. Guard `safe_browsing_bridge.cc:109` (or exclude the file at mode 0), then re-apply
   `safe_browsing_mode = 0`
2. Relax `chrome/browser/ai/BUILD.gn:9` assert, then re-apply `build_with_model_execution = false`
3. Relax `chrome/test/BUILD.gn:57` assert (test-only), then re-apply
   `enable_supervised_users = false`
4. Relax `chrome/browser/offline_pages/BUILD.gn:7` assert, then re-apply
   `enable_offline_pages = false`
5. **XR group (highest value remaining).** Guard the `GetVectorIcon` call sites at
   `searchbox_handler.cc:897`, `searchbox_handler.cc:969`, and `omnibox_edit_model.cc:1947`, then
   set `enable_arcore`, `enable_cardboard`, and `enable_openxr` to false: `enable_vr` follows
   automatically. Do NOT force `enable_vr = true` as a workaround; that breaks WebXR JNI
   registration instead. This removes `com.google.ar.core`, `com.google.cardboard.sdk`,
   `com.google.vr.vrcore`, and `libopenxr.google.so`.

6. **Extensions toolbar on phone layouts (usability, not de-Googling).** On a phone-width layout
   there is no way to open an extension's popup or pin it, only enable/disable/remove via
   `chrome://extensions`. Confirmed cause:

   - `setExtensionsToolbarCoordinator` is implemented only in
     `chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarTablet.java:469`
   - The base implementation at `ToolbarLayout.java:205` has an **empty body**, so the phone
     toolbar silently discards the coordinator
   - Routed through `TopToolbarCoordinator.java:531`
   - Tablet is gated by `MINIMUM_TABLET_WIDTH_DP = 600`
     (`ui/android/java/src/org/chromium/ui/base/DeviceFormFactor.java:78`)

   Verified on device 2026-08-15: forcing ≥600dp (`adb shell wm density 340` on a 1344px screen
   → 632dp) produces the full tablet UI with the extensions toolbar, per-site permissions,
   **Pin to toolbar**, and working extension popups (Bitwarden login confirmed).

   The patch is to create the coordinator on phone layouts and give `ToolbarPhone` somewhere to
   host it. This is genuine UI work: the phone toolbar has no space designed for extension icons.

   **Do not ship the density workaround.** Changing `wm density` is system-wide, and on the test
   device it caused the launcher to rebuild its home screen grid and drop icons, which resetting
   the density did not restore.

7. **External intents: stop links opening in apps.** Navigations to sites with an installed app
   (Reddit, YouTube, etc.) hand off to that app with no prompt and no in-browser setting to stop
   it. Patch `components/external_intents/android/java/src/org/chromium/components/external_intents/ExternalNavigationHandler.java`
   so external intents are never auto-launched. Cromite carries an equivalent patch.

   Android-side mitigation that needs no rebuild, per app:
   `adb shell pm set-app-links --package <pkg> 0 all`, or Settings → Apps → *app* →
   Open by default → disable "Open supported links". There is no global Android toggle.

### Already neutralized upstream: do not re-investigate

Verified 2026-08-15. Several targets originally listed for Stage 3 need no work, because a
public (non-Chrome-branded, non-official) Chromium build already has them disabled. Recorded
here so they are not rediscovered later.

| Target | Why it is already dead |
| --- | --- |
| UMA metrics upload | All URLs in `components/metrics/server_urls.grd` are `-` placeholders |
| UKM (URL-keyed metrics) | Same mechanism, `IDS_UKM_SERVER_URL` |
| DWA / Cast / private metrics | Same mechanism |
| Crash upload | `CrashReporterClient::GetUploadUrl()` returns `std::string()` |
| Navigation error correction ("link doctor") | No endpoint present in this tree |

**Metrics.** `components/metrics/server_urls.cc` reads every endpoint from a GRIT resource, and
the public `server_urls.grd` carries a `-` placeholder for each, which `GetUrl()` converts to an
empty `GURL()`. The file states the intent directly: the real URLs live in an internal grd
"to prevent Chromium forks from accidentally sending metrics to Google servers."

**Crash upload.** `components/crash/core/app/crash_reporter_client.cc:148`:

```cpp
std::string CrashReporterClient::GetUploadUrl() {
#if BUILDFLAG(GOOGLE_CHROME_BRANDING) && defined(OFFICIAL_BUILD)
  return kDefaultUploadURL;   // https://clients2.google.com/cr/report
#else
  return std::string();
#endif
}
```

This build satisfies neither condition, so the upload URL is empty and `kDefaultUploadURL` is
not even compiled in.

This is the same class of finding as the missing Google API keys recorded in `docs/design.md`:
the build is substantially more de-Googled out of the box than a generic de-Googling guide
would suggest. Confirm before patching.

### Still live after the above

| Target | Endpoint | Location |
| --- | --- | --- |
| Autofill crowdsourcing | `content-autofill.googleapis.com` | `autofill_crowdsourcing_manager.cc:127` |
| Translate | `translate.googleapis.com`, plus a ranker model URL | `translate_ranker_impl.cc:83`, `:87`, `:91` |
| Component updater | Google update service | Deliberately retained for CRLSets |

Autofill crowdsourcing uploads the structure of encountered forms (field names and types).
Local autofill is unaffected by its removal. The translate ranker has three conditional URL
definitions, so it needs reading before patching rather than a single-line change.

### First-run experience: priority item for Stage 5

On a fresh profile the browser opens a full-screen first-run page: "Make Chrome your own",
"Sign in to get your bookmarks, passwords, and more on all your devices", with **Add account to
device** as the primary action and *Stay signed out* as the secondary.

Two reasons to remove it, the second stronger than the first:

1. It is a Google sign-in promotion, and sign-in does not function in this build (no API keys).
2. Its footer states: *"To help improve the app, Chrome sends usage and crash data to Google."*
   **That is false here.** Metrics endpoints are empty placeholders and
   `CrashReporterClient::GetUploadUrl()` returns an empty string, as recorded above. The screen
   asks the user to accept a data-sharing statement describing behaviour the binary does not have.

A build that claims to send data it cannot send is worse than one that simply says nothing, so
this ranks above the Settings and New Tab Page surfaces in Stage 5.

### Also observed for Stage 5 (UI removal)

Beyond the Settings entries already scoped, the New Tab Page still carries Google branding, an
**AI Mode** button, Discover, Chrome tips, and a sign-in promo. The NTP is more visible than the
settings entries and belongs in Stage 5's scope.

### GN assert findings (tested 2026-08-15)

The three abandoned flags were assumed to share one cause: test targets in the graph asserting
on production flags. Testing showed they do not.

**`enable_supervised_users`: structurally blocked, not a test artifact.** Relaxing the assert at
`chrome/test/BUILD.gn:57` only exposed a second one at **`chrome/android/BUILD.gn:15`**, reached
via `//chrome/android:chrome_junit_tests` from the root `BUILD.gn`. That file builds
`chrome_public_apk` itself, so the flag is genuinely required by the Android build. Removing
Family Link support needs real code changes, not assert relaxation. Attempt reverted.

**`enable_offline_pages`: assert is test-only.** It fires at
`chrome/browser/offline_pages/BUILD.gn:7`, reached from `chrome/test/BUILD.gn:1581`
(`//chrome/browser/offline_pages:impl`). Unlike supervised users, nothing in `chrome/android`
asserts on it, so this one may be reachable by guarding the test dependency. Untested.

**`build_with_model_execution`: needs dependency surgery.** `//chrome/browser/ai` is referenced
from at least five places in `chrome/test/BUILD.gn`, so removing the dep is not a single edit.
Note the practical value is limited: the AI models and services are already disabled through
`use_mlkit_for_aicore`, `enable_glic_internal_resources`,
`build_with_internal_optimization_guide`, `enable_ml_internal` and `use_on_device_model_service`.
This flag would remove the remaining framework code, which is a size win rather than a
behaviour change.

### Pre-existing limitation: passkeys

`Fido.FIDO2_PRIVILEGED_API` is restricted to Google-signed browsers. A self-built Chromium is
refused with `ApiException: 17`, logged by `cr_ChromiumWebauthn` at startup. Confirmed
pre-existing by reproducing it on an earlier build, so it is inherent to self-building rather
than caused by any patch in this series.

### Build diagnostics: where errors actually appear

`autoninja` writes almost nothing to stdout/stderr under siso: a redirected build log may contain
only four lines and no error at all, even on failure. **Real build errors are in
`out/PixelFold/siso_output`**, with re-runnable commands in `out/PixelFold/siso_failed_commands.sh`.
Always check those on a nonzero exit; the redirected log is not sufficient.

Similarly, tailing a build log is not a liveness check: siso can appear frozen at
`waiting for lock holder` while compiling normally. To judge whether a build is alive, count
recently written objects:

```
find out/PixelFold/obj -newermt "-5 minutes" -name "*.o" | wc -l
```

## Definition of done

- `git status` in the checkout is clean; branch `local-patches` at `1edd8e56d1`.
- `out/PixelFold/args.gn` and `local-src/out/PixelFold/args.gn` are identical in content.
- Both JUnit regression tests pass.
- `exchange/stage2-manifest.txt` contains zero ML Kit, AICore, ARCore, Cardboard, VrCore, or
  OpenXR references, and a nonzero count of extension references.
- The stage2 APK is measurably smaller than the stage1 APK.
- Phase 2 is archived at `exchange/phase2-abandoned-2026-08-14.patch`.

Any Stage 2a flag that had to be abandoned is recorded with its error, so the follow-on plan can
address it as source work rather than rediscovering it.
