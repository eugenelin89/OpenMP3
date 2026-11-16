# V202 — single top player and ready collections

Date: 2026-11-15 (America/Vancouver). Ticket #20; specification #18.
Baseline: fixed player 5733652b8cb24f17470f954f54149bf9713b3ce7.
V201 remains independent in draft #24; scan wording here is still the baseline wording.

## Automated evidence

`swift test`: 29 XCTest cases, zero failures after review corrections. Six new
application-boundary tests use controlled discovery, recording audio, deterministic
shuffle and suspended completion. They verify top Play, silent navigation,
repeat boundaries/history, initial shuffle, partial-result eligibility, empty/failed
preservation, cached browsing, ready replacement, and exhausted queue precedence.
Initial top-Play and navigation tests failed before implementation. Review regression
reproduced failure to arm after permanent exhaustion, then passed after correction.
The first red test also had an unsafe test-array assertion; it was corrected to
use `first` before subsequent runs. No test-run crash is counted as a pass.

`python3 scripts/build_simulator.py`: native simulator build passed.
`python3 scripts/build_simulator.py --player-ui-fixture`: isolated synthetic UI
fixture build passed. No network or audible output in this fixture.

## Focused UI observations

Computer Use, OpenMP3 Keyboard SE simulator, iOS 26.5:

| Steps | Expected / actual | Result |
| --- | --- | --- |
| Launch settled fixture | READY, Ready collection, track 1, enabled top transport; no lower Play All/Shuffle All | Passed |
| Next before Play | Track 2, still READY | Passed |
| Top Play | Track 2 becomes active, source changes to queue source, Pause replaces Play | Passed (synthetic audio only) |
| Expand Load another folder; focus URL | URL visible above software keyboard, Done visible | Passed |
| Paste synthetic public-folder URL; Load | URL accepted, Load enabled, new selected saved folder; old queue source retained | Passed |
| Press Done explicitly | Not separately exercised in this pass | Not tested |

## Independent review

Standards: zero documented violations; one possible duplicated-ordering smell.
Resolved with a shared visited-prefix/unvisited-suffix ordering function.
Spec: found fresh settlement blocked after permanent exhaustion because `current`
remained nonnil. Added failing regression and a resumability predicate; corrected.
Spec also requested this UI/environment evidence record, now supplied.

## Limits

Implementation and automated checks do not establish owner acceptance. Physical
sound, VoiceOver, remotes, accessibility-size layouts and legacy compatibility are
not claimed here. Pending handoff, explicit intent races/recovery integration and
native metadata are V203–V205. No Drive coverage, scan-budget or v0.1 acceptance
claims changed. No PR merged or issue closed.
