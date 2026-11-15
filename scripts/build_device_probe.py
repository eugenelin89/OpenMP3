#!/usr/bin/env python3
"""Direct SDK build for the spike when Xcode destination components are unavailable.

The caller supplies an existing development profile and signing identity. No account,
profile, certificate, or device registration is created or changed by this script.
"""
import argparse
import plistlib
import re
import shutil
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--profile', required=True, type=Path)
parser.add_argument('--identity', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
subprocess.run(['python3', str(root / 'scripts/generate_probe_project.py')], check=True)
profile = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i', str(args.profile)]))
bundle = 'org.openmp3.FeasibilityProbe'
team = profile['TeamIdentifier'][0]
identifier = profile['Entitlements']['application-identifier']
if identifier not in [team + '.*', team + '.' + bundle] or not profile['Entitlements'].get('get-task-allow'):
    raise SystemExit('An existing compatible development profile is required.')
out = root / '.build/device/OpenMP3Probe.app'
out.mkdir(parents=True, exist_ok=True)
minimum = re.search(r'Minimum supported OS / Xcode deployment target:\*\* \*\*iOS ([\d.]+)', (root / 'Drive_Folder_Music_Player_Brainstorm.md').read_text()).group(1)
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphoneos', '--show-sdk-path'], text=True).strip()
subprocess.run(['xcrun', '--sdk', 'iphoneos', 'swiftc', '-parse-as-library', '-target', 'arm64-apple-ios' + minimum,
                '-sdk', sdk, '-module-cache-path', str(root / '.build/ios-module-cache'),
                *map(str, sorted((root / 'Sources/ProbeCore').glob('*.swift'))),
                *map(str, sorted((root / 'ProbeApp').glob('*.swift'))), '-o', str(out / 'OpenMP3Probe')], check=True)
info = plistlib.loads((root / 'ProbeApp/GeneratedInfo.plist').read_bytes())
info.update(CFBundleExecutable='OpenMP3Probe', CFBundleIdentifier=bundle, MinimumOSVersion=minimum,
            CFBundleSupportedPlatforms=['iPhoneOS'], UIDeviceFamily=[1])
(out / 'Info.plist').write_bytes(plistlib.dumps(info))
shutil.copyfile(args.profile, out / 'embedded.mobileprovision')
entitlements = dict(profile['Entitlements'])
entitlements['application-identifier'] = team + '.' + bundle
entitlements['keychain-access-groups'] = [team + '.' + bundle]
entitlements_path = root / '.build/device/entitlements.plist'
entitlements_path.write_bytes(plistlib.dumps(entitlements))
subprocess.run(['codesign', '--force', '--sign', args.identity, '--entitlements', str(entitlements_path), str(out)], check=True)
subprocess.run(['codesign', '--verify', '--strict', str(out)], check=True)
print(out)
