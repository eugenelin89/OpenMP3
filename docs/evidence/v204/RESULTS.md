# V204 — explicit intent, races, removal and recovery

Date: 2026-11-15 (America/Vancouver). Ticket #22; spec #18.
Base: reviewed V203 7e879b3. V201 remains independent for V205 integration.
The V203 ChatGPT consultation supported progression with no blocking defects;
it requested careful distinction of retryable A from exhausted recovery.

## Automated verification

`swift test`: 44 XCTest cases, zero failures after review correction. Eight new
application-boundary scenarios control suspended discovery and captured audio
callbacks, covering explicit track taps vs older scans, A-end/B-pending/C-scanning
ordering, late readiness after ordinary exhaustion, restricted removal and
future-intent clearing, temporary/permanent exhaustion, paused/playing retryable
errors, and post-handoff failure. Existing cold-launch check now verifies ready,
pending and modes are not restored alongside the saved-root checks.

Explicit tap, recovery promotion, removal, and manual-Retry tests failed before
their corrections. Native simulator builds passed. Signed-device SDK build passed
at e215553 before the manual-Retry correction; final integrated signed build is V205.
These are controlled/model/build outcomes, not physical audible verification.

## Decisions and independent review

Track taps on already-discovered rows are available during a scan, so explicit
intent can win while that scan is still in flight. The scan may settle browsing
results but its captured intent generation no longer arms a collection. New scans
may arm normally. Top collection-wide readiness still waits for settlement.
This realizes v0.2 decision 7 and deliberately differs from v0.1's settle-first
restriction for individual rows; historical documents remain unchanged.

Removal remains blocked until the single scan task finishes. Removal then clears
matching cache and ready/pending snapshots and invalidates intent; no older scan
can still settle after an allowed removal. The active queue remains independent.

Paused/interrupted temporary failures remain resumable without consuming retry
budget or pending B. Actual exhaustion is explicit and promotes B silently.
Manual Retry of A moves ready B back to pending before restarting A, so source,
track, and subsequent Next agree. The existing Retry label clarifies "previous
track" when B is ready; top Play still prioritizes B.

Standards: no findings. Spec: found Retry could play A while displaying Ready B;
reproduced with a failing regression and corrected. Recheck/ChatGPT feedback below.

## Limits

Physical audibility, remote behavior, VoiceOver, native metadata and integrated
V201 scan outcomes remain V205 work. No scope expansion, access-method change,
scan-budget claim, merge, issue closure or owner acceptance.
