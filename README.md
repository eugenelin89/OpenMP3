# OpenMP3 v0.2 experimental player

A native iPhone player for MP3s in public Google Drive folders. **No API key, OAuth or backend.** Anonymous discovery remains experimental. Successful scans show neutral “Scan finished” with a separate coverage notice; observed partial failures remain incomplete. [T01 evidence](docs/evidence/t01/RESULTS.md) and [integrated prototype evidence](docs/evidence/overnight/RESULTS.md) distinguish verified results from open gates.

The normal app opens the dark player. Load a public folder, silently choose a ready track with Next/Previous, then press Play at the top. A new nonempty scan during playback becomes Up Next: the current song continues until its natural end or explicit Next. Paused Next stays paused. Individual track taps start immediately and supersede older scan intent. Cached-folder browsing stays passive. Saved folders and the active queue have separate sheets. Audio streaming uses cellular data when available.

Run `python3 scripts/generate_probe_project.py` to create the disposable Xcode project and generated app configuration. The generator reads the canonical platform and scan controls from the living brainstorm; regenerate after changing them. Open the generated project under `ProbeApp/` and select your existing development team/device. If Xcode destination components are unavailable, the direct SDK build below uses an existing compatible profile without creating credentials.

For an Apple Silicon simulator with an installed iOS runtime, run `python3 scripts/build_simulator.py`, then install `.build/simulator/OpenMP3Probe.app` with `simctl`. `scripts/build_device_probe.py` builds the same source for an iPhone using the existing profile/identity arguments described below. The historical bundle identifier is retained so the prototype updates the feasibility harness in place. Normal launch is silent. Set `OPENMP3_PROBE=1` to open the retained manual harness; automated audio smoke remains explicitly opt-in.

Focused validation: `swift test`. No dependency downloads are required. Saved links remain local; collections/queue/position/modes are session-only. No fixture links or personal music metadata should be committed. [v0.2 evidence](docs/evidence/v205/RESULTS.md) separates automated checks, simulator observations, physical visual/timing checks, owner-confirmed audibility, and outstanding remote/VoiceOver acceptance. The prerequisite and v0.2 PR stack is merged; [post-merge verification](docs/evidence/v02-merge/RESULTS.md) records the integrated checks. Remaining physical checks are unverified; merging does not establish release acceptance.

---

# OpenMP3 feasibility probe (T01)

A small anonymous Google Drive → native AVPlayer experiment for [issue #4](https://github.com/eugenelin89/OpenMP3/issues/4). **The downstream implementation gate remains open.** See the [observed evidence and remaining gaps](docs/evidence/t01/RESULTS.md).

The user's current-version decision is **no API key**. There is no key configuration, OAuth, listener login, backend, or access-control workaround. This overrides the ticket's earlier key-fallback allowance. The probe parses an **undocumented** public Drive webpage payload. V201 separates unverified pagination/resource-key coverage from observed scan failures. Do not mistake the discovered count for a complete library. Historical v0.1 reports retain their original incomplete classifications.

Platform targets live in the [canonical baseline](Drive_Folder_Music_Player_Brainstorm.md#platform-compatibility-baseline-single-source-of-truth). Application scan budgets remain pending in the [canonical scan-limits section](Drive_Folder_Music_Player_Brainstorm.md#v01-recursive-scan-boundary-and-limits).

## Run the network experiment

Requires the installed Apple Swift toolchain; no package dependencies.

```sh
swift test
mkdir -p probe-runs
# Put only your authorized public folder URL into probe-runs/root.txt.
swift run drive-probe --root-file probe-runs/root.txt --output probe-runs/run.json --ranges
```

The URL file and raw artifacts under `probe-runs/` are ignored by Git. The command validates the URL, checks the root, traverses visible actual child folders, skips shortcuts, retains stable identities/relative paths, and records request counts and elapsed time. It never downloads media while scanning. `--ranges` explicitly requests small beginning and nonzero-offset samples of the first two discovered tracks after discovery settles. A range response is **not** native seek or audibility evidence. HTTP observations record status, content type/range, bytes, redirect count and final host, without URLs, resource keys or cookies. Published reports contain only aggregate discovery counts and depths. Raw identities, filenames, paths, resource keys, and deterministic hashes of them are excluded. Preserve any earlier detailed reports locally; do not publish them.

`--requests` and `--seconds` override **temporary experimental controls**, not measured application budgets. Each report records the controls used. Defaults live in `ExperimentControls`: bounded listing work, wall time, per-request/scan-wide retries, and size caps. Transport adds a response-size cap, finite request/resource timeouts and a redirect cap. Root-page validation is counted separately from folder listing; both are within the scan wall-time bound. Media sampling has separate bounds and is excluded from scan time. Never combine those metrics when deriving scan budgets.

Normal command completion means a report was written, **not** that the feasibility gate passed. Read `scan.state`, `reasons`, `coverageNotices` and HTTP observations. The legacy serialized state `complete` means the supported scan finished; it does not certify coverage. A malformed input or local output failure exits with a nonzero status; remote failures are represented as `incomplete` or `failed` in the report.

For deterministic player UI checks, build `python3 scripts/build_simulator.py --player-ui-fixture` and install `.build/player-ui/PlayerFixture.app`. Launch `org.openmp3.PlayerFixture` with `SIMCTL_CHILD_OPENMP3_PLAYER_SCENARIO` set to `empty`, `ready`, or `pending`. This separate synthetic executable uses the production screen/coordinator without network or audible output. The two fixture flags are mutually exclusive.

For deterministic scan-status UI checks, build `python3 scripts/build_simulator.py --scan-ui-fixture` and install `.build/scan-ui/ScanStatusFixture.app` in a simulator. Launch bundle `org.openmp3.ScanStatusFixture` with `SIMCTL_CHILD_OPENMP3_SCAN_SCENARIO` set to `finished`, `empty`, `incomplete`, `incomplete-empty`, or `failed`. This separate executable uses the real player screen and coordinator with synthetic discovery; it has no network or audio output and is excluded from the normal app.

## Run the iPhone probe

```sh
python3 scripts/generate_probe_project.py
open ProbeApp/OpenMP3Probe.xcodeproj
```

Select your development team, connect/unlock a provisioned iPhone, and run the `OpenMP3Probe` scheme. The generated project gets its deployment target from the canonical baseline. It can be regenerated and is ignored by Git. With `OPENMP3_PROBE=1`, the retained harness offers scan/stop, Play All, pause, next, midpoint seek and near-end seek. It displays selected root separately from queue source. Scanning and browsing never start audio; explicitly press Play All. Leaving the foreground stops discovery and leaves an existing native player alive. The retained probe is for evidence capture. The normal player now implements native background/remote/interruption wiring, but physical navigation acceptance remains unverified.

1. Paste an authorized folder link and scan. Inspect paths/counts and incomplete reasons.
2. Press Play All and listen for the first track. Note device, OS, network and audio route.
3. Seek to the midpoint and confirm audible continuation at the new position.
4. Seek near the end, then **wait** for natural transition. Verify the second track audibly; pressing Next does not prove natural transition.
5. Record pass/fail/not tested in the observation pickers, then Copy evidence. Native timing events and human audio observations are separate.
6. Test manual Next independently, then pause. Repeat after cold launch and on another network when available.

For an opt-in automated real-player run, launch with `OPENMP3_ROOT_URL` containing your public root and `OPENMP3_RUN_SMOKE=1`. This **will play audio**. It scans, waits for first-item progress, seeks to midpoint, seeks near end, waits for natural second-item progress, and pauses. The native procedure is time-bounded and writes `Documents/smoke.txt` in the app container. Human audibility remains `not tested` until confirmed. Normal launches do not autorun or restore a queue. Do not interact with the app during an automated run; it is an experiment harness, not a finished transport UI.

If Xcode reports that its device platform components are unavailable but the iOS SDK and an existing compatible development profile are installed, the tested alternative is:

```sh
python3 scripts/build_device_probe.py --profile /absolute/path/to/development.mobileprovision --identity YOUR_SIGNING_IDENTITY
xcrun devicectl list devices
xcrun devicectl device install app --device YOUR_DEVICE .build/device/OpenMP3Probe.app
xcrun devicectl device process launch --device YOUR_DEVICE org.openmp3.FeasibilityProbe
```

This script builds against the installed iOS SDK and signs only the local probe with the supplied existing profile. It does not register devices or create credentials. You must use a profile covering your device and the probe bundle identifier. Retrieve an automated result with:

```sh
xcrun devicectl device copy from --device YOUR_DEVICE --domain-type appDataContainer --domain-identifier org.openmp3.FeasibilityProbe --source Documents/smoke.txt --destination probe-runs/device-smoke.txt
```

## Reproduce the next evidence step

Only use fixtures you own or are authorized to access. Do not modify the supplied music library for testing. In a separate authorized test tree, place MP3s at root, child and grandchild levels, duplicate filenames with different IDs, TXT/JPG entries, shortcuts and an inaccessible descendant where feasible. Keep a private manifest of expected identities and paths. Also prepare a representative non-audio-heavy folder large enough to exercise paging. Do not artificially drive Google into quota errors; record any naturally observed quota responses and use substitutes for deliberate retry/failure tests.

Run small bounded trials with recorded controls, compare expected versus discovered identities/paths, repeat after restart and on another network, and examine missing rows/continuations before increasing bounds. Preserve root-resource-key cases and download-restricted files as separate access checks; never remove restrictions to make a test pass. Record all failure modes and explicitly untested cases. Once representative real coverage and native playback are established, derive numeric work budgets **only in the canonical scan-limits section** with measurement rationale. Until then, keep T01 and downstream gates open.

Automated behavioral tests drive `ProbeApplication`, the approved application seam, with controlled Drive, audio and time dependencies. They cover discovery, boundaries, queue source separation, seek/end events and errors. They do not prove Google integration or physical audio. The retained harness is separate from the normal player. The provisional player adds saved roots, shuffle/repeat and remote integration; optional playlists remain deferred.
