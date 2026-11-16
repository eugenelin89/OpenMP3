# V205 — native controls, accessibility and integrated verification

2026-11-15 (America/Vancouver). [Ticket #23](https://github.com/eugenelin89/OpenMP3/issues/23),
[spec #18](https://github.com/eugenelin89/OpenMP3/issues/18).
Code tested: `661fa65947a9eced338ffc1aace2afc6263aacbb`.
Integration commit `0adab7668177efd63340600bff8af64d429f1d9c` combines V204
`89f8093` and independently preserved V201 `38a0845`.

Implementation complete; automated verification complete; physical verification
partial; owner acceptance pending. Listening confirmation below is evidence of
audible playback, not acceptance of the whole iteration.

## Implemented and reviewed

Top controls and native commands share availability and displayed metadata.
Ready collections publish their own track/source with zero time/rate; seek cannot
reach an exhausted old queue. Empty, playing, paused and ended states have explicit
command availability. App startup publishes empty metadata. Accessibility-size
layouts stack controls and wrap titles; mode labels expose current values.
The generated app is version 0.2, build 2.

Independent Standards and Spec reviews found no actionable defects at `661fa65`.
The Spec reviewer explicitly distinguished shared metadata tests from actual
MPRemoteCommandCenter, audibility and VoiceOver verification. V202's exhausted
readiness defect, V203's stale same-file callback race, and V204's Retry A/Ready B
contradiction were corrected with regressions before this integration.

## Automated and build evidence

- `swift test`: **55 XCTest cases, zero failures**. The separate Swift Testing
  runner reports zero cases; it is not the suite count. Integrated scan outcomes,
  empty/partial/failed preservation, ready seek rejection and native presentation
  contracts join ready/handoff/intent/recovery regressions.
- The ready-seek regression failed before correction. The V201 merge first passed
  52 existing cases; V205 added three integrated cases.
- Normal simulator, player fixture and scan fixture builds passed using
  `scripts/build_simulator.py` and its mutually exclusive fixture flags.
- Signed device build passed through `scripts/build_device_probe.py` using the
  existing compatible development identity/profile. The final V204 correction
  also received a successful signed build before this integrated build.
- Xcode 26.6 (17F113), Apple Swift 6.3.3; simulator iOS 26.5. Native fixture checks
  used the small-screen OpenMP3 Keyboard SE simulator. No XCUITest target exists;
  these UI checks were performed with Computer Use, not an automated UI suite.

## Simulator accessibility and keyboard observations

At the largest accessibility text category, the initial layout truncated the title
and split the loading status. After correction, status and title wrapped, transport
and mode controls remained reachable, and Repeat All could be selected. The
accessibility tree exposed Pause and mode values. URL entry remained visible above
the software keyboard; explicit Done removed that keyboard. The simulator text
category was restored to its original Large setting. This verifies layout and
available accessibility labels, not spoken VoiceOver order or usability.

## Physical iPhone observations

iPhone 16 (iPhone17,3), iOS 26.5.2 (23F84); installed app 0.2/build 2 from `661fa65`.
Executable SHA-256:
`e915a94c89a0bd7efd0dc845d28fad824ba75a33b8fef53486f6ec38ca1e471a`.
Installation succeeded. Initial command-line launch failed because the phone was
locked; iPhone Mirroring subsequently opened the installed app successfully.
Existing authorized saved folders are anonymized here as A and B. Screenshots
containing personal folder labels/music titles are not published.

| Scenario | Actual observation | Evidence boundary |
| --- | --- | --- |
| Cold launch | Saved roots restored; IDLE, no queue, disabled transport, modes off, no autoplay | Physical UI |
| Discovery A/B | A settled with 15 tracks, B with 12; neutral Scan finished and separate unverified-coverage disclosure | Physical UI; not completeness proof |
| Silent ready Next | Changed selected ready track; remained READY at zero time | Physical UI; no playback intent |
| Top Play | Loading then PLAYING, elapsed time and media duration advanced | Physical UI/timing |
| A during B scan | A retained its source and advanced; Pause/Play retained A; B became Up Next | Physical UI/timing |
| Explicit handoff | Next changed A to B and removed Up Next; B progressed | Physical UI/timing |
| Separate natural handoff | While B played, rescanned A; no Next or seek was issued; later A was playing at 1:08 with pending cleared | Observed before/after natural boundary; exact transition instant not captured |
| Paused handoff | A stayed paused at 1:16 through B scan; Next changed source to B at 0:00 and stayed PAUSED; Play resumed B | Physical UI/timing |
| Background | B advanced from about 0:10 before leaving to 0:29 on return through Home/Maps | Physical timing; Maps showed onboarding, no navigation prompts exercised |
| Modes and continuation | Shuffle on and Repeat All selected; both restored off; subsequent Next played another B track at 0:07 | Control/state observation; repeat boundary and shuffle ordering covered by controlled tests |
| Audible playback | Owner stated “i can hear the music” during this installed-build session | Human confirmation of general audibility; no per-transition or background-specific listening claim |

Not tested / requires owner verification: actual lock-screen/Control Center/headset
remote delivery and metadata, Bluetooth/route changes, interruptions and Maps voice
prompts, spoken VoiceOver traversal, extended background reliability, per-transition
audible continuity, and legacy runtime/hardware compatibility. Mirroring does not
provide the needed audio/hardware observations. No unavailable check is a pass.

## Anonymous live scan

[Sanitized report](live-scan.json): existing authorized fixture, 14 tracks in one
folder, one metadata and one listing request, both HTTP 200, zero retries, about
5.49 seconds. This fixture differs from the physical A/B roots above. No media was
sampled by this command. Legacy serialized `complete` means supported scan finished;
the unverified pagination/resource-key coverage notice remains. Recorded numeric
probe controls are experiment defaults, not a change to canonical app budgets.

## Remaining limits and integration

T01 completeness, pagination/resource keys, representative large/non-audio fixtures
and measured budget justification remain open. No access-method, canonical budget,
platform promise or accepted v0.1 history changed. All implementation PRs remain
drafts; no issue was closed. Review/merge prerequisites before retargeting the stack
and rerun integrated checks on the actual merge result. Complete owner verification
before any broader reliability or release claim.
