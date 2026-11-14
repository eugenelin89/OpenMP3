# Public Google Drive Music Player — Living Brainstorm

> **Status:** Exploring / pre-build  
> **Version:** 0.1  
> **Created:** 2026-11-14  
> **Last updated:** 2026-11-14  
> **Working title:** Drive Folder Music Player (name TBD)  
> **Purpose:** A living source of truth for brainstorming, technical experiments, decisions, and Codex implementation.

## 1. The idea in one sentence

An iPhone app where someone pastes an **“Anyone with the link” Google Drive folder URL** and immediately gets a simple music player for the MP3s in that folder—**no Google sign-in and, if technically feasible, no Google Drive API key**.

## 2. Problem and opportunity

A public Drive folder is easy to share, but it is not a convenient music playlist on an iPhone. Existing solutions may require a Google account connection, a paid upgrade, or a browser-based player. We want a frictionless, native experience: **paste link → see songs → press Play**.

## 3. Product principles

1. **Link-first:** The public folder URL is the primary input.
2. **No account required:** No Google OAuth, no app account, no sign-up for the initial version.
3. **No API key initially:** Investigate whether public-link discovery and streaming can work without the official Google Drive API. This is a *hypothesis to validate*, not a proven capability.
4. **Native iPhone experience:** SwiftUI interface, background audio, lock-screen controls.
5. **Minimal scope:** Make one folder work reliably before adding features.
6. **Transparent failure:** Explain inaccessible folders, unsupported files, and playback failures rather than silently failing.

## 4. User experience (first draft)

**Happy path**

1. Open the iPhone app.
2. Paste a public Google Drive folder link.
3. Tap **Load folder**.
4. The app finds playable audio files and shows a song list.
5. Tap a song or **Play all**; tracks continue automatically.
6. Control playback from the lock screen or headphones.

**First-screen sketch**

```text
┌────────────────────────────────┐
│ Your Music                     │
│                                │
│ Google Drive folder link       │
│ [ https://drive.google.com/… ] │
│ [ Load folder ]                │
│                                │
│ Recently added                 │
│ • Folder A                     │
│                                │
│ Now Playing                    │
│ [◀◀] [▶/Ⅱ] [▶▶]    [Shuffle]    │
└────────────────────────────────┘
```

## 5. MVP scope

### Must have

- [ ] Paste and validate a Google Drive **folder** link.
- [ ] Read a folder shared as **Anyone with the link → Viewer**, without asking the listener to sign in.
- [ ] Discover MP3 files, including filenames and playable URLs when available.
- [ ] Display a selectable track list with loading and error states.
- [ ] Play/pause, next/previous, autoplay next track.
- [ ] Basic shuffle and repeat.
- [ ] Background playback and lock-screen / headset controls.
- [ ] Remember previously used folder links locally on the device.

### Nice to have later

- [ ] Embedded artwork and ID3 metadata.
- [ ] Multiple folders and a combined library.
- [ ] Nested subfolder support.
- [ ] Playback position/resume.
- [ ] Offline caching for files the user is authorized to access.
- [ ] AirPlay and CarPlay polish.
- [ ] Share Sheet: **Open in Music Player** from a Drive folder link.

### Explicit non-goals for version 1

- Private Google Drive folders requiring account authorization.
- A cloud backend, subscription, or social features.
- Uploading or modifying files in Google Drive.
- Circumventing Drive access controls, download restrictions, or usage limits.

## 6. Technical direction — hypotheses, not yet validated

**Target stack:** Swift, SwiftUI, AVFoundation/AVPlayer, AVAudioSession, MPNowPlayingInfoCenter, MPRemoteCommandCenter. Store saved folder links locally (e.g., UserDefaults initially).

### Option A — Public-link-only, no API key (preferred experiment)

- Parse the folder ID and any resource-key information from the shared URL.
- Request the public folder page, then investigate whether a maintainable method exists to extract the files and their identifiers.
- Resolve an audio URL usable by the player and test actual streaming, seeking, and next-track playback on a physical iPhone.

**Risks:** Google Drive's human-facing page is not a documented folder-listing API; markup/scripts can change. Direct file/download links may redirect, expire, require cookies, block streaming or byte-range requests, or encounter quota/download restrictions. A browser-visible folder does **not** guarantee that a native app can list and stream every file anonymously.

### Option B — Official Google Drive API (fallback)

- Use the supported Drive API to list publicly accessible folder contents, with an appropriately restricted application API key if the endpoints and access mode permit it.
- Separately verify file-content retrieval and the behavior of resource keys, quotas, download restrictions, and audio seeking.

**Trade-off:** More predictable file metadata discovery, but requires API configuration. An API key identifies the calling project; it does not grant permission to private files. An API key embedded in an iOS app should not be treated as a secret.

### Option C — User-authorized Google Drive access (later only)

- OAuth may be needed for private folders or some otherwise inaccessible files.
- Outside the initial product promise; reconsider only if requirements change.

**Architecture decision pending:** We should only select an architecture after testing an actual public folder. Avoid building the full interface around an unverified extraction strategy.

## 7. First technical experiment — highest priority

**Goal:** Prove or disprove the defining user journey before building the rest of the app.

**Test setup:** A Google Drive folder containing at least three MP3 files, shared as **Anyone with the link → Viewer**. Use test files you have the right to access. Test on a physical iPhone and, where useful, with a simple network prototype.

**Acceptance criteria:**

- [ ] Paste the URL without Google login or an API key.
- [ ] List all expected MP3 filenames in a predictable order.
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
| Q3 | Are all audio files directly in one folder, or are subfolders important? | **Assume** one folder for MVP |
| Q4 | MP3 only, or also M4A, AAC, FLAC, WAV? | **MP3 first** |
| Q5 | Should songs play in filename order, folder order, or shuffled order by default? | **Assume** filename order |
| Q6 | Is cellular streaming acceptable? | **Assume** yes, with user control later |
| Q7 | Is downloading/offline listening essential? | **No**, defer |
| Q8 | What should we call the app? | **Open** |
| Q9 | What happens if anonymous folder listing cannot be supported reliably? | **Open**; run experiment first |

## 10. Decisions log

| Date | ID | Decision | Rationale / confidence |
| --- | --- | --- | --- |
| 2026-11-14 | D-001 | Target a native iPhone app | User wants an iPhone app |
| 2026-11-14 | D-002 | Input is a public Google Drive folder URL | Core user experience |
| 2026-11-14 | D-003 | Do not require listener Google sign-in in the MVP | Core user preference |
| 2026-11-14 | D-004 | Test a no-API-key approach **before** committing to it | Unverified technical feasibility |
| 2026-11-14 | D-005 | Build with Codex; validate a single folder first | Keep scope small |

## 11. Parking lot — ideas to revisit

- Playlist sharing using only a public folder URL.
- Simple album artwork from folder image files.
- Gapless playback / crossfade.
- Playback speed for spoken-word MP3s.
- Widgets, Siri Shortcuts, and Share Sheet integration.
- Import links from QR codes.

## 12. Codex kickoff task (copy/paste)

> Build a minimal native SwiftUI iPhone proof of concept for this spec. Start with the feasibility spike in Section 7, not the full application. Accept a Google Drive folder URL shared as “Anyone with the link → Viewer.” Attempt to list MP3 files and stream at least one file with **no Google sign-in and no Google Drive API key**. Do not use brittle webpage scraping without documenting its fragility, and do not bypass Google access restrictions. Report which operations succeeded, which failed, HTTP/streaming limitations, and an honest recommendation about whether the no-key approach is supportable. If the no-key approach is not viable, outline a minimal official-API fallback before implementing it. Use AVPlayer for playback and test on a physical iPhone when available.

## 13. Next actions

1. Supply a non-sensitive test public Drive folder URL containing a few MP3 files.
2. Run the no-key proof of concept in Codex.
3. Record results here under **Experiment log**.
4. Decide whether to proceed with Option A or Option B.
5. Create a tighter V0.1 build specification based on those results.

## 14. Experiment log

| Date | Test | Result | Evidence / notes | Follow-up |
| --- | --- | --- | --- | --- |
| — | Public folder anonymous listing | Not yet tested | — | Codex spike |
| — | Direct MP3 streaming on iPhone | Not yet tested | — | Codex spike |
| — | Seek, next track, background playback | Not yet tested | — | Codex spike |

## 15. Changelog

- **2026-11-14 / v0.1:** Initial living brainstorm: concept, scope, user flow, competing technical approaches, feasibility test, questions, and decisions.

---

**Working agreement:** Update this file as ideas evolve. Keep confirmed decisions separate from assumptions, add dated changelog entries, and record experiment results rather than treating speculation as proof.
