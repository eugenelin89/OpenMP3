# T01 evidence — 2026-11-15

**Outcome: partial feasibility evidence; gate OPEN.** This is an experiment deliverable, not completion of issue #4 or permission to release downstream app tickets.

The user supplied three authorized public folder links during implementation and explicitly decided: **“for this version we are not going to use API key.”** The earlier ticket/spec fallback allowance is superseded for this version. No key, OAuth, logged-in browser session, Drive connector credentials, backend or restriction bypass was used. Fixture links and raw pages remain local in ignored `probe-runs/`; they are not published here.

## Initial network evidence (historical; follow-up below supersedes coverage gaps)

Initial bounded anonymous checks on fixture A returned:

- Public root page: HTTP 200, 445,756 bytes, 0.459 seconds, no redirects (curl).
- Official Drive API listing without a key: HTTP 403, 692 bytes, 0.118 seconds, `Permission denied on the service.` This failure applies to that endpoint/request, not all possible anonymous access paths.
- One public media download URL with `Range: bytes=0-1023`: HTTP 206, 1,024 bytes, `audio/mpeg`, one redirect, 1.885 seconds. No confirmation-token or cookie workaround.

The Swift probe then ran independent anonymous sessions against both fixtures. These first runs overlapped; latencies are observations on this host/network, not calibrated estimates or application budgets.

| Capability | Result | Evidence / limitation |
| --- | --- | --- |
| Public webpage entry extraction | Pass for these pages | Fixture A exposed 14 MP3s at root. Uses undocumented `window['_DRIVE_ivd']` escaped JSON and positional row fields. |
| Real child-folder traversal | Partial pass | Fixture B exposed two child folders and 15 MP3s at child depth. Three folder-listing requests plus one root-validation request. |
| First-run listing measurements | Observed | A: 6.105 seconds, one listing + one validation; B: 9.242 seconds, three listings + one validation; no retries in either run. Includes parsing, excludes media sampling. |
| Distinct identities and paths | Observed for exposed entries | Public reports now retain aggregate counts only; original detailed evidence is preserved locally. No independent owner manifest supplied to establish complete coverage. |
| Byte ranges / redirects | Pass for sampled files | Two ranges per track (beginning and nonzero offset), first two discoveries in each root: eight HTTP 206 responses, each 1,024 bytes. No claim about every track. |
| Root resource-key parsing | Controlled test pass | Parser preserves the supplied query parameter; no real key-protected fixture supplied. |
| Descendant resource-key propagation | Not tested / unresolved | Undocumented page-field location is not assumed. Entries requiring a key may fail. |
| Pagination / large non-audio folder | Not tested / unresolved | Only initial public page data is understood. Every real scan is deliberately marked incomplete. |
| Root + child + grandchild MP3 fixture | Not tested | Supplied trees cover root and child depth across different roots, not the required three-level representative fixture. |
| Duplicate names / ignored files / shortcuts / inaccessible descendant | Controlled test coverage only | Not observed in supplied real fixtures. |
| Download restrictions / quota | Not tested | No such response observed; no deliberate quota exhaustion or restriction bypass. |
| Restricted developer key | Excluded | Current user decision is no key for this version. |
| Numerical application scan budgets | Unresolved | These small trees cannot justify request/time/retry budgets for representative large/non-audio scans. |

Root-page validation currently fetches the root page separately from its listing; the reports count this overhead explicitly. Reports distinguish HTTP range probes from native AVPlayer traffic. Initial reports used the generic reason “Drive reported incomplete search” as a local conservative marker; this was corrected in code to identify **our unverified webpage coverage**, not a Google server assertion.

## Physical device / native audio

Device available: connected iPhone 16, iOS 26.5.2. This is observed test hardware, not a change to the [canonical platform baseline](../../../Drive_Folder_Music_Player_Brainstorm.md#platform-compatibility-baseline-single-source-of-truth).

- Swift app passed direct SDK typechecking and built/signed using the existing development identity/profile. Binary inspection confirmed the canonical minimum deployment target.
- Standard `xcodebuild` was blocked by missing device platform components. The documented direct SDK build installed successfully with `devicectl`.
- Initial launch failed because the phone was locked. The user unlocked it; the second launch succeeded.
- The first automated run did not start because the foreground wait held stale view state. The user could play songs manually. The corrected run starts when the scene becomes active and writes interim/final evidence.
- The [physical-device report](device-smoke.txt) records native first-item progression, midpoint seek requested/observed at 106.3 seconds, near-end seek requested/observed at 208.7 seconds, a natural-end event, second-item readiness and subsequent time progression. Audio route: built-in speaker. This is real AVPlayer streaming; no local audio file was supplied to the player.
- Human observation: the user confirmed manual playback, and for the automated run answered **“Heard audio, but cannot confirm every step.”** Audible sound is confirmed; separate audible midpoint/second-track confirmation remains **not fully verified**. The report's manual pickers retain `not tested`; these later chat observations supplement them without rewriting raw evidence.
- The latest [sanitized network rerun](network-root-b.json) found the same 15 tracks through three folders in 8.828 seconds (three listings + one validation), with four additional successful range samples. The device's scan took 8.494 seconds. These are small-fixture observations, not application budgets.
- Legacy reference hardware, second network, Maps, lock-screen, interruptions and remotes remain unverified. Comprehensive device acceptance belongs to [T07](https://github.com/eugenelin89/OpenMP3/issues/10) and [T08](https://github.com/eugenelin89/OpenMP3/issues/11).

## Recommendation and gate

The original gate recommendation was to continue only the no-key feasibility experiment. The owner subsequently authorized a provisional overnight app implementation while they sleep; that changes implementation sequencing, not the evidence standard or no-key decision. Keep T01 and downstream acceptance open, and do not merge or release automatically. The observed public media path supports byte-range retrieval, and the webpage payload exposes useful entries and child folders. Do not treat that brittle schema as a reliable, complete listing contract. Pagination, resource-key coverage, representative fixtures, remaining audibility/compatibility checks and measured application budgets remain mandatory before declaring the app accepted. Provisional review branches may proceed under the later owner instruction. If the no-key path cannot meet that gate, return for a product decision; do not silently introduce the now-excluded key fallback.

[Run and fixture instructions](../../../README.md) describe the rerunnable demo and bounded measurement procedure. The [canonical scan-limits section](../../../Drive_Folder_Music_Player_Brainstorm.md#v01-recursive-scan-boundary-and-limits) owns any eventual application budget values. Temporary controls recorded in experiment reports are not those budgets.

## Automated checks and review

The follow-up behavioral suite has 15 passing tests at `ProbeApplication`, including controlled recursive/paginated discovery, identity/path handling, invalid versus inaccessible/empty roots, exact/over limits, retries, deadline cancellation, foreground exit, explicit playback and queue-source separation, stale audio events, escaped Unicode and malformed child-page recovery. These tests are controlled-substitute evidence, separate from the live network/device artifacts.

The standards review found descendant parse-failure isolation and UTF-16 escape handling defects; both were fixed with regression coverage. The specification review found a stale native time-callback race that could misattribute first-track timing to the second track; time observers now bind to the producing AVPlayer item. A subsequent review caught raw JSON decoding errors bypassing descendant recovery; those are normalized as well. No unresolved code-review defect remains from those findings; the documented experimental coverage gaps remain open.

## Follow-up experiments and remaining evidence (2026-11-15)

Latest main (`c2a99eb`, brainstorm revision 0.11) was merged while preserving local implementation `3452549`, pre-existing documentation edits, glossary and original evidence. Public evidence uses aggregate schema 2: no folder URLs, names, IDs, resource keys or identifying hashes. Historical raw material remains in ignored local storage and the preserved local history; the review branch publishes only the sanitized tree.

| Experiment | Result | Measured evidence |
| --- | --- | --- |
| Repeated small-root scans | Pass for exposed entries | [A](resume-fixture-a/summary.json): three runs, 14 tracks, one listing plus validation, median 5.321s, max 5.379s. [B](resume-fixture-b/summary.json): three runs, 15 tracks, three listings plus validation, median 8.577s, max 8.768s. Zero retries throughout. Host/network observations, not calibrated performance guarantees. |
| Deeper mixed tree | Partial pass | [After fix](deep-tree-after-empty-fix.json): 47 tracks at relative depth three, 31 listings plus validation, 54 ignored files, 68.200s, zero retries. No independent owner manifest establishes completeness. |
| Empty descendants | Fixed and verified | The [pre-fix scan](root-c-expanded.json) mislabeled four empty public folders as unreadable (70.301s). A controlled regression reproduced the observed null-row payload; the live rerun retained all 47 discoveries without unreadable-descendant reasons. |
| Listing cutoff | Pass | [Live request cutoff](live-request-cutoff.json): one listing plus validation, 4.261s, explicit incomplete result. The [initial deeper scan](root-c-initial.json) retained 28 discoveries when its experimental request bound fired. |
| Deadline cancellation | Pass | [Live time cutoff](live-time-cutoff.json): root request canceled at 0.108s for the deliberately short experiment; explicit incomplete result. |
| Byte ranges | Pass for samples | First repeated A/B runs and deeper post-fix run each returned four HTTP 206 responses of 1,024 bytes, covering offset zero and a nonzero offset on two tracks. No content published. |
| Device progression and seek | Pass for native events; audibility partial | [Follow-up iPhone report](device-smoke-followup.txt): first item progressed, midpoint seek completed and playback progressed again, near-end seek led to natural end and second-item progression. Speaker route. The owner was ready before the run, then went to bed without confirming each audible stage. Earlier human confirmation of sound remains valid; no new per-stage audible pass is claimed. |
| Pagination and resource keys | Unresolved | The standard page and embedded view were inspected anonymously. No genuine multi-page or key-protected fixture was established. Public client code inspection did not establish a supported continuation contract. No web-client key was extracted or used. Root-key forwarding is controlled-test evidence only. |
| Large non-audio folder, duplicates, shortcuts, inaccessible children | Not verified live | The deeper tree contains ignored files but no demonstrated large single folder or multi-page listing. No real duplicate filename groups or shortcuts were observed. Four apparent inaccessible children were empty instead. Controlled substitutes cover these behaviors. |
| Live retry recovery | Not tested | No 429/5xx or transient retry occurred. Controlled tests verify bounded retry accounting; they do not establish live recovery or optimal retry values. |

Numerical recommendations and their rationale appear **only in the [canonical scan-limits section](../../../Drive_Folder_Music_Player_Brainstorm.md#v01-recursive-scan-boundary-and-limits)**. They are provisional recommendations grounded in measured successful work and a conservative retry allowance, not accepted final budgets. The missing pagination/resource-key/large-folder evidence prevents T01 acceptance. No other access method is authorized or implemented.

Focused validation: `swift test` passed all 15 tests, including new aggregate-evidence privacy and observed-empty-page regressions. The follow-up smoke binary built, signed and installed on the connected physical iPhone. Testing after the owner's bedtime is silent; Maps/interruptions/lock-screen/legacy-device evidence remains unverified.

Follow-up review: standards found no hard violations or actionable smells; spec review confirmed the three known evidence gaps (live discovery coverage, final budgets, per-stage audibility), with no new code defect. The empty-page fifth field carries page metadata in the observed live response, so the parser intentionally permits that array; it does not imply complete coverage.
