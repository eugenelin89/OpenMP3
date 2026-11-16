# V201 — honest scan outcomes

Recorded 2026-11-15 (America/Vancouver). Implementation: `119742c`.
Scope: [V201 / #19](https://github.com/eugenelin89/OpenMP3/issues/19), under specification #18 and kickoff #17.

## Baseline and preservation

Fixed review baseline: `5733652b8cb24f17470f954f54149bf9713b3ce7`, the PR #14 head including merged keyboard fix #16. Draft base: `codex/overnight-player`; #14 remains stacked on draft #13. No merges or issue closures were performed.

The owner requested questions go to the existing ChatGPT design conversation when possible. Its public-reference recommendation confirmed this baseline and PR base. That recommendation is delegated design input, not new test evidence.

The v0.1 retrospective remains unchanged on `codex/v01-retrospective` at `32b2c47`; its files and acceptance evidence are also retained locally. Original uncommitted brainstorm, GLOSSARY.md, design, spec and ticket files were verified byte-for-byte against a pre-work hash manifest. They are excluded from this PR.

## Behavior

`ScanState` distinguishes active discovery from finished, incomplete and failed outcomes. Coverage notices retain their raw wording separately from observed failure reasons. The state remains scanning until settlement even when an early page reports partial results.

- Successful supported requests: neutral “Scan finished · N tracks found”, including zero; unverified coverage has a secondary disclosure.
- Cancellation, foreground exit, limits, partial search, descendant failures and detected pagination failures: orange incomplete status, with accessible reasons. Discovered tracks remain available to existing explicit playback actions after settlement.
- Unreadable root/initial listing: failed status and guidance to check access/connection and rescan.
- Empty/failed scans preserve an unrelated playing or paused queue, source and position.
- Existing traversal continues accessible siblings after a descendant pagination failure.

The serialized evidence state `complete` is retained for compatibility and means the supported request sequence finished. It never certifies exhaustive Drive coverage. Historical reports remain unchanged. No new discovery access method, key/OAuth/backend, numerical budget, playback feature or deployment target was introduced.

## Automated evidence

`swift test`: **31 tests passed, zero failures** on the final implementation. The original baseline contained 23 tests. Tests use the approved `ProbeApplication` seam with controlled Drive, audio, clock and suspended requests; existing storage/randomness/playback regressions also pass.

Red → green evidence was observed for:

| Regression | Before | After |
| --- | --- | --- |
| Successful anonymous Unicode listing | incomplete; disclaimer in failure reasons | finished; raw coverage notice separate |
| Unreadable root | incomplete with generic error | failed with actionable access guidance |
| UI-facing status | no finished/empty summary contract | exact finished/incomplete/failed copy |
| Repeated page token | generic access error | useful pagination reason, including zero tracks |
| Partial evidence during an active request | premature incomplete/playable state during development | remains scanning until settlement |
| Descendant pagination | skipped accessible sibling during development | sibling track retained, failed descendant identified |

Additional regression coverage includes warning wording independent of severity; readable anonymous empty pages; partial search/denied descendants with zero and nonzero results; stop/background cancellation with retained tracks; request/folder/track/time/response-size cutoffs; late access/restriction/malformed/transient/pagination failures; cached status; no scan autoplay; and preserved playing/paused music after empty or failed scans.

The exact commands and local execution logs are retained under ignored `probe-runs/v201/`. These tests do not establish live discovery completeness or physical audibility.

## Build and UI evidence

- `python3 scripts/build_simulator.py`: PASS, normal app.
- `python3 scripts/build_simulator.py --scan-ui-fixture`: PASS, isolated fixture executable with the real screen and coordinator; no network/audio dependency.
- Signed physical-device SDK build and signature verification: PASS, using the existing development profile and identity.
- Installation and normal launch on the available iPhone 16: PASS.

Computer Use inspected the iPhone SE simulator on iOS 26.5:

| Scenario | Observed result |
| --- | --- |
| Finished, one track | White finished heading; secondary coverage disclosure; no queue/autoplay; collection playback available |
| Empty | Neutral zero-track heading; collection playback disabled |
| Incomplete, one track | Orange incomplete heading; expanded reason visible; disclosure accessibility value exposes the reason |
| Failed root | “Scan failed”, actionable access/rescan guidance, reason available in accessibility tree |
| Incomplete-empty at accessibility-extra-extra-extra-large | Reasons and coverage notice wrap and remain reachable by scrolling; disclosure expands; no tracks to play |

Screenshots contain synthetic fixture content only:

- [Finished](finished.png)
- [Readable empty](empty.png)
- [Incomplete with expanded reason](incomplete.png)
- [Actionable failure](failed.png)
- [Accessibility-size expanded reasons](accessibility-reasons.png)

The simulator's original `large` text category was restored. The inherited top-player title and lower playback buttons still truncate at the maximum accessibility size; this focused status slice does not certify the entire screen's accessibility. No VoiceOver speech/navigation pass is claimed.

## Live anonymous and physical checks

The final CLI build scanned an existing authorized public fixture with no media sampling: **14 tracks, 1 metadata request, 1 listing, 0 retries, 5.200 seconds**, HTTP 200 for both requests. The outcome was finished, with no failure reasons and the original unverified-coverage notice. [Sanitized aggregate report](live-scan.json).

On the installed physical iPhone 16 build, a rescan of an already saved root visibly passed through Discovering and settled at **“Scan finished · 15 tracks found”** in neutral white. The secondary coverage disclosure expanded to the raw undocumented-webpage notice. The player remained **IDLE**, **No queue**, with no autoplay. This was observed through iPhone Mirroring after the owner locked the phone. The physical root differs from the CLI fixture; the counts are separate observations.

Physical screenshots containing the saved-folder label are retained only in ignored local evidence. No personal fixture URLs, names, paths or media are published. The phone was left on its settled scan. Audible playback, VoiceOver, headset/lock-screen controls, Maps/interruption behavior and legacy-device runtime compatibility were not retested for this build.

## Standards

Independent Matt Pocock Standards review of `5733652...119742c`: **0 findings**. No documented-standard violations or actionable baseline smells. Typed state, separate coverage notices, controlled application tests and the isolated UI fixture align with the repository guidance; budgets, access methods and deployment constraints remain intact.

## Spec

Independent Matt Pocock Spec review of `5733652...119742c`: **0 actionable findings**. The review found V201's typed outcomes, neutral finished/empty status, incomplete reasons, actionable root failure and retained partial playback implemented. It excluded V202 ready/handoff requirements and left actual UI/build verification to the checks above.

Review totals: Standards 0; Spec 0. No outstanding concrete review findings.

## Acceptance limits

V201's implementation and focused regression/presentation criteria are satisfied by the evidence above. Unknown Drive coverage remains unknown; live pagination/resource-key completeness and the existing T01 gate are not resolved. This work does not implement V202–V205 or certify broader physical audio/accessibility behavior.
