#!/usr/bin/env python3
"""Build the same source tree for a locally installed Apple Silicon iOS simulator."""
import plistlib
import re
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
subprocess.run(['python3', str(root / 'scripts/generate_probe_project.py')], check=True)
minimum = re.search(r'Minimum supported OS / Xcode deployment target:\*\* \*\*iOS ([\d.]+)', (root / 'Drive_Folder_Music_Player_Brainstorm.md').read_text()).group(1)
out = root / '.build/simulator/OpenMP3Probe.app'
out.mkdir(parents=True, exist_ok=True)
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
subprocess.run(['xcrun', '--sdk', 'iphonesimulator', 'swiftc', '-parse-as-library', '-target', 'arm64-apple-ios' + minimum + '-simulator',
                '-sdk', sdk, '-module-cache-path', str(root / '.build/simulator-module-cache'),
                *map(str, sorted((root / 'Sources/ProbeCore').glob('*.swift'))),
                *map(str, sorted((root / 'ProbeApp').glob('*.swift'))), '-o', str(out / 'OpenMP3Probe')], check=True)
info = plistlib.loads((root / 'ProbeApp/GeneratedInfo.plist').read_bytes())
info.update(CFBundleExecutable='OpenMP3Probe', CFBundleIdentifier='org.openmp3.FeasibilityProbe', MinimumOSVersion=minimum,
            CFBundleSupportedPlatforms=['iPhoneSimulator'], UIDeviceFamily=[1])
(out / 'Info.plist').write_bytes(plistlib.dumps(info))
subprocess.run(['codesign', '--force', '--sign', '-', str(out)], check=True)
print(out)
