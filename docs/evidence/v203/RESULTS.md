# V203 — pending collection handoff

Date: 2026-11-15 (America/Vancouver). Ticket #21, specification #18.
Base: V202 7226672. V201 remains separate until V205.

## Verification

- `swift test`: 36 XCTest cases, zero failures. Six new application-boundary
  handoff tests cover natural vs explicit transition, Pause/Play/Previous on A,
  paused Next, all repeat modes, shuffle at consumption, new history/source,
  suspended replacement, empty/failed preservation and same-root snapshots.
- Natural handoff test failed before implementation. Repeated-file-ID stale
  completion test failed before generation-scoped callbacks, then passed.
  The real native adapter captures each item-load callback; old callback delivery
  is rejected even if the next collection starts the same Drive file.
- Permanent-unavailable skipping stays inside A while B remains pending.
  Full failure exhaustion/race/removal combinations are the next V204 slice.
- Native simulator and isolated player fixture builds passed.
- Computer Use, small-screen OpenMP3 Keyboard SE simulator / iOS 26.5:
  observed current A source with Up Next B; Pause retained A and B; Next switched
  source to B, removed Up Next, and remained PAUSED with Play available. Passed
  as synthetic UI behavior only; fixture emits no audible audio.

## Review

Standards: no documented violations. One optional low-priority test-fixture
repetition heuristic; kept explicit per-scenario setup for readability.
Spec review and consultation results are recorded below when complete.

## Limits

No physical audible/remote/VoiceOver or legacy acceptance is claimed. Native
metadata availability is finalized in V205. Playback recovery exhaustion and
scan intent invalidation are V204. No budget, access-method or historical
acceptance changes. Draft only; owner acceptance pending.

Spec review: no actionable V203 defects, no scope expansion. Reviewer explicitly
confirmed generation-bound callbacks reject stale repeated-file events; V204 and
V205 responsibilities remain separate. Signed device SDK build passed using the
existing development identity/profile; this is not physical playback evidence.
