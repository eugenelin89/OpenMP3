# Provisional overnight player — 2026-11-15

**Status: usable prototype, formal acceptance OPEN.** The owner explicitly asked for continued app implementation overnight, pragmatic testing, and advice from the already-open ChatGPT session in Brave. That later instruction permits provisional work beyond T01; it does not establish missing feasibility evidence, authorize another access method, or authorize issue closure/merging. The advisor recommended completing the playable core and leaving physical listening/navigation validation for morning.

The implementation builds on [T01 draft PR #13](https://github.com/eugenelin89/OpenMP3/pull/13). No Google Drive API key, OAuth, backend or logged-in discovery was added. The anonymous page adapter remains experimental. Every real scan still reports incomplete coverage because pagination and descendant resource-key handling remain unverified.

## Implemented behavior

- Explicit Play all, Shuffle all and settled-track taps; play/pause, seek, Next/Previous, natural advancement. Loading a root never autoplays or replaces a queue.
- Repeat Off/All/One, shuffle of the unvisited remainder, actual Previous history, paused transport, and restart of the original source after exhaustion. Repeat cycles avoid immediate boundary duplicates when shuffled alternatives exist.
- Foreground scan cancellation, retained partial discoveries, ignored-file and shortcut accounting, folder grouping and independent selected-root/queue-source labels.
- Local saved roots and last selection; session-only settled collection cache; fresh Rescan replaces browsing results; removal leaves the existing queue and source label intact. Cold launch restores no queue or position.
- An original dark SwiftUI player, separate saved-folder and queue sheets, labeled controls, touch-sized transport, and a scrolling layout for accessibility text sizes. No copied skin or visualizer.
- Native playback session/background capability, Now Playing metadata, shared system play/pause/Next/Previous/seek actions, interruption permission and explicit-pause precedence, and pause on route disconnection. These are implemented integrations, **not physical-device acceptance passes**.
- Conservative playback recovery: one automatic re-prepare per failed item attempt, followed by a paused Retry state retaining the last position; explicit Retry begins another bounded attempt. This is a provisional engineering policy, not measured live-outage recovery. Unknown failures, access/quota responses and ambiguous format errors remain retryable. Confirmed missing-resource HTTP responses or native decode/decoder failures are marked unavailable; unavailable tracks cannot loop forever under repeat. A new explicit collection Play can retry them.

## Verification matrix

| Check | Result | Evidence and limits |
| --- | --- | --- |
| Application behavior suite | Pass | `swift test`: 23 tests, including eight new integrated tests for transport/source independence, interruption/disconnect, shuffle/repeat, saved roots/cold launch, failures and single-item queues. Controlled Drive/audio/storage/randomness substitutes; not live-media proof. |
| iPhone SDK compilation/signing | Pass | Direct SDK build with the existing local development profile and identity. Baseline remains in the canonical brainstorm. |
| Simulator launch/layout | Pass | Dedicated iPhone 16 simulator, iOS 26.5. Original dark player, labeled transport and selected-folder hierarchy observed. |
| Invalid link | Pass | UI displayed invalid-folder-link feedback; collection playback remained unavailable. |
| Live discovery through player UI | Partial pass | Authorized small fixture: 14 tracks, explicitly incomplete scan, Play controls enabled, player stayed IDLE with no queue. Cookies-free anonymous adapter. No personal titles/URLs published. |
| Saved-folder sheet | Pass for basic UI | Sheet displayed the locally saved fixture label; selection indicator and removal explanation observed. Full persistence/queue isolation covered by controlled behavior tests. |
| Physical playback in this integrated build | Not tested | Owner asleep. Earlier T01 physical streaming, seek and natural-transition evidence is preserved separately and is not relabeled as a pass for this build. |
| Maps, lock screen, headset/Bluetooth remotes, interruptions, route changes | Not tested physically | Native wiring and controlled event tests pass; Maps version/physical route not applicable to this silent run. |
| VoiceOver, accessibility text sizes, legacy hardware | Partial / not tested | Controls are labeled and accessibility-size layout implemented; complete interactive VoiceOver/large-text and legacy-device verification remains outstanding. |
| Real pagination/resource keys/large single-folder discovery | Unresolved | See [T01 evidence](../t01/RESULTS.md). No new access mechanism or completeness claim. |

## Build and morning check

1. Follow the [README](../../../README.md) to generate and build the app. App scan configuration is generated from the [canonical scan-limits section](../../../Drive_Folder_Music_Player_Brainstorm.md#v01-recursive-scan-boundary-and-limits); values are not maintained in another product document. These controls remain explicitly provisional.
2. Open OpenMP3, paste an authorized public folder link, optionally name it, and Load. Confirm no autoplay, incomplete status and discovered tracks.
3. Play a track; verify sound, pause/resume, seeking, Next/Previous, shuffle/repeat and queue contents. Browse/scan another folder while music continues; stop the scan. Verify saved-folder switching, Rescan and removal preserve the queue.
4. While stationary, verify Maps prompts, screen lock and natural advancement, supported remotes, interruption recovery and disconnect/reconnect. Record each observed result, device/OS/Maps version and audio route. Do not mark these passed from compilation or simulated callbacks.
5. Cold-launch: saved roots and selection remain; no queue resumes. Scan and Play explicitly.

No issues are closed and no PRs are merged. T01/#4 and integrated T08/#11 cannot satisfy acceptance until their outstanding evidence is resolved. Optional playlists and billing remain deferred.

Native integration follows Apple's [interruption guidance](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions) and [remote-command guidance](https://developer.apple.com/documentation/mediaplayer/handling-external-player-events-notifications). The installed SDK was used for API/type verification; these references are design support, not device-test evidence.

## Review fixes

Standards review found a recovery-position race and inconsistent transport intent presentation. Spec review additionally found first-track pinning in Shuffle All, a shuffled exhaustion-boundary repeat, and Previous history lost at repeat boundaries. Fixed all findings: recovery ignores preparatory progress until successful restoration (including failed-seek cases), UI and toggle share playback intent, full shuffle includes the first choice, exhaustion retains its boundary identity, and stable-ID history survives cycles. Targeted regressions cover these paths; the spec reviewer independently reproduced the corrected outcomes. No new access method or acceptance claim was added.

Installed implementation: [`a8fa31c`](https://github.com/eugenelin89/OpenMP3/commit/a8fa31c47588b2b6bc96d0ba4d9633bca99bb715). The signed prototype was installed on the connected iPhone without launching playback. Open the app named **OpenMP3** in the morning; saved links are local and no personal fixture is embedded in the app. Installation alone is not a physical playback pass.
