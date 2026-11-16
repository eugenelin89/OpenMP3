#!/usr/bin/env python3
"""Build the same source tree for a locally installed Apple Silicon iOS simulator."""
import plistlib
import argparse
import re
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--scan-ui-fixture', action='store_true', help='Build the isolated V201 scan-status fixture app')
args = parser.parse_args()
subprocess.run(['python3', str(root / 'scripts/generate_probe_project.py')], check=True)
minimum = re.search(r'Minimum supported OS / Xcode deployment target:\*\* \*\*iOS ([\d.]+)', (root / 'Drive_Folder_Music_Player_Brainstorm.md').read_text()).group(1)
out = root / ('.build/scan-ui/ScanStatusFixture.app' if args.scan_ui_fixture else '.build/simulator/OpenMP3Probe.app')
out.mkdir(parents=True, exist_ok=True)
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
app_sources = ([root / 'ProbeApp/PlayerScreen.swift', root / 'Tests/ScanStatusUI/ScanStatusFixtureApp.swift']
               if args.scan_ui_fixture else sorted((root / 'ProbeApp').glob('*.swift')))
subprocess.run(['xcrun', '--sdk', 'iphonesimulator', 'swiftc', '-parse-as-library', '-target', 'arm64-apple-ios' + minimum + '-simulator',
                '-sdk', sdk, '-module-cache-path', str(root / '.build/simulator-module-cache'),
                *map(str, sorted((root / 'Sources/ProbeCore').glob('*.swift'))),
                *map(str, app_sources), '-o', str(out / 'OpenMP3Probe')], check=True)
info = plistlib.loads((root / 'ProbeApp/GeneratedInfo.plist').read_bytes())
info.update(CFBundleExecutable='OpenMP3Probe', CFBundleIdentifier='org.openmp3.FeasibilityProbe', MinimumOSVersion=minimum,
            CFBundleSupportedPlatforms=['iPhoneSimulator'], UIDeviceFamily=[1])
if args.scan_ui_fixture:
    info.update(CFBundleIdentifier='org.openmp3.ScanStatusFixture', CFBundleDisplayName='Scan Status Fixture')
(out / 'Info.plist').write_bytes(plistlib.dumps(info))
subprocess.run(['codesign', '--force', '--sign', '-', str(out)], check=True)
print(out)
