# Public Google Drive Music Player — Living Brainstorm

> **Current-version access decision (2026-11-15):** The user has explicitly restricted this version to **anonymous, no-API-key access**. Earlier developer-key fallback allowances in this document and derived tickets are superseded for this version; they remain historical context. Do not add a key, OAuth, listener login, or backend. The [T01 probe evidence](docs/evidence/t01/RESULTS.md) is partial and the downstream gate remains **open**.

> **Status:** OpenMP3 v0.1 weekend prototype kickoff; implementation unverified  
> **Version:** 0.11 (document revision; not the app release version)  
> **App release target:** 0.1 — experimental iPhone weekend prototype  
> **GitHub kickoff issue:** [#1 — OpenMP3 v0.1](https://github.com/eugenelin89/OpenMP3/issues/1)  
> **Created:** 2026-11-14  
> **Last updated:** 2026-11-14  
> **Working title:** Drive Folder Music Player (name TBD)  
> **Purpose:** A living source of truth for brainstorming, technical experiments, decisions, and Codex implementation.

## Weekend prototype kickoff — OpenMP3 app v0.1

- **Single kickoff issue:** [GitHub #1 — OpenMP3 v0.1 weekend prototype](https://github.com/eugenelin89/OpenMP3/issues/1). Use this as the entry point for the installed Matt Pocock/Codex workflow; let that workflow break the work into small implementation tickets.
- **Release goal:** One demonstrably working native iPhone player for public Drive-folder MP3 streaming; no production-grade roadmap, backend, login, or App Store release required.
- **Build order:** Validate anonymous recursive discovery and playback **without any Google Drive API key**. If this path is unreliable, document the blocker and stop for a product decision; **do not add an API key, OAuth, or backend in v0.1**. Then deliver the retro player, folder queue, shuffle, and **required background/lock-screen playback while another app (especially Google Maps navigation) is foregrounded**; add local custom playlists as capacity allows.
- **Time-boxing principle:** Preserve a playable vertical slice even if stretch features remain unfinished. **Saved custom playlists are optional for v0.1 sign-off**, as is premium entitlement simulation. Core release requires recursive folder playback, transport/seek/shuffle/repeat, retro UI, verified background audio during navigation, and compatibility with the single platform baseline. Clearly distinguish tested behavior from aspirations.
- **API-key decision (updated 2026-11-15, supersedes D-013 for v0.1):** **No API key of any kind for v0.1**, including developer-configured keys. No Google sign-in, OAuth, or backend. Verify real discovery, file access, streaming and seeking separately. If no-key discovery is unreliable, **stop, record evidence and revisit the product promise**; only a later explicit product decision could authorize a different architecture for a future version.
- **Scope authority:** This document remains the detailed ideas/requirements log; issue #1 defines the executable weekend-prototype checklist. The **app release target v0.1** is separate from this document's revision number. Keep all concrete platform versions and device-model targets **only** in the [platform compatibility baseline](#platform-compatibility-baseline-single-source-of-truth); other sections and GitHub issues link to it.

## Platform compatibility baseline (single source of truth)

> **Canonical configuration for OpenMP3 v0.1.** Update the version and reference device **only here**. Other parts of this document and GitHub Issue #1 must link to this section rather than repeat those values.

- **Minimum supported OS / Xcode deployment target:** **iOS 15.0**.
- **Legacy reference device for compatibility testing:** **iPhone 8**, with **iPhone 8 Plus** in the same support class. The reference device must be running a supported OS version. Apple's compatibility list includes these models in iOS 16; they are not eligible for iOS 17. Older models able to run the minimum OS may work too, but are **not** an additional tested-hardware promise.
- **Support policy:** The app must install, launch, load a public Drive folder, play MP3s, and perform the P0 background-navigation scenario on supported devices. Avoid newer-only SDK features or frameworks that raise the deployment target; gate newer APIs with availability checks and a usable fallback.
- **Build-tool caveat:** Apple's Xcode deployment-target range does not always equal its direct device-install/debug range. In particular, Xcode 27 supports iOS 15 deployment targets but lists iOS 17 or later for direct device support; use an appropriate supported Xcode toolchain or another validated installation/test method for older physical hardware. Do not assume successful compilation proves old-device compatibility.
- **Validation status:** Requirement confirmed, **not yet implemented or tested**. Test on the reference device when available; otherwise record compatibility as unverified, not passed. Recheck SDK/dependency support before changing this baseline.
- **Change control:** Any proposal to raise the minimum must be an explicit product decision; update this section, the Xcode project settings, and the corresponding test evidence together.

**Reference material:** [Apple's iOS 16 device list](https://support.apple.com/en-ca/103267) · [Apple's Xcode SDK/device-support matrix](https://developer.apple.com/xcode/system-requirements/) · [Apple's API-availability guidance](https://developer.apple.com/documentation/xcode/running-code-on-a-specific-version/)

## Monetization proposal (single source of truth for commercial terms)

> **Product direction confirmed:** The app should be free to download and useful without paying. **Specific paid feature and price are proposals, not approved App Store settings.** This is a small weekend experiment, so a working playback prototype takes precedence over live billing.

- **Always free:** Add public Drive folders, recursively discover and stream MP3s, play in folder mode, shuffle/repeat, transport/seek, and keep audio playing with the screen locked or Google Maps in front. No Google account or OpenMP3 account is required.
- **Proposed optional upgrade:** A **single lifetime unlock for creating and managing unlimited custom playlists** across the user's accessible folders. No per-playlist charges and no subscription. Do not charge for listening to folder-based music.
- **Proposed price:** **about CA$0.99 one time**, subject to available App Store Connect price points, taxes, and localized pricing. This is a target, not a verified live storefront offer.
- **Planned implementation:** Apple's **StoreKit non-consumable in-app purchase** (working title `Unlimited Playlists`) with Restore Purchases, explicit price display, purchase cancellation/failure handling, and local entitlement state backed by verified transactions. No third-party checkout for an in-app digital feature.
- **Prototype boundary:** v0.1 can demonstrate creating and saving playlists locally (including via a development/test entitlement). **No real charges, paywall requirement, or live App Store Connect product should block the weekend prototype.** Add the actual StoreKit purchase flow when preparing for App Store distribution; never ship a fake purchase button.
- **Compatibility:** All purchase integration must respect the [platform compatibility baseline](#platform-compatibility-baseline-single-source-of-truth); do not raise deployment requirements just to add monetization.
- **Unresolved design question:** Whether playlists specifically should be the paid benefit, versus offering one free custom playlist or charging for a different power-user feature. Decide before implementing a real paywall.

## v0.1 recursive scan boundary and limits

> **Canonical v0.1 traversal policy:** Keep the exact caps and shortcut behavior defined here. Elsewhere (including Issue #1 and Codex tickets), reference this section rather than independently hardcoding thresholds.

- **Scope:** Only the supplied public root folder and its **actual descendant folders**. **Do not follow Google Drive shortcuts**, whether pointing to a file or another folder (inside or outside the tree); count/report skipped shortcut entries visibly.
- **Maximum MP3s per root scan:** **1,000** eligible MP3s.
- **Maximum actual folders per root scan:** **100 total, including the root folder**.
- **Additional work budgets (numbers pending feasibility evidence):** Bound the **number of Drive listing requests**, **elapsed wall-clock scan time**, and **retry attempts** per scan/request. During the feasibility spike, measure representative nested and non-audio-heavy folders, select reasonable numeric maximums, and record them **here only before implementation acceptance**. These budgets must prevent a huge single folder from causing an unbounded scan even if MP3/folder caps are not reached. The agreed requirement to bound work is P0; specific numeric values are deliberately **TBD until measured**, not assumed unlimited.
- **T01 measurement status (2026-11-15):** [Follow-up evidence](docs/evidence/t01/RESULTS.md) now includes a deeper tree with 31 listing requests plus root validation, 47 discovered MP3s at relative depth three, 54 ignored non-MP3 entries, and a 70.301-second pre-fix scan. Real pagination, resource-key-protected access, a large single non-audio-heavy folder, shortcuts and inaccessible descendants remain unresolved. Work budgets below are **provisional recommendations**, not accepted T01 budgets.
- **Provisional listing-request budget:** **60 listing attempts per scan, including retries**. This allows nearly twice the measured deeper-tree listing work while bounding unsupported pagination or oversized trees. Root validation is separately counted and shares the wall-clock/retry bounds. This is a conservative engineering recommendation for the observed workloads, not proof that every tree up to the folder cap completes.
- **Provisional wall-clock budget:** **180 seconds per foreground scan**. This exceeds twice the longest observed deeper-tree scan and leaves room for bounded retry attempts. Stop immediately on foreground exit or the listener's Stop action, preserve discoveries, and report incomplete coverage. The observed scans include parsing but exclude media retrieval.
- **Provisional retry budgets:** **1 additional attempt per failed request, 2 additional attempts across the scan, with a 1-second delay**; retry only temporary network/server/quota failures within all other bounds. No live 429/5xx or successful retry was observed: the retry recommendation is a deliberately small recovery allowance, **not an empirically established optimal policy**. With the experiment's bounded transport timeout, this keeps additional work finite; access denial and parsing failures are not retried.
- **Acceptance status of these recommendations:** **Not accepted as final application budgets.** Confirm them against genuinely multi-page and non-audio-heavy fixtures, resource-key coverage and observed retry conditions before closing T01. The owner subsequently requested a provisional overnight app with pragmatic checks; using these as explicitly provisional controls does not close T01 or certify downstream tickets.
- **Truncation behavior:** If any limit or work budget prevents complete traversal, stop within the bounds, retain all already discovered MP3 entries for later attempted playback and display **Incomplete scan** with a clear reason and discovered count. Never label truncated scans complete. Empty/private/unavailable subfolders must also be distinguished from a complete scan.
- **Non-MP3 files:** Ignore (apart from reporting skipped shortcuts when encountered); use stable file IDs so same-named tracks in different folders are distinguishable.
- **Validation on demand:** Display MP3 entries as **discovered tracks**, not as guaranteed playable. Do not download or decode all audio during the scan. Validate a track only when its playback is attempted; corrupt/unsupported MP3s are marked unavailable and skipped under the [playback failure policy](#v01-collection-queue-and-recovery-behavior).
- **Foreground-only / one scan:** Run at most one root scan at a time. If the app leaves the foreground, **end the current scan as incomplete** and keep discovered tracks in a settled, playable collection; do not continue crawls in the background. A pre-existing playing queue must continue playing via the audio background mode. Do not confuse background MP3 playback with background folder discovery.
- **Validation:** Test roots, nested descendants, ignored shortcuts, exactly-at-limit and over-limit fixtures, a huge non-audio-heavy folder, explicit Stop scan, background transition, partial failures, and playback attempts from discovered entries after a cutoff. Record listing/time/retry evidence and the chosen budget values here before calling P0 implemented.

## v0.1 collection, queue and recovery behavior

> **Canonical playback rules for grilling decisions Q6–Q12 and Q21–Q23, supplemented by the [transport/visual rules](#v01-playback-controls-and-screen-behavior) for Q13–Q20 and Q24.** Later specs and tickets should reference this section rather than inventing different behavior. None of these decisions changes the separate [platform compatibility baseline](#platform-compatibility-baseline-single-source-of-truth) or [scan limits](#v01-recursive-scan-boundary-and-limits).

- **Multiple saved roots, one active queue:** Persist multiple public Drive root links. Save and restore the last *selected* root. A root selection or new scan **never** replaces or interrupts music already playing. An explicit **Play/Play All** from a settled collection replaces the active queue; combining multiple root collections is deferred.
- **Reuse settled results until Rescan (Q21):** For the current app session, revisiting a previously scanned root displays that root's settled discovery results without starting a new scan. **Rescan** starts fresh, discards old browsing results, and replaces them even when new results are incomplete; **never merge stale discoveries**. A Rescan does not interrupt or modify the existing playback queue. App termination clears in-session collections, while saved root links and last selected root remain available for fresh scanning.
- **Remove saved root without stopping music (Q22):** Remove its local saved link and browsing collection only; never delete or modify its Google Drive content. If it was the selected root, browsing moves to **unselected**. A playing queue sourced from the removed root and its original **queue source label** remain intact, subject to media availability.
- **Failure scope and empty folders (Q23):** If a descendant folder cannot be read, identify it, mark **Incomplete scan**, and continue accessible siblings within scan budgets. A fully readable root tree with zero discovered MP3s is **successfully empty**, not an error. Root-load failure or exhausted scan-wide network/quota failure ends discovery with a clear explanation, preserving any discoveries already made when appropriate. **Disable Play when no tracks were discovered**; never claim an empty or unscanned collection can be played.
- **Scan gate / Stop scan:** New collections are playable only after scanning has **completed**, **failed partially**, **stopped at a documented limit/work budget**, the listener has pressed **Stop scan**, or **the app leaves the foreground** (ending the scan incomplete). Run one foreground scan at a time. Keep discovered tracks playable in incomplete results, and label incomplete/partial scans and why they stopped. Existing playback can continue in the background while another root is scanned. **Load/scan never autoplays.**
- **Default queue order:** For ordinary, non-shuffled playback, play MP3s in the root folder first; then group by relative descendant folder path, then sort filenames *within each folder*, using natural numeric ordering (e.g., `02` before `10`). Use a deterministic tie breaker for duplicate names. Shuffle changes queue order only when explicitly enabled.
- **Relaunch/termination:** Persist saved root links and last selected root; do **not** automatically restore the previous queue, shuffle history or playback position after the app has been terminated. Require a fresh scan and an explicit Play after a cold relaunch. This **does not affect** required uninterrupted playback while the app is merely backgrounded or the screen is locked.
- **Cellular use:** Cellular streaming is enabled by default, with a visible and understandable mobile-data notice. Defer a Wi-Fi-only switch. Never autoplay from a saved/root folder merely because Load finished.
- **Playback failure policy:** A definitively deleted/inaccessible MP3, or an MP3 proven corrupt/unsupported **on playback attempt**, is marked unavailable and skipped to the next playable track. A potentially recoverable **network, connectivity or quota** failure gets bounded retries, then pauses on the current track with a **Retry** action and best-effort preservation of position. Do not misclassify temporary quota/access errors as permanently missing music; no infinite retry/skip loops. When no playable tracks remain, stop with a clear explanation.
- **Navigation/interruption policy:** Google Maps announcements may duck the audio or temporarily interrupt it. Resume after a system interruption only when permitted and only if OpenMP3 was playing beforehand. A deliberate user pause remains paused; headset/Bluetooth disconnection pauses and reconnection alone **never autoplays**.
- **Acceptance coverage:** Test switching roots while playing, incomplete scan Stop/limit behavior, stable default ordering, cold relaunch, cellular disclosure, removed-vs-temporary file failures, and navigation prompts plus user/disconnect pause precedence. On-device claims require actual test evidence.

## v0.1 playback controls and screen behavior

> **Canonical Q13–Q20 and Q24 playback and UI decisions.** The [collection/queue/recovery policy](#v01-collection-queue-and-recovery-behavior) still defines saved roots, scan-to-queue transitions, relaunch, failures and interruptions. The [scan boundary](#v01-recursive-scan-boundary-and-limits) owns all scan budget numbers.

- **Repeat Off / All / One (Q13):** Off stops at the queue end. All starts a fresh full cycle; with shuffle enabled, reshuffle the new cycle and avoid immediately replaying the last track across the cycle boundary when multiple alternatives exist. One repeats the current track after **natural completion**; **manual Next still advances**. At the final track, manual Next starts a new cycle **only under Repeat All**; Repeat Off and Repeat One instead end the queue. Explicit Previous or user-selected tracks may replay a song.
- **Play after natural exhaustion (Q24):** Pressing the player's **Play** after the active queue naturally finishes starts a fresh cycle of that **same queue source**, not the currently browsed/selected root—even if the saved root link has since been removed. Respect existing Repeat/Shuffle new-cycle rules. Next/Previous while paused retain pause state.
- **Shuffle toggling (Q14):** Never restart or seek the currently playing track. Preserve its position and playback history. Reorder **only unvisited remaining tracks**: randomize when enabling shuffle and restore the [agreed folder/path/natural-filename order](#v01-collection-queue-and-recovery-behavior) for unvisited tracks when disabling it. Do not rewrite previous history or requeue already visited tracks except via explicit user action or a new repeat cycle.
- **Previous / Next and pause (Q15):** At **three seconds or later** in the current track, Previous restarts that track. Before three seconds, it navigates to the previous track in playback history; if there is no previous track, it restarts the current one. **Next/Previous while paused leaves playback paused** after the seek/track change. The same behavior applies to on-screen, lock-screen, and supported headset/Bluetooth remote commands.
- **Explicit track tap (Q16):** Tapping a track in a **settled** collection is an explicit request to play and replaces the current queue. In ordinary order, start at that track's position in the ordered collection; when shuffle is active, play the chosen track first and shuffle the other tracks behind it. **Play All** starts at the collection's beginning. Merely selecting a root or scanning is **not** a Play action.
- **Discover, do not pre-validate (Q17):** Show **discovered tracks** without claiming all are playable. Validate audio only at playback time; mark corrupt/unsupported MP3s unavailable and skip under the [failure policy](#v01-collection-queue-and-recovery-behavior). Do not fetch/download every audio file to complete a folder scan.
- **Bounded work and foreground-only scanning (Q18–Q19):** Observe the canonical [scan boundary](#v01-recursive-scan-boundary-and-limits). Request-count, wall-time and retry budgets require measured numeric values from the feasibility spike before declaring the scanner complete. Permit **one scan at a time**; if OpenMP3 leaves the foreground, stop that scan as **Incomplete scan**, preserve discovered tracks, and leave existing background music uninterrupted.
- **Single-screen hierarchy (Q20):** A compact original **dark retro player panel** stays at the top with track/title, elapsed time, seek, transport, shuffle/repeat and the **queue source** (currently playing root) clearly displayed. Below it, show the separately labeled **selected root** (which may differ), its scan status and tracks **grouped by folder**. Open **saved-root management** and **active queue** in separate sheets. All controls need touch-friendly sizes, scalable text and VoiceOver. Decorative EQ/spectrum visualizers are omitted from v0.1.

**Acceptance tests:** Repeat-mode end/cycle boundaries including single-item queues, shuffle toggle mid-track, Previous on either side of the threshold, paused remote Next/Previous, track-tap vs root-selection behavior, on-demand corrupt-file skip, large non-audio-heavy scans and foreground transitions, and a UI where *queue source A* is distinguishable from *selected root B*.

## 1. The idea in one sentence

**OpenMP3** is a native iPhone music player with a classic Winamp-inspired look: paste a public Google Drive folder URL, discover MP3s **recursively across its subfolders**, then play the entire collection in folder mode or build custom playlists. No Google sign-in; avoid an API key if a reliable no-key approach proves feasible.

## 2. Problem and opportunity

A public Drive folder is easy to share, but it is not a convenient music playlist on an iPhone. Existing solutions may require a Google account connection, a paid upgrade, or a browser-based player. We want a frictionless, native experience: **paste link → see songs → press Play**.

## 3. Product principles

1. **Link-first:** The public folder URL is the primary input.
2. **No account required:** No Google OAuth, no app account, no sign-up for the initial version.
3. **No API key in v0.1:** Use anonymous public-link access only. A developer-configured API key is **not allowed** in this version; if it fails, stop and report rather than silently introducing another access path. Neither public-folder listing nor media streaming is assumed to work until tested. No listener OAuth or account.
4. **Explicit listening transitions:** Scanning a saved root never starts or replaces playback; see [collection, queue and recovery behavior](#v01-collection-queue-and-recovery-behavior).
5. **Native iPhone experience:** SwiftUI interface, background audio, lock-screen controls, and compatibility with the [platform compatibility baseline](#platform-compatibility-baseline-single-source-of-truth).
6. **Nostalgic but usable:** Capture the compact, tactile, classic Winamp 2.x feel while meeting modern iPhone touch, accessibility, and background-audio needs; do not reuse Winamp logos, copyrighted skin assets, or trademarks as app branding.
7. **Folder-first listening:** One pasted root folder can act as a complete library, including nested folders; custom playlists add curation without requiring reorganization in Drive.
8. **Technical proof before UI build:** Prove one track and recursive discovery before investing in the full player.
9. **Transparent failure:** Explain inaccessible folders, unsupported files, and playback failures rather than silently failing.
10. **Free core player:** Preserve free folder playback, shuffle, and background audio even if optional premium features are later offered (see [monetization proposal](#monetization-proposal-single-source-of-truth-for-commercial-terms)).

## 4. User experience — agreed direction, design still exploratory

**Core job to be done:** “I have MP3s in a public Google Drive folder tree. Let me listen to all of them on my iPhone, with the feel and controls of a classic desktop music player, without moving files or signing into Google.”

### The two listening modes

1. **Folder mode (default):** Paste or choose among saved public root folders. Scan the selected root and its actual descendant folders. Once the scan settles, users can explicitly Play all or Shuffle all discovered MP3s; scanning another root does **not** replace the existing queue. See [collection, queue and recovery behavior](#v01-collection-queue-and-recovery-behavior).
2. **Playlist mode:** Create a named playlist in the app; add individual tracks found in saved folders, remove/reorder them, and play or shuffle that selection. A playlist is a locally stored set of references, **not** a new Drive folder or an upload. A future paid unlock for playlist creation is proposed in the [monetization section](#monetization-proposal-single-source-of-truth-for-commercial-terms); the prototype may demonstrate playlists without live billing.

### First-run journey

1. Open OpenMP3; see a Winamp-inspired player.
2. Paste an **Anyone with the link → Viewer** Google Drive root-folder URL.
3. Tap **Load**. See scanning progress, playable track count, and clear errors for inaccessible subfolders/files.
4. After the scan settles (complete or incomplete), browse discovered tracks with folder paths for disambiguating duplicate filenames, then explicitly **Play all** or **Shuffle all**. Load itself never autoplays.
5. Optionally create a named playlist, add tracks, rearrange them, and save it.
6. Continue playback with the screen locked or OpenMP3 backgrounded, including while Google Maps is foregrounded for navigation; expose lock-screen and supported remote/headphone controls.

### Visual direction — classic Winamp-inspired, not a literal skin copy

- Compact, dense, retro audio-player aesthetic reminiscent of late-1990s / early-2000s Winamp: dark metallic panels, high-contrast displays, distinctive transport buttons, a timeline, track/time readouts, playlist/queue pane, and an optional animated spectrum visualization.
- Preserve the personality on iPhone, but use touch-friendly targets, scalable text, VoiceOver labels, and responsive layouts.
- **Design exploration, not finalized specifications:** Exact colors, panel placement, equalizer interaction, animations, and whether users can switch between compact/expanded views.
- Avoid copying Winamp's name, logo, original skin graphics, or other proprietary assets.

```text
┌──────────────────────────────────┐
│ OpenMP3 • RETRO PLAYER           │
│ 01:24  ▮▮▮▯▮▮▯  TRACK NAME        │
│ [◀◀] [▶/Ⅱ] [■] [▶▶]  ━━━━━●━━━  │
│ [Shuffle] [Repeat] [Queue]        │
├──────────────────────────────────┤
│ [Folder ▼] [Playlist ▼]          │
│ My Drive collection • 128 tracks* │
│  ♪ song.mp3     /Album A        │
│  ♪ song2.mp3    /Live/1999      │
│  [+ Add to playlist]            │
└──────────────────────────────────┘
* Illustrative placeholder count, not a verified result.
```

## 5. Requirements, prioritization, and release plan

**PM convention:** Record each requirement with an ID, user outcome, priority, and observable acceptance criterion. Distinguish **user-confirmed requirements** from **proposed details** and **technical assumptions**. Dates and estimates are deliberately not invented.

### Requirement register

| ID | Requirement | Priority | Status | Acceptance / observable behavior |
| --- | --- | --- | --- | --- |
| R-01 | Accept a public Google Drive folder URL without Google sign-in | Core | Confirmed | The listener pastes a public root URL and can attempt to load it without OAuth |
| R-02 | **Discover MP3s recursively** in the root and accessible **actual descendant folders** | Core / P0 | Confirmed | A three-level test tree lists each eligible MP3 once, including deep descendants; non-audio files and shortcuts are excluded, and skipped shortcuts reported. Respect the [scan boundary and limits](#v01-recursive-scan-boundary-and-limits) |
| R-03 | **Folder mode**: play one loaded folder tree at a time | Core / P0 | Confirmed | After scan settles, explicit Play All replaces the active queue and advances through discovered tracks. Merely selecting or scanning a different root does not interrupt current audio; see [queue and recovery behavior](#v01-collection-queue-and-recovery-behavior) |
| R-04 | Queue order, shuffle and repeat for folder collection; future playlists | Core / P0 for folder mode; playlist shuffle stretch | Confirmed | Deterministic default order, current-track-safe shuffle toggles, repeat off/all/one and boundary handling as defined in [playback controls and screen behavior](#v01-playback-controls-and-screen-behavior) |
| R-05 | Create and manage **custom in-app playlists** | Stretch for v0.1; future planned capability | User goal confirmed; **not a v0.1 completion gate** | When built, users can name, save, add/remove tracks, reorder and play playlists; they persist after app restart |
| R-06 | **Classic Winamp-inspired** UI | Core / P0 | Confirmed direction | Original dark player panel with **queue source** distinct from selected browsing root, scan status and folder-grouped tracks; separate sheets for saved roots and queue; accessible touch targets; see [playback controls and screen behavior](#v01-playback-controls-and-screen-behavior) |
| R-07 | Music-player transport: play/pause, next/previous, seek, volume where supported, repeat off/all/one | Core / P0 | Confirmed behavior | Repeat, Previous threshold, pause state, track taps and basic lock-screen/headset/Bluetooth commands follow [playback controls and screen behavior](#v01-playback-controls-and-screen-behavior); artwork/richer metadata is optional |
| R-08 | **Keep music playing while another app is foregrounded, especially Google Maps navigation**; also support locked-screen audio and headset/Bluetooth controls | Core / P0 | **Confirmed** | Start playback, switch to Google Maps and use navigation; current and next tracks play, and lock-screen plus supported headset/Bluetooth play/pause and next/previous work. Handle interruptions with system-appropriate duck/pause/resume behavior. Verify on physical hardware |
| R-09 | Persist saved public root links and the last selected root; playlist storage is stretch | Core / P0 for roots | Confirmed | Multiple links and the last selected root remain after relaunch. After termination, a fresh scan and explicit Play are required; previous queue, position and shuffle history need not be restored. See [relaunch policy](#v01-collection-queue-and-recovery-behavior) |
| R-10 | Differentiate unavailable tracks, temporary network/quota interruptions, scan failures and Drive limits | Core / P0 | Confirmed | Missing tracks are skipped; temporary failures get bounded retries then pause with Retry and best-effort preserved position; incomplete scans are labeled. Never loop infinitely. See [recovery behavior](#v01-collection-queue-and-recovery-behavior) |
| R-11 | More advanced music-player capabilities | Later / explore | User goal, feature list unconfirmed | Evaluate equalizer, gapless/crossfade, ID3/artwork, search/sort, sleep timer, queue editing, offline cache, AirPlay and CarPlay; prioritize individually before development |
| R-12 | **Support legacy iPhones according to the single compatibility baseline** | Core / P0 | **Confirmed** | Deployment target and APIs match the [platform compatibility baseline](#platform-compatibility-baseline-single-source-of-truth); run the full P0 flow on reference hardware when available, or explicitly mark device coverage unverified |
| R-13 | **Free player plus optional paid upgrade** | Product direction confirmed; pricing / entitlement proposed | Discovery; live IAP post-prototype | Free users retain recursive playback, shuffle, and navigation background audio. A proposed one-time unlock enables unlimited named custom playlists. For price, purchase type, and implementation boundaries see [monetization proposal](#monetization-proposal-single-source-of-truth-for-commercial-terms). |
| R-14 | **Bounded recursive foreground-only scans with transparent incomplete results** | Core / P0 | Confirmed, additional numerical budgets pending spike evidence | Respect [canonical scan limits](#v01-recursive-scan-boundary-and-limits), including evidence-driven request/time/retry budgets; one foreground scan, ending incomplete on background transition; retain discovered tracks in a settled collection |
| R-15 | Multiple saved public roots, one active collection | Core / P0 | Confirmed | Save/choose roots independently of playback; cached settled browse results persist until Rescan/termination; deleting a saved root doesn't change its active queue/source; see [collection policy](#v01-collection-queue-and-recovery-behavior) |
| R-16 | Cellular streaming and safe audio interruption handling | Core / P0 | Confirmed | Cellular works with a data-use notice; navigation prompts may duck or interrupt but only resume when appropriate, while user pause/disconnection remains paused; see [recovery policy](#v01-collection-queue-and-recovery-behavior) |
| R-17 | **Lazy validation of discovered MP3s** | Core / P0 | Confirmed | Scans display discovered MP3 entries without pre-downloading/decoding every file; corrupt/unsupported files are handled at playback time under [failure rules](#v01-collection-queue-and-recovery-behavior) |
| R-18 | **Explicit track tapping and source distinction** | Core / P0 | Confirmed | A track tap in a settled collection starts the specified queue; selecting, rescanning or deleting roots alone does not. The player displays queue source separately from selected browsing root, per [playback controls and screen behavior](#v01-playback-controls-and-screen-behavior) |
| R-19 | **Folder failure isolation and non-playable empty roots** | Core / P0 | Confirmed | Continue scanning accessible siblings after descendant errors and label incomplete; distinguish successful empty results from root-wide failures; disable Play with zero discoveries. See [collection/recovery policy](#v01-collection-queue-and-recovery-behavior) |

**Core = desired initial product experience**, not a claim that every item has already been proven achievable through anonymous no-key access. For development, validate the technology first; then sequence implementation.

### Acceptance scenarios for the hardest features

- **Recursive listing:** Fixture includes root, nested A, A/B, and A/B/C; MP3s at multiple depths; ignored TXT/JPG and shortcuts; duplicate filenames in different folders. Scan actual accessible descendants, handle pagination, preserve distinguishable paths, and report partial failures. Apply the [scan boundary and limits](#v01-recursive-scan-boundary-and-limits), including measured work budgets and foreground cancellation, with explicit incomplete indicators and discovered tracks available for playback attempts (not guaranteed playable).
- **Shuffle / repeat / controls:** In the active queue, test repeat Off/All/One including shuffled boundary reshuffling, **manual Next at the final track under each repeat mode**, and **Play after natural exhaustion** restarting that same active queue while a different or removed root is browsed; shuffle toggles must preserve current track/position/history, Previous threshold and paused Next/Previous apply on-screen and remotely. Follow [playback controls and screen behavior](#v01-playback-controls-and-screen-behavior).
- **Custom playlist:** Build and save a playlist from a loaded folder; reorder it; relaunch the app; play it again. Store stable file/folder identifiers rather than assuming an expiring download URL is permanent; gracefully handle files later removed or made private.
- **Retro interface:** Check readability, button hit areas, VoiceOver, large text, and iPhone layouts. Player **queue source** must remain visible while a different **selected root** is browsed, including after the saved queue source has been deleted. Follow [playback controls and screen behavior](#v01-playback-controls-and-screen-behavior); no decorative equalizer/visualizer controls in v0.1.
- **Collection reuse and failures:** Revisit a settled root without network rescanning, then Rescan to replace old browse results even if incomplete while audio continues. Remove a selected saved root and confirm its queue source label/music remains but browsing becomes unselected. Simulate one inaccessible descendant (continue siblings/incomplete), a fully readable empty root (successful, no Play), root-load failure and scan-wide quota/network exhaustion. Follow [collection/recovery policy](#v01-collection-queue-and-recovery-behavior).
- **Google Maps / background playback (R-08):** On a physical iPhone, begin streaming a multi-track queue in OpenMP3, switch to Google Maps, start a navigation route while stationary or as a passenger, and verify music continues with Maps foregrounded. Check spoken-direction ducking or interruptions, resumption **only if previously playing**, auto-advance to the next MP3, **play/pause and next/previous via lock-screen and supported headset/Bluetooth remotes**, no autoplay after headset reconnection or deliberate pause, and returning to OpenMP3 without losing place. Rich artwork/metadata is optional. Treat third-party navigation prompt behavior as dependent on the actual iOS audio session/route; see [interruption policy](#v01-collection-queue-and-recovery-behavior).
- **Legacy compatibility (R-12):** Build with the deployment target from the [platform compatibility baseline](#platform-compatibility-baseline-single-source-of-truth); run install/launch, folder loading, background-navigation playback, shuffle, and remote controls on the reference hardware, or explicitly record which checks could not be run.
- **Free and premium boundary (R-13):** Simulate free vs. unlocked states without collecting payment during the prototype. Free users must be able to play all recursively discovered MP3s and use background audio and shuffle. If a real premium purchase is later implemented, users can purchase once, create/reorder/persist multiple playlists, and restore entitlement without paying twice. Use the [monetization proposal](#monetization-proposal-single-source-of-truth-for-commercial-terms) as the sole source for tentative pricing.

### Suggested release sequence — validate before committing

| Stage | Outcome | Scope |
| --- | --- | --- |
| **0 — Feasibility spike** | Confirm a trustworthy way to list public folder trees and stream MP3 audio | Start with one public track, then recursively enumerate nested folders, stream/seek, and record no-key limitations |
| **1 — Core player** | A genuinely useful iPhone music player | Retro-inspired UI, recursive folder mode, play controls, shuffle/repeat, persistence, **background playback during navigation (P0)**, legacy compatibility per the [platform compatibility baseline](#platform-compatibility-baseline-single-source-of-truth); custom playlists if feasible |
| **2 — Power-user polish / optional distribution** | A more advanced player | Prioritize equalizer, visualizer, metadata/artwork, search/sort, gapless/crossfade, queue management, offline options, and (only when pursuing App Store release) the StoreKit upgrade described in [monetization proposal](#monetization-proposal-single-source-of-truth-for-commercial-terms) |

### Product success measures (targets to set after prototyping)

- **Time to first music:** From pasting a valid public folder URL to audible playback.
- **Discovery completeness:** Expected MP3s found divided by eligible MP3s in the test folder tree, with partial failures disclosed.
- **Playback reliability:** Track-start success, skip success, and uninterrupted listening across background/lock states.
- **Playlist usability:** Can someone create, save, reopen, and play a playlist without instructions?
- **Retro design usability:** Users recognize the nostalgic look *and* can operate all essential controls comfortably.

### Scope boundaries

- Initial product: public Google Drive links, MP3 playback, on-device playlists, iPhone.
- Do not silently assume private Google Drive access, subscriptions, backend hosting, social features, or uploading/modifying Drive files.
- No bypassing Google authentication, access controls, download restrictions, or usage limits.
- **No API key is a fixed v0.1 product constraint**, not merely a preference. Technical reliability still requires evidence; if no-key access cannot support the promised experience, stop and revisit v0.1 scope instead of implementing a key fallback.
- Advanced player functions are **candidate features**, not automatically all in the first release.
- App Store billing is not a prerequisite to the v0.1 experiment; the intended future free/paid split is tracked in the [monetization proposal](#monetization-proposal-single-source-of-truth-for-commercial-terms).

## 6. Technical direction — hypotheses, not yet validated

**Target stack:** Swift, SwiftUI, AVFoundation/AVPlayer, AVAudioSession, MPNowPlayingInfoCenter, MPRemoteCommandCenter. Store saved folder links locally (e.g., UserDefaults initially). Follow the [platform compatibility baseline](#platform-compatibility-baseline-single-source-of-truth) for the deployment target and API/dependency availability. For background playback, enable the **Audio** background mode (`UIBackgroundModes` includes `audio`), use an `AVAudioSession` playback category, and retain the active player/queue when the app becomes inactive. Handle audio-session interruptions and route changes, including navigation announcements; do not rely on a foreground-only UI lifecycle.

### Option A — Public-link-only, no API key (only permitted v0.1 access path)

- Parse the folder ID and any resource-key information from the shared URL.
- Request the public folder page, then investigate whether a maintainable method exists to extract the files and their identifiers.
- Traverse the root folder plus nested child folders, handling pagination, duplicate filenames and partial failures; test the public-webpage approach at multiple depths before promising recursive completeness.
- Resolve an audio URL usable by the player and test actual streaming, seeking, and next-track playback on a physical iPhone.

**Risks:** Google Drive's human-facing page is not a documented folder-listing API; markup/scripts can change. Direct file/download links may redirect, expire, require cookies, block streaming or byte-range requests, or encounter quota/download restrictions. A browser-visible folder does **not** guarantee that a native app can list and stream every file anonymously.

### Option B — Official Google Drive API with key (deferred; not permitted in v0.1)

- Use the supported Drive API to list publicly accessible folder contents **recursively** (one folder level at a time, with pagination), with an appropriately restricted application API key if the endpoints and access mode permit it.
- Separately verify file-content retrieval and the behavior of resource keys, quotas, download restrictions, and audio seeking.

**Future-only note:** This is a research option for a later version only after explicit user approval; **do not implement, configure, or use a developer API key in v0.1**. An API key identifies the calling project but does not grant private-file permissions, and an embedded iOS key is not a secret.

### Option C — User-authorized Google Drive access (later only)

- OAuth may be needed for private folders or some otherwise inaccessible files.
- Outside the initial product promise; reconsider only if requirements change.

**Architecture decision pending:** We should only select an architecture after testing an actual public folder. Avoid building the full interface around an unverified extraction strategy.

## 7. First technical experiment — highest priority

**Goal:** Prove or disprove the defining user journey before building the rest of the app.

**Test setup:** A Google Drive root folder containing at least three MP3 files distributed across the root and **at least two nested folder levels**, shared as **Anyone with the link → Viewer**. Use test files you have the right to access. Test on a physical iPhone and, where useful, with a simple network prototype.

**Acceptance criteria:**

- [ ] Paste the URL without Google login **and without any API key**, even one configured by the developer. If no-key access is blocked, record evidence and stop for a product decision.
- [ ] List eligible MP3 filenames **recursively across actual descendant folders**, retaining relative paths, skipping/reporting shortcuts, and respecting the [scan boundary and limits](#v01-recursive-scan-boundary-and-limits). Report any inaccessible folders or incomplete traversal.
- [ ] Play the first track audibly on iPhone.
- [ ] Seek within the track and play the next track.
- [ ] Verify playback with the app backgrounded and phone locked, including **Google Maps foreground navigation** with spoken directions; confirm audio/queue continuity, basic play/pause and next/previous via lock-screen and supported headset/Bluetooth remotes, and appropriate interruption recovery.
- [ ] Check the app against the [platform compatibility baseline](#platform-compatibility-baseline-single-source-of-truth); verify on the reference physical device where possible and record any untested compatibility claims.
- [ ] Repeat after app restart and on a different network.
- [ ] Record exact failure causes if any step is blocked.

**Negative tests:** Invalid URL, private/restricted folder, empty folder, unsupported format, broken link, unavailable network, Drive rate limit, and large file.

**Decision gate:**

- **Pass:** Continue with no-key native MVP.
- **Partial pass:** Identify what is blocked (listing vs. retrieving vs. streaming), measure the limitations and retry within the approved no-key experiment. Do **not** introduce an API key; leave the gate open if required evidence remains missing.
- **Fail:** If the no-key approach cannot reliably support the product without login or a backend, **stop** and revisit the product promise. Do **not** add an API key or assume an undocumented workaround will remain reliable.

## 8. Privacy, reliability, and distribution

- Only load folders deliberately supplied by the user. A public shared link can still expose content to anyone who possesses it.
- Store links locally; avoid logging full folder URLs or forwarding them to third-party services.
- Handle link-based resource keys if present; do not treat them as authentication for private content.
- Respect copyright, users' access permissions, Google Drive service terms, and rate/download limits.
- Use standard iOS background audio capabilities; Google Maps navigation in the foreground is a **required** test scenario, not a future enhancement. Test actual interruptions and background transitions instead of assuming they work. Follow the [platform compatibility baseline](#platform-compatibility-baseline-single-source-of-truth) for supported platforms.
- If considering App Store release, assess reliability and current App Review requirements before submission.

## 9. Open questions for our brainstorm

| ID | Question | Initial assumption / status |
| --- | --- | --- |
| Q1 | Is this strictly for personal use, or a public App Store product? | **Open**; prototype for personal use first |
| Q2 | Must the app work with *zero* API keys, or is that only a preference? | **Updated 2026-11-15:** v0.1 requires **zero API keys**, including developer keys. If the no-key approach fails, pause for a product decision. Supersedes earlier fallback approval |
| Q3 | Are all audio files directly in one folder, or are subfolders important? | **Resolved:** Recursive discovery is a core user requirement |
| Q4 | MP3 only, or also M4A, AAC, FLAC, WAV? | **MP3 first** |
| Q5 | Should songs play in filename order, folder order, or shuffled order by default? | **Resolved:** root tracks first, relative folder paths then natural numeric filename; shuffle explicit (see [collection rules](#v01-collection-queue-and-recovery-behavior)) |
| Q6 | Is cellular streaming acceptable? | **Resolved:** yes, enabled with data-use notice; Wi-Fi-only option later (see [recovery rules](#v01-collection-queue-and-recovery-behavior)) |
| Q7 | Is downloading/offline listening essential? | **No**, defer |
| Q8 | What should we call the app? | **Open** |
| Q9 | What happens if anonymous folder listing cannot be supported reliably? | **Open**; run experiment first |
| Q10 | Which specific advanced functions must ship first (equalizer, gapless, crossfade, search, visualizer, etc.)? | **Open**; do not assume all are MVP |
| Q11 | Should recursive scans follow Drive shortcuts, and what should happen in huge trees? | **Resolved:** Skip shortcuts, enforce the [scan boundary and limits](#v01-recursive-scan-boundary-and-limits) and report incomplete scans |
| Q12 | Should shuffle avoid repeats until every track has played, and should it remember state? | **Proposed** behavior in R-04; confirm in testing |
| Q13 | What degree of Winamp likeness is desired (classic fixed-size panels versus a touch-adapted homage)? | **Open**; create visual mockups before coding |
| Q14 | Should the premium unlock specifically be unlimited playlists, and should there be a free playlist allowance? | **Open**; one-time playlist unlock is proposed, not finalized |
| Q15 | Does v0.1 require saving and restoring custom playlists? | **Resolved:** No. Custom playlists are stretch scope, not a weekend release gate |
| Q16 | Should lock-screen and supported headset/Bluetooth basic remote commands be P0? | **Resolved:** Yes; play/pause and next/previous required. Artwork and rich metadata optional |
| Q17 | How should multiple saved roots, scan completion, relaunch, and temporary playback failures behave? | **Resolved by grilling Q6–Q12**; see [canonical collection, queue and recovery behavior](#v01-collection-queue-and-recovery-behavior) |
| Q18 | How should repeat, shuffle toggles, Previous, track taps, discovered-track validation and the main screen behave? | **Resolved by grilling Q13–Q20**; see [playback controls and screen behavior](#v01-playback-controls-and-screen-behavior) |
| Q19 | What numerical listing-request, scan-time and retry budgets should v0.1 use? | **Pending feasibility measurements**; specific values must be recorded in [canonical scan limits](#v01-recursive-scan-boundary-and-limits) before scan implementation acceptance |
| Q20 | How are settled collection reuse, saved-root removal, descendant failures and queue exhaustion handled? | **Resolved by grilling Q21–Q24**; see [collection/recovery policy](#v01-collection-queue-and-recovery-behavior) and [playback control policy](#v01-playback-controls-and-screen-behavior) |

## 10. Decisions log

| Date | ID | Decision | Rationale / confidence |
| --- | --- | --- | --- |
| 2026-11-14 | D-001 | Target a native iPhone app | User wants an iPhone app |
| 2026-11-14 | D-002 | Input is a public Google Drive folder URL | Core user experience |
| 2026-11-14 | D-003 | Do not require listener Google sign-in in the MVP | Core user preference |
| 2026-11-14 | D-004 | Test a no-API-key approach **before** committing to it | Unverified technical feasibility |
| 2026-11-14 | D-005 | Build with Codex; validate a single folder/track first | Keep scope small |
| 2026-11-14 | D-006 | Adopt a classic Winamp-inspired visual direction | Explicit user requirement; protect usability and avoid copying proprietary assets |
| 2026-11-14 | D-007 | Recursive playback of the root **and all nested folders** is a core requirement | Explicit user requirement; supersedes v0.1 subfolders-as-later assumption |
| 2026-11-14 | D-008 | Support both folder mode and saved in-app custom playlists, with shuffle | Explicit user requirement |
| 2026-11-14 | D-009 | Keep advanced features in a prioritized discovery backlog until specified | User wants a capable player; exact advanced set is not yet defined |
| 2026-11-14 | D-010 | Require music to keep playing when Google Maps navigation is in the foreground | Explicit user requirement; prioritize background audio in P0 |
| 2026-11-14 | D-011 | Centralize all explicit platform/device versions in one [platform compatibility baseline](#platform-compatibility-baseline-single-source-of-truth) | Explicit user preference; avoid documentation drift and simplify future changes |
| 2026-11-14 | D-012 | Keep core OpenMP3 free; consider a small, one-time IAP for custom playlists | User requested free app with an optional low-cost purchase; exact paid feature/price remain tentative (see [monetization proposal](#monetization-proposal-single-source-of-truth-for-commercial-terms)) |
| 2026-11-14 | D-013 | Developer-restricted Drive API key was originally an accepted fallback | **Superseded for v0.1 by D-037 (2026-11-15)**; retained as historical decision only |
| 2026-11-14 | D-014 | Custom playlists are optional stretch for the v0.1 weekend release | Remove conflict between P1 and mandatory acceptance, prioritize a playable end-to-end app |
| 2026-11-14 | D-015 | Make basic lock-screen/headset/Bluetooth play/pause and next/previous P0 | These are core listening controls; richer metadata/artwork remain stretch |
| 2026-11-14 | D-016 | Skip Drive shortcuts when discovering a root folder's actual descendants | Predictable traversal scope; transparently report skipped shortcuts |
| 2026-11-14 | D-017 | Limit v0.1 scan size and make partial results playable | Weekend stability; full thresholds and truncation behavior are centralized in the [scan boundary and limits](#v01-recursive-scan-boundary-and-limits) |
| 2026-11-14 | D-018 | Save multiple roots; only explicit Play changes the active queue | No interruptions from selection or scanning; no merged roots |
| 2026-11-14 | D-019 | Require settled scans before starting the new collection | Stable queue, predictable sorting/shuffle; allow incomplete results on Stop/error/limit |
| 2026-11-14 | D-020 | Use folder-aware natural numeric order for non-shuffle playback | Keep albums grouped; see [canonical queue policy](#v01-collection-queue-and-recovery-behavior) |
| 2026-11-14 | D-021 | Restore roots/selection, not last playback queue/position after termination | Keep cold-launch behavior minimal; do not relax background audio |
| 2026-11-14 | D-022 | Allow cellular with data-use notice, no autoplay on folder load | Supports navigation listening; no Wi-Fi-only control yet |
| 2026-11-14 | D-023 | Skip definitively unavailable files; retry and pause on temporary network/quota failures | Preserve place, expose Retry, avoid infinite loops |
| 2026-11-14 | D-024 | Resume from navigation interruptions only when previously playing; no resume on user pause/disconnect | Respect user intent and iOS audio behavior |
| 2026-11-14 | D-025 | Define Repeat Off/All/One, reshuffle cycles, and manual Next behavior | Deterministic queue end and repeat behavior; [playback controls and screen behavior](#v01-playback-controls-and-screen-behavior) |
| 2026-11-14 | D-026 | Shuffle toggles preserve current track, position, history | Only unvisited remainder is reordered; [playback controls and screen behavior](#v01-playback-controls-and-screen-behavior) |
| 2026-11-14 | D-027 | Standardize Previous threshold and paused transport controls | Same semantics on-screen and remotes; [playback controls and screen behavior](#v01-playback-controls-and-screen-behavior) |
| 2026-11-14 | D-028 | Tapping a track explicitly plays from a settled collection | Distinct from root selection/scan; [playback controls and screen behavior](#v01-playback-controls-and-screen-behavior) |
| 2026-11-14 | D-029 | Show discovered MP3s without bulk validation | Verify playback lazily; report unsupported/corrupt entries only when attempted |
| 2026-11-14 | D-030 | Bound scan requests, elapsed time and retries | Pick numerical budgets from feasibility evidence in [single scan-limits section](#v01-recursive-scan-boundary-and-limits) |
| 2026-11-14 | D-031 | One foreground-only scan; backgrounding ends scan incomplete | Playback in background continues independently; do not crawl while backgrounded |
| 2026-11-14 | D-032 | One retro main screen distinguishes queue source and selected root | Accessible playback/browsing separation; omit cosmetic EQ and visualizers |
| 2026-11-15 | D-033 | Reuse settled browsing results until explicit Rescan or termination | Rescan replaces, never merges, even incomplete results; active queue independent |
| 2026-11-15 | D-034 | Remove saved root without stopping its playing queue | Preserve source label, clear selected/browse state; never modify Drive content |
| 2026-11-15 | D-035 | Continue accessible siblings after descendant failure; distinguish successful empty root and scan-wide failure | Mark partial incomplete; disable Play for zero discoveries |
| 2026-11-15 | D-036 | Manual Next at final track cycles only under Repeat All; Play after exhaustion restarts existing queue | Respect repeat/shuffle and queue source despite different/removed browsing root |
| 2026-11-15 | D-037 | Require no Google Drive API key in OpenMP3 v0.1; no automatic key fallback | Explicit owner decision after T01 no-key prototype progress; if anonymous access fails, document blockers and seek a new product decision |

## 11. Parking lot — ideas to revisit

- Optional import/export and sharing of custom playlists.
- Playlist sharing using only a public folder URL.
- Simple album artwork from folder image files.
- Gapless playback / crossfade.
- Playback speed for spoken-word MP3s.
- Widgets, Siri Shortcuts, and Share Sheet integration.
- Import links from QR codes.

## 12. Codex kickoff task (copy/paste)

> Build a minimal native SwiftUI iPhone proof of concept for OpenMP3. Start with the feasibility spike in Section 7, **not** the complete Winamp-inspired interface. Accept a Google Drive root-folder URL shared as “Anyone with the link → Viewer.” First attempt to list and stream one MP3 with **no Google sign-in and no Google Drive API key**; then attempt recursive discovery through at least two nested subfolder levels. Record exact results for access, pagination, scanning, streaming, seeking, and **background playback while Google Maps navigation is in the foreground**. Follow the [platform compatibility baseline](#platform-compatibility-baseline-single-source-of-truth) for the minimum OS and legacy validation device; do not repeat or change those values in implementation tickets. Do not use brittle webpage scraping without documenting its fragility or bypass Google access restrictions. If no-key discovery proves unreliable, document the failure and stop for a product decision; **do not introduce an API key or backend in v0.1**. Use AVPlayer where viable; test on a physical iPhone when available, recording unverified checks honestly. After the feasibility decision, implement the prioritized requirements R-01 through R-10 and R-12 in small tested increments.

## 13. Next actions

1. Supply a non-sensitive public Drive **root folder with MP3s at multiple nesting levels** for testing.
2. Run the no-key proof of concept in Codex.
3. Record results here under **Experiment log**.
4. Decide whether to proceed with Option A or Option B.
5. Confirm the advanced-player backlog and final retro UI direction, then turn requirements R-01–R-10 and R-12 into small Codex/GitHub issues. Keep all issue references to platform versions linked to the [platform compatibility baseline](#platform-compatibility-baseline-single-source-of-truth).

## 14. Experiment log

| Date | Test | Result | Evidence / notes | Follow-up |
| --- | --- | --- | --- | --- |
| — | Public root and nested folder anonymous listing | Not yet tested | — | Codex spike |
| — | Direct MP3 streaming on iPhone | Not yet tested | — | Codex spike |
| — | Seek, next track, background playback | Not yet tested | — | Codex spike |
| — | Google Maps foreground navigation, spoken prompts and queue continuity | Not yet tested | — | Core P0 device test |
| — | Baseline legacy-device installation and playback | Not yet tested | See [platform compatibility baseline](#platform-compatibility-baseline-single-source-of-truth) | Legacy compatibility test |

## 15. Changelog

- **2026-11-15 / v0.11:** Made v0.1 strictly **no Google Drive API key** (developer keys included), superseding the earlier Q1/D-013 key fallback. No-key feasibility gaps remain to be measured; if unworkable, pause and revisit product scope. Updated Issue #1, specification #3 and T01 #4; no media fixture URLs added to public documentation.
- **2026-11-15 / v0.10:** Resolved Codex grilling Q21–Q24: session cache and Rescan replacement, saved-root removal without queue interruption, sibling continuation after descendant failure with empty-root distinction, and manual Next/Play after queue exhaustion. Updated Issue #1 and decisions D-033–D-036.
- **2026-11-14 / v0.9:** Resolved Codex grilling Q13–Q20. Centralized repeat/shuffle/Previous/tap/UI behavior, lazy track validation, bounded scan-work budgets pending evidence, and foreground-only scans; aligned issue #1 and decisions D-025–D-032.
- **2026-11-14 / v0.8:** Resolved Codex grilling Q6–Q12 and centralized root selection, scan gate, default order, cold relaunch, cellular use, playback failure recovery, and navigation interruption policy; updated issue #1, requirements R-03/R-04/R-09/R-10/R-14–R-16 and decisions D-018–D-024.
- **2026-11-14 / v0.7:** Resolved grilling Q3–Q5: basic lock-screen/headset Bluetooth commands are P0; Drive shortcuts are excluded/reported; centralized bounded scan limits with playable incomplete results. Updated R-02/R-07/R-08/R-14 and decisions D-015–D-017.
- **2026-11-14 / v0.6:** Resolved grilling decisions: authorized restricted developer API-key fallback if no-key fails; aligned release gate so saved custom playlists are stretch, not required for v0.1 success. No changes to the single platform baseline or the single monetization proposal.
- **2026-11-14 / v0.5:** Recorded free-to-download direction and tentative one-time paid playlist unlock as R-13 / D-012, with price and commercial rules in a single section. Preserved free recursive folder playback, shuffle and background navigation; deferred real IAP billing until App Store distribution work.
- **2026-11-14 / v0.4:** Made Google Maps foreground navigation/background playback an explicit P0 requirement with a device test. Added R-12 and one canonical [platform compatibility baseline](#platform-compatibility-baseline-single-source-of-truth) for minimum OS and legacy reference device; other sections and Issue #1 link rather than duplicate versions.
- **2026-11-14 / v0.3:** Reframed OpenMP3 **app v0.1** as a weekend experiment, linked GitHub kickoff issue #1, and separated the app release number from the living document revision. Prioritized feasibility and a playable vertical slice before polish.
- **2026-11-14 / v0.2:** Added a PM-style requirements register, user journeys, a Winamp-inspired visual direction, recursive folder playback, folder/playlist modes, shuffle, acceptance criteria, phased roadmap, success measures, risks, and decisions D-006–D-009. Supersedes v0.1's deferred nested-subfolder assumption.
- **2026-11-14 / v0.1:** Initial living brainstorm: concept, scope, user flow, competing technical approaches, feasibility test, questions, and decisions.

---

**Working agreement:** Update this file as ideas evolve. Keep confirmed decisions separate from assumptions, add dated changelog entries, and record experiment results rather than treating speculation as proof.
