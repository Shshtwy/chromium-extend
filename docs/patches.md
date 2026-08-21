# What the patches do

Every change Bare makes to Chromium, in the order the series applies. The patches
themselves are in [`patches/`](../patches); this is the summary of what each one is for.

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
| 0011 | Ignore page requests to lock screen orientation | Fullscreen video forced landscape, overriding the system rotation lock |
| 0012 | Draw fullscreen content into the display cutout | Fullscreen video was letterboxed off the camera edge, leaving it off-centre |
| 0013 | Size fullscreen video to its picture | The seekbar sat at the bottom of the screen instead of on the video |
| 0014 | DuckDuckGo as the default search provider | Google was the shipped default, selected by engine ID rather than list order |
| 0015 | Remove the sign-in first-run screen | Promoted a sign-in this build cannot do, and claimed data is sent to Google |
| 0016 | Stop showing the NTP sign-in card | "Get better content": sign in to personalise a feed this build cannot use |
| 0017 | Remove the Chrome tips module | A carousel of Google promos: history sync, sign-in, passwords, Safe Browsing |
| 0018 | Never offer the web app restore promo | Restores apps from devices "connected to this account", impossible here |
| 0019 | Remove the Ask Gemini button | The bottom bar's extra slot resolved to Gemini, which demands account verification |
| 0020 | Remove the avatar sign-in button | "Signed out. Opens options to sign in." on every new tab page |
| 0021 | Stop offering Gemini as a toolbar shortcut | Otherwise the button removed in 0019 could be put back from Settings |
| 0022 | Offer downloads to an installed download manager | Hands a download to an app such as 1DM instead of fetching it in the browser |
| 0023 | Add a setting to choose the download manager | Settings → Downloads, off by default |
| 0024 | Browse the Chrome Web Store as a desktop site | The mobile store has no install button, so extensions could not be installed |
| 0025 | Turn off the AI Mode omnibox button | An AI entry point in the omnibox, on by default |
| 0026 | Hide the shortcuts row and NTP cards by default | Both already had toggles; only the starting state changed |
| 0027 | Lower the search box into thumb reach | Sits around 40% down the page rather than near the top |
| 0028 | Move the tab switcher toolbar to the bottom | Its buttons stayed at the top while the browsing toolbar sits at the bottom |
| 0029 | Pick which download manager receives downloads | Lists installed handlers, or ask every time |
| 0030 | Add an incognito toggle to the bottom bar | Fills the slot 0019 emptied; red while incognito is active |
| 0031 | Reword the toolbar shortcut window width note | "Only available for small windows" read as excluding phones |
| 0032 | Lower the search box to the middle of the screen | 40% was still higher than a thumb comfortably reaches |
| 0033 | Stop painting white while a page loads on a dark theme | Three surfaces defaulted to white; adds the darken-websites setting |
| 0034 | Default the toolbar shortcut to Share | It defaulted to "based on your usage", which moves the button as habits change |
| 0035 | Let the user add their own search engine | Chromium's add-engine screen existed but was switched off on Android |
| 0036 | Remove the built-in Gemini and AI Mode shortcuts | @gemini and @aimode shipped as search shortcuts pointing at Google |
| 0037 | Round the search engine icon in the omnibox | The rounding provider was built and updated but never attached to the view |
| 0038 | Rename the browser to Bare | Launcher, widgets, About page and the menu description |
| 0039 | Use the Bare icon | Legacy, adaptive and monochrome variants in every density |
| 0040 | Stop badging settings rows as new | "New" appeared beside Address bar and Appearance on every fresh profile |
| 0041 | Skip the first run experience | It opened a second Activity that only showed a spinner |
| 0042 | Add the Bare welcome screen | One-time welcome layered over the browser, not its own Activity |
| 0043 | Let supported sites keep playing media in the background | Opt-in, off by default; the page is told it is still visible so it does not pause itself |
| 0044 | Rename the browser in the remaining Android strings | 337 strings still said Chrome; Google's own products keep their names |
| 0045 | Remove the Autofill AI and personal context settings | "Smarter form understanding" shared page URLs and content with Google |
| 0046 | Use the installed password manager by default | And relabel the built-in option, which claimed to use your Google Account |
| 0047 | Animate a new tab from the button that opened it | From the tab switcher it grew from the top corner, ignoring the bottom bar |
| 0048 | Keep the search engine icon round in thumbnails | Outline clipping is skipped when a view is drawn into a software canvas |
| 0049 | Add a Video autostart site setting | Chromium stored an autoplay setting nothing ever read |
| 0050 | Keep sites told the page is visible in the background | Sites paused their own video on `visibilitychange`, defeating background playback |
| 0051 | Keep background playback permission when hidden | The permission was withdrawn the moment the page stopped being visible |
| 0052 | Add DuckDuckGo No AI as a prepopulated engine | Selectable from the engine list rather than added by hand |
| 0053 | Show the NOAI wordmark on the new tab page | The engine had no logo, so the page showed nothing |
| 0054 | Fix a crash when Video autostart is switched back on | Introduced by 0049 |
| 0055 | Use the Bare mark in the media notification | The lock screen still showed Chromium's |
| 0056 | Look under overlays laid over images and video | Sites cover media with a transparent layer, which defeated the long press |
| 0057 | Keep Manifest V2 extensions working | Chromium 153 disables MV2 outright; full uBlock Origin needs it |
| 0058 | Ship the MV2 action schemas in this build | Their absence killed the renderer for any extension using them |
| 0059 | Ship uBlock Origin with the browser | Pre-installed, unpinned, removable like anything else |
| 0060 | Use the Bare mark for the launcher icon | Adaptive, themed and legacy variants |
| 0061 | Offer the main settings on the welcome screen | Search engine, ad blocker, address bar, downloads, chosen before anything loads |
| 0062 | Finish renaming the browser in the remaining strings | The strings the first rename pass missed |
| 0063 | Remove Ask Gemini from the app menu | It appeared once on first launch, then never again |
| 0064 | Offer a download for audio elements | A long press on an `<audio>` element produced an empty menu |
| 0065 | Offer a download for video the page only streams | Media Source video has no downloadable src, so upstream offers nothing |
| 0066 | Follow range requests back to the whole file | A range-fetched URL names a slice, not the file, and audio is a separate track |
| 0067 | Stop asking the user to sign in to a Google account | Six surfaces built the same promo; all six ask one method first |
| 0068 | Let extension context menu items run their own command | The menu overwrote the listener extensions arrive with, so tapping one did nothing |
| 0069 | Add in-browser developer tools and element inspector | On-device DOM inspector and DevTools console powered by bundled Eruda |
| 0070 | Add Safe Shield anti-porn family filter and SafeSearch | Intercepts explicit domains, enforces SafeSearch, Family DoH and parental panel |
| 0071 | Add touch and letter navigation gestures | Edge swipes, gesture trail, and letter 'C' (Close) tab closure recognizer |
| 0072 | Add Spanish interface translations | Spanish (es / es-419) translations for gestures, Safe Shield, settings, media, devtools and welcome onboarding |

Patches 0001 and 0002 are bug fixes that happen to be prerequisites. 0003 is a usability fix.
0004 through 0010 are the de-Googling, as are 0014 through 0021. 0011 through 0013 fix
fullscreen video behaviour. 0022 and 0023 add the external download manager option. 0024
through 0028 are usability changes: the Web Store, the AI Mode button, what the new tab page
shows by default, and where the toolbars sit. 0029 through 0033 continue in that vein: choosing
the download manager, the incognito toggle, clearer wording in settings, where the search box
sits, the white flash on a dark theme, which shortcut the toolbar starts with, and adding your
own search engine. 0036 drops the built-in Google AI search shortcuts and 0037 fixes the shape
of the engine icon in the omnibox. 0038 through 0042 are the rebrand to Bare, and 0044 finishes
the naming the first pass missed. 0043 adds background media playback. 0045 and 0046 continue
the de-Googling in autofill: removing the AI sections, and defaulting to whichever password
manager the user already has. 0047 and 0048 are small visual fixes found by using the build:
where a new tab animation starts, and an icon that was clipped round rather than drawn round.

Sign-in has no single gate in Chromium. Patches 0009, 0010, 0015, 0016 and 0020 each remove a
different entry point: the settings row, the "You and Google" section, the first-run screen,
the New Tab Page card, and the toolbar avatar. Assume there are more rather than fewer.

## Removed by build flag

These go in `args.gn` rather than a patch:

```gn
use_mlkit_for_aicore = false          # ML Kit + AICore (on-device Gemini Nano bridge)
enable_glic_internal_resources = false # Gemini-in-Chrome surface
enable_reporting = false               # Reporting API / Network Error Logging
enable_service_discovery = false       # local device discovery
enable_mdns = false                    # mDNS

chrome_public_manifest_package = "org.barebrowser"  # application id
```

The application id is a build argument rather than a patch, because upstream already exposes
it as one. Note that changing it means the app installs alongside an earlier build rather
than upgrading it: Android identifies apps by package, so tabs, extensions and settings do
not carry over.

## What is deliberately kept

| Kept | Why |
| --- | --- |
| Extensions (`enable_extensions_core`) | The entire point of the Desktop Android target |
| Proprietary codecs (`ffmpeg_branding = "Chrome"`) | H.264/AAC video playback |
| Widevine | DRM. Removing it breaks paid streaming |
| Component updater | Delivers CRLSet certificate revocation data |
| HSTS preload list | Static security asset, no callback |

## Verified on device

Recorded when each of these landed, on a Pixel 10 Pro XL.

Extensions install and run (Bitwarden, uBlock Origin, Dark Reader, Bypass Paywalls Clean),
popups open and pinning works. Both crash reproductions behind 0001 are gone, and the shipped
`AndroidManifest.xml` contains no reference to ML Kit or AICore.

**0005** against a real in-page link tap: following a Reddit result from a search page keeps you
in the browser, with Reddit's own "Open App" prompt left unused.

**0011 and 0012**: fullscreen video follows the phone's orientation instead of forcing landscape,
and sits centred in both portrait and landscape. **0013** by geometry read off the running page,
for both a 16:9 video and one taller than the viewport.

**0014 and 0015** on a wiped profile, which is the only honest test for either: the new tab page
shows DuckDuckGo and a query resolves to `duckduckgo.com`, and the browser opens straight to the
new tab page with no first-run screen, including after a force stop and relaunch, which is what
fails if the Terms of Service acceptance does not persist.
