# Issue #15: keyboard-safe folder entry

Date: 2026-11-15. Base: PR #14, `0555831`. Status: simulator regression fixed;
core physical-iPhone keyboard checks **passed, owner-confirmed**. Accessibility
text sizes and VoiceOver remain **unverified**.

## Reproduction and cause

Before editing, reproduced the obstruction in the existing returning-user iPhone
16 simulator and a fresh iPhone SE (3rd generation) simulator, iOS 26.5. With the
software keyboard open on the SE, only a thin sliver of the URL field remained
visible and Load was hidden. The normal-text layout kept the large player outside
the collection's scroll view, leaving too little height for the form. It also had
no explicit focus scrolling or keyboard dismissal control.

| Before (unmodified PR #14) | After (final fix) |
| --- | --- |
| ![URL obscured by keyboard](before-se-keyboard.png) | ![Form visible above keyboard](after-se-keyboard.png) |

Both captures show the fresh, empty SE form and contain no personal folder data.

## Change

Use one scroll view for player and collection at every text size. Focus changes
and the keyboard's did-show notification scroll the active field into view.
The name field's Next key focuses the URL; the URL's Done key and a visible
navigation-bar Done button dismiss editing. Load dismisses editing before the
existing validation/scan action. Focus and draft values remain local to the view.
The code uses APIs compatible with the canonical minimum iOS baseline; no new
dependency or access method is introduced.

## Verification

| Check | Result and evidence |
| --- | --- |
| Fresh small viewport, software keyboard | **PASS (simulator):** SE name, URL, and Load remain visible; see after capture. |
| Standard long-press Paste | **PASS (simulator):** copied a synthetic full-length Drive URL with a resource-key query using iOS Select All/Cut, then long-pressed the empty visible URL field and chose Paste with the software keyboard open. Full value appeared and Load enabled. Synthetic URL was not submitted. |
| Optional name and keyboard Next | **PASS (simulator):** typed a name, reopened the software keyboard, and used Next to focus the visible URL field. |
| Done and reopen | **PASS (simulator):** keyboard Done dismisses; final navigation-bar Done dismisses; tapping URL reopens the keyboard with the field visible. |
| Invalid input feedback | **PASS (simulator, final build):** submitting invalid text dismissed the keyboard and displayed “Invalid Google Drive folder link”. |
| Public URL submission, no autoplay | **PASS (simulator, final build):** entered the previously authorized public fixture URL and loaded it; 14 tracks discovered, correctly marked incomplete. Player remained idle with no queue. Personal URL and track metadata omitted. |
| Returning-user form | **PASS (simulator, final build):** after loading the fixture, opened Load another folder and focused URL; name, URL, Load and Done remained visible above the software keyboard. |
| Queue independent of browsing | **PASS (automated core boundary and owner-confirmed physical check):** existing tests verify scanning another root retains the active queue source and playback progression. The owner subsequently confirmed that reopening folder entry while music plays does not interrupt playback; see confirmation below. |
| Automated suite | **PASS:** `swift test`, 23 tests, zero failures. Includes invalid-link parsing, no autoplay, queue separation, saved-root restoration, and player behavior. Rerun during the installed workflow review against final implementation commit `fea05d0`, after the Done-button relocation. |
| Final simulator build | **PASS:** `python3 scripts/build_simulator.py`; installed and exercised on SE simulator, then rebuilt successfully during review of `fea05d0`. |
| Final signed device build/install | **PASS:** `scripts/build_device_probe.py` with the existing local signing configuration; `devicectl` confirmed installation on the paired iPhone 16. |
| Physical iPhone keyboard visibility, Paste, Done → Load | **PASS (owner-confirmed):** URL stays visible above the software keyboard, long-press Paste works, and Done → Load works without autoplay. The original agent check was unavailable because iPhone Mirroring reported the phone in use; the later owner confirmation supplies the physical evidence. |
| Accessibility text sizes and VoiceOver | **UNVERIFIED / NOT TESTED.** Neither the owner confirmation nor the automated tests establishes these checks. Unified scrolling is an implementation observation, not a runtime accessibility pass. |
| Oldest supported iOS runtime | **NOT TESTED:** compilation uses the canonical deployment target, but available simulator runtime was iOS 26.5. |

The visual regression was checked in the actual SwiftUI UI rather than adding a
unit test that merely mirrors view modifiers. Paste/name checks were performed on
the same scrolling/focus implementation before the final Done-button relocation;
the final button and keyboard reopen were then rechecked.

## Owner confirmation and review

The [owner's physical-iPhone verification](https://github.com/eugenelin89/OpenMP3/pull/16#issuecomment-6903960079)
is dated 2026-11-15 (posted 2026-11-16 UTC). It confirms all four requested checks:
URL visibility above the software keyboard, standard long-press Paste,
Done → Load without autoplay, and uninterrupted music while reopening folder
entry. These are owner-reported device observations, distinct from agent-run
simulator and automated checks. They supersede the original unverified status.

The installed Matt Pocock code-review workflow reviewed `0555831...fea05d0` with
independent Standards and Spec reviewers. No required implementation fixes were
found. The duplicated scroll callbacks were an optional improvement; accessibility
coverage remained a nonblocking verification gap. The full suite (23 tests), final
SwiftUI simulator build, and diff whitespace check passed during that review.

## Remaining acceptance and scope

Accessibility-size and VoiceOver checks remain explicitly unverified, as does
runtime compatibility on the oldest supported OS. The owner authorized merging
only PR #16's keyboard fix into its existing `codex/overnight-player` base.
This does not authorize merging PR #14 or closing broader acceptance issues,
and does not resolve or relax T01's feasibility evidence or scan-work budgets.
