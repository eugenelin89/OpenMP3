# Public Google Drive Music Player — Living Brainstorm

> **Status:** OpenMP3 v0.1 weekend prototype kickoff; implementation unverified  
> **Version:** 0.3 (document revision; not the app release version)  
> **App release target:** 0.1 — experimental iPhone weekend prototype  
> **GitHub kickoff issue:** [#1 — OpenMP3 v0.1](https://github.com/eugenelin89/OpenMP3/issues/1)  
> **Created:** 2026-11-14  
> **Last updated:** 2026-11-14  
> **Working title:** Drive Folder Music Player (name TBD)  
> **Purpose:** A living source of truth for brainstorming, technical experiments, decisions, and Codex implementation.

## Weekend prototype kickoff — OpenMP3 app v0.1

- **Single kickoff issue:** [GitHub #1 — OpenMP3 v0.1 weekend prototype](https://github.com/eugenelin89/OpenMP3/issues/1). Use this as the entry point for the installed Matt Pocock/Codex workflow; let that workflow break the work into small implementation tickets.
- **Release goal:** One demonstrably working native iPhone player for public Drive-folder MP3 streaming; no production-grade roadmap, backend, login, or App Store release required.
- **Build order:** First validate anonymous recursive discovery and playback, preferably without an API key. If that is unreliable, document the blocker and evaluate an official API-based fallback. Then deliver the retro player, folder queue and shuffle; add local custom playlists and background/lock-screen support as the core proves stable.
- **Time-boxing principle:** Preserve a playable vertical slice even if stretch features remain unfinished. Clearly distinguish tested behavior from aspirations.
- **Scope authority:** This document remains the detailed ideas/requirements log; issue #1 defines the executable weekend-prototype checklist. The **app release target v0.1** is separate from this document's **revision v0.3**.

## 1. The idea in one sentence

**OpenMP3** is a native iPhone music player with a classic Winamp-inspired look: paste a public Google Drive folder URL, discover MP3s **recursively across its subfolders**, then play the entire collection in folder mode or build custom playlists. No Google sign-in; avoid an API key if a reliable no-key approach proves feasible.

## 2. Problem and opportunity

A public Drive folder is easy to share, but it is not a convenient music playlist on an iPhone. Existing solutions may require a Google account connection, a paid upgrade, or a browser-based player. We want a frictionless, native experience: **paste link → see songs → press Play**.

## 3. Product principles

1. **Link-first:** The public folder URL is the primary input.
2. **No account required:** No Google OAuth, no app account, no sign-up for the initial version.
3. **No API key initially:** Investigate whether public-link discovery and streaming can work without the official Google Drive API. This is a *hypothesis to validate*, not a proven capability.
4. **Native iPhone experience:** SwiftUI interface, background audio, lock-screen controls.
5. **Nostalgic but usable:** Capture the compact, tactile, classic Winamp 2.x feel while meeting modern iPhone touch, accessibility, and background-audio needs; do not reuse Winamp logos, copyrighted skin assets, or trademarks as app branding.
6. **Folder-first listening:** One pasted root folder can act as a complete library, including nested folders; custom playlists add curation without requiring reorganization in Drive.
7. **Technical proof before UI build:** Prove one track and recursive discovery before investing in the full player.
8. **Transparent failure:** Explain inaccessible folders, unsupported files, and playback failures rather than silently failing.

## 4. User experience — agreed direction, design still exploratory

**Core job to be done:** “I have MP3s in a public Google Drive folder tree. Let me listen to all of them on my iPhone, with the feel and controls of a classic desktop music player, without moving files or signing into Google.”

### The two listening modes

1. **Folder mode (default):** Paste or choose a saved *top-level* public folder. Automatically find playable MP3s in that folder **and all nested subfolders**, build a play queue, and let the listener play in order or shuffle. This is the “just give it a folder and play” flow.
2. **Playlist mode:** Create a named playlist in the app; add individual tracks found in saved folders, remove/reorder them, and play or shuffle that selection. A playlist is a locally stored set of references, **not** a new Drive folder or an upload.

### First-run journey

1. Open OpenMP3; see a Winamp-inspired player.
2. Paste an **Anyone with the link → Viewer** Google Drive root-folder URL.
3. Tap **Load**. See scanning progress, playable track count, and clear errors for inaccessible subfolders/files.
4. Browse tracks (with folder paths for disambiguating duplicate filenames), then **Play all** or **Shuffle all**.
5. Optionally create a named playlist, add tracks, rearrange them, and save it.
6. Continue playback with the screen locked, with remote/headphone controls.

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
| R-02 | **Discover MP3s recursively** in the root and every accessible nested subfolder | Core | Confirmed | A test tree with three nesting levels lists each eligible MP3 once, including deep descendants; non-audio files are excluded |
| R-03 | **Folder mode**: play the loaded folder tree as one collection | Core | Confirmed | Play All creates a queue from the recursive collection and automatically advances through it |
| R-04 | Shuffle the folder collection and custom playlists | Core | Confirmed | Shuffle changes track order across the relevant queue; no repeats in a cycle until exhausted unless repeat behavior says otherwise |
| R-05 | Create and manage **custom in-app playlists** | Core | Confirmed | Users can name, save, add/remove tracks, reorder and play playlists; they persist after app restart |
| R-06 | **Classic Winamp-inspired** UI | Core | Confirmed direction | Primary playback screen visibly follows the retro design direction and remains operable with iPhone touch and accessibility controls |
| R-07 | Music-player transport: play/pause, next/previous, seek, volume where supported, repeat off/all/one | Core | Confirmed general capability; details proposed | Controls affect the active queue predictably, including at its beginning/end |
| R-08 | Play in background, on lock screen, and with headset/Bluetooth remote controls | Core | Carried forward | Playback and remote commands function on a physical iPhone when the app is backgrounded or locked |
| R-09 | Remember added folder links and playlist definitions locally | Core | Carried forward | Saved entries remain after relaunch; no app account required |
| R-10 | Explain partial scans, unavailable tracks, network errors, and Drive limits | Core | Proposed quality requirement | Error states identify failed folders/tracks and allow retry without pretending every track loaded |
| R-11 | More advanced music-player capabilities | Later / explore | User goal, feature list unconfirmed | Evaluate equalizer, gapless/crossfade, ID3/artwork, search/sort, sleep timer, queue editing, offline cache, AirPlay and CarPlay; prioritize individually before development |

**Core = desired initial product experience**, not a claim that every item is technically achievable without an API key. For development, validate the technology first; then sequence implementation.

### Acceptance scenarios for the hardest features

- **Recursive listing:** Fixture includes root, nested A, A/B, and A/B/C; MP3s at multiple depths; ignored TXT/JPG; duplicate filenames in different folders. Scan covers all accessible folders, uses pagination where applicable, preserves distinguishable paths, and reports partial failures. Define behavior for Google Drive shortcuts and very large trees before claiming support.
- **Shuffle:** Shuffle operates on whichever queue is active (entire folder tree versus selected playlist); changing modes does not corrupt playlist contents. Repeat One, Repeat All, and shuffle interaction need defined behavior.
- **Custom playlist:** Build and save a playlist from a loaded folder; reorder it; relaunch the app; play it again. Store stable file/folder identifiers rather than assuming an expiring download URL is permanent; gracefully handle files later removed or made private.
- **Retro interface:** Check readability, button hit areas, VoiceOver, large text, and iPhone layouts; nostalgia must not make the player unusable.

### Suggested release sequence — validate before committing

| Stage | Outcome | Scope |
| --- | --- | --- |
| **0 — Feasibility spike** | Confirm a trustworthy way to list public folder trees and stream MP3 audio | Start with one public track, then recursively enumerate nested folders, stream/seek, and record no-key limitations |
| **1 — Core player** | A genuinely useful iPhone music player | Retro-inspired UI, recursive folder mode, play controls, shuffle/repeat, custom playlists, persistence, background playback |
| **2 — Power-user polish** | A more advanced player | Prioritize equalizer, visualizer, metadata/artwork, search/sort, gapless/crossfade, queue management, offline options, and integrations based on testing and feedback |

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
- “No API key” remains a **preferred technical hypothesis**, not an unconditional promise.
- Advanced player functions are **candidate features**, not automatically all in the first release.

## 6. Technical direction — hypotheses, not yet validated

**Target stack:** Swift, SwiftUI, AVFoundation/AVPlayer, AVAudioSession, MPNowPlayingInfoCenter, MPRemoteCommandCenter. Store saved folder links locally (e.g., UserDefaults initially).

### Option A — Public-link-only, no API key (preferred experiment)

- Parse the folder ID and any resource-key information from the shared URL.
- Request the public folder page, then investigate whether a maintainable method exists to extract the files and their identifiers.
- Traverse the root folder plus nested child folders, handling pagination, duplicate filenames and partial failures; test the public-webpage approach at multiple depths before promising recursive completeness.
- Resolve an audio URL usable by the player and test actual streaming, seeking, and next-track playback on a physical iPhone.

**Risks:** Google Drive's human-facing page is not a documented folder-listing API; markup/scripts can change. Direct file/download links may redirect, expire, require cookies, block streaming or byte-range requests, or encounter quota/download restrictions. A browser-visible folder does **not** guarantee that a native app can list and stream every file anonymously.

### Option B — Official Google Drive API (fallback)

- Use the supported Drive API to list publicly accessible folder contents **recursively** (one folder level at a time, with pagination), with an appropriately restricted application API key if the endpoints and access mode permit it.
- Separately verify file-content retrieval and the behavior of resource keys, quotas, download restrictions, and audio seeking.

**Trade-off:** More predictable file metadata discovery, but requires API configuration. An API key identifies the calling project; it does not grant permission to private files. An API key embedded in an iOS app should not be treated as a secret.

### Option C — User-authorized Google Drive access (later only)

- OAuth may be needed for private folders or some otherwise inaccessible files.
- Outside the initial product promise; reconsider only if requirements change.

**Architecture decision pending:** We should only select an architecture after testing an actual public folder. Avoid building the full interface around an unverified extraction strategy.

## 7. First technical experiment — highest priority

**Goal:** Prove or disprove the defining user journey before building the rest of the app.

**Test setup:** A Google Drive root folder containing at least three MP3 files distributed across the root and **at least two nested folder levels**, shared as **Anyone with the link → Viewer**. Use test files you have the right to access. Test on a physical iPhone and, where useful, with a simple network prototype.

**Acceptance criteria:**

- [ ] Paste the URL without Google login or an API key.
- [ ] List all expected MP3 filenames **recursively**, retaining relative folder paths, and report any subfolders that could not be scanned.
- [ ] Play the first track audibly on iPhone.
- [ ] Seek within the track and play the next track.
- [ ] Verify playback with the app backgrounded and phone locked.
- [ ] Repeat after app restart and on a different network.
- [ ] Record exact failure causes if any step is blocked.

**Negative tests:** Invalid URL, private/restricted folder, empty folder, unsupported format, broken link, unavailable network, Drive rate limit, and large file.

**Decision gate:**

- **Pass:** Continue with no-key native MVP.
- **Partial pass:** Identify what is blocked (listing vs. retrieving vs. streaming); consider a minimal fallback.
- **Fail:** Revisit API-backed discovery or revise the product promise. Do **not** assume an undocumented workaround will remain reliable.

## 8. Privacy, reliability, and distribution

- Only load folders deliberately supplied by the user. A public shared link can still expose content to anyone who possesses it.
- Store links locally; avoid logging full folder URLs or forwarding them to third-party services.
- Handle link-based resource keys if present; do not treat them as authentication for private content.
- Respect copyright, users' access permissions, Google Drive service terms, and rate/download limits.
- Use standard iOS background audio capabilities; test actual behavior instead of assuming it.
- If considering App Store release, assess reliability and current App Review requirements before submission.

## 9. Open questions for our brainstorm

| ID | Question | Initial assumption / status |
| --- | --- | --- |
| Q1 | Is this strictly for personal use, or a public App Store product? | **Open**; prototype for personal use first |
| Q2 | Must the app work with *zero* API keys, or is that only a preference? | **Preference:** try zero-key first |
| Q3 | Are all audio files directly in one folder, or are subfolders important? | **Resolved:** Recursive discovery is a core user requirement |
| Q4 | MP3 only, or also M4A, AAC, FLAC, WAV? | **MP3 first** |
| Q5 | Should songs play in filename order, folder order, or shuffled order by default? | **Assume** filename order |
| Q6 | Is cellular streaming acceptable? | **Assume** yes, with user control later |
| Q7 | Is downloading/offline listening essential? | **No**, defer |
| Q8 | What should we call the app? | **Open** |
| Q9 | What happens if anonymous folder listing cannot be supported reliably? | **Open**; run experiment first |
| Q10 | Which specific advanced functions must ship first (equalizer, gapless, crossfade, search, visualizer, etc.)? | **Open**; do not assume all are MVP |
| Q11 | Should recursive scans follow Drive shortcuts, and what should happen in huge trees? | **Open**; define limits/progress/partial-scan behavior |
| Q12 | Should shuffle avoid repeats until every track has played, and should it remember state? | **Proposed** behavior in R-04; confirm in testing |
| Q13 | What degree of Winamp likeness is desired (classic fixed-size panels versus a touch-adapted homage)? | **Open**; create visual mockups before coding |

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

## 11. Parking lot — ideas to revisit

- Optional import/export and sharing of custom playlists.
- Playlist sharing using only a public folder URL.
- Simple album artwork from folder image files.
- Gapless playback / crossfade.
- Playback speed for spoken-word MP3s.
- Widgets, Siri Shortcuts, and Share Sheet integration.
- Import links from QR codes.

## 12. Codex kickoff task (copy/paste)

> Build a minimal native SwiftUI iPhone proof of concept for OpenMP3. Start with the feasibility spike in Section 7, **not** the complete Winamp-inspired interface. Accept a Google Drive root-folder URL shared as “Anyone with the link → Viewer.” First attempt to list and stream one MP3 with **no Google sign-in and no Google Drive API key**; then attempt recursive discovery through at least two nested subfolder levels. Record exact results for access, pagination, scanning, streaming, seeking, and background playback. Do not use brittle webpage scraping without documenting its fragility or bypass Google access restrictions. If no-key discovery is not viable, propose a minimal supported API fallback before implementing it. Use AVPlayer where viable; test on a physical iPhone when available. After the feasibility decision, implement the prioritized requirements R-01 through R-10 in small tested increments.

## 13. Next actions

1. Supply a non-sensitive public Drive **root folder with MP3s at multiple nesting levels** for testing.
2. Run the no-key proof of concept in Codex.
3. Record results here under **Experiment log**.
4. Decide whether to proceed with Option A or Option B.
5. Confirm the advanced-player backlog and final retro UI direction, then turn requirements R-01–R-10 into small Codex/GitHub issues.

## 14. Experiment log

| Date | Test | Result | Evidence / notes | Follow-up |
| --- | --- | --- | --- | --- |
| — | Public root and nested folder anonymous listing | Not yet tested | — | Codex spike |
| — | Direct MP3 streaming on iPhone | Not yet tested | — | Codex spike |
| — | Seek, next track, background playback | Not yet tested | — | Codex spike |

## 15. Changelog

- **2026-11-14 / v0.3:** Reframed OpenMP3 **app v0.1** as a weekend experiment, linked GitHub kickoff issue #1, and separated the app release number from the living document revision. Prioritized feasibility and a playable vertical slice before polish.
- **2026-11-14 / v0.2:** Added a PM-style requirements register, user journeys, a Winamp-inspired visual direction, recursive folder playback, folder/playlist modes, shuffle, acceptance criteria, phased roadmap, success measures, risks, and decisions D-006–D-009. Supersedes v0.1's deferred nested-subfolder assumption.
- **2026-11-14 / v0.1:** Initial living brainstorm: concept, scope, user flow, competing technical approaches, feasibility test, questions, and decisions.

---

**Working agreement:** Update this file as ideas evolve. Keep confirmed decisions separate from assumptions, add dated changelog entries, and record experiment results rather than treating speculation as proof.
