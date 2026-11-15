#!/usr/bin/env python3
"""Dependency-free disposable Xcode project; platform baseline remains canonical."""
from pathlib import Path
import hashlib
import re
import plistlib

root = Path(__file__).resolve().parents[1]
baseline = (root / "Drive_Folder_Music_Player_Brainstorm.md").read_text()
minimum = re.search(r"Minimum supported OS / Xcode deployment target:\*\* \*\*iOS ([\d.]+)", baseline).group(1)
project = root / "ProbeApp/OpenMP3Probe.xcodeproj"
project.mkdir(exist_ok=True)
def ident(label):
    return hashlib.sha256(label.encode()).hexdigest()[:24].upper()
objects = []
def obj(label, body):
    objects.append(f"{ident(label)} = {{ {body} }};")
    return ident(label)
sources = sorted((root / "Sources/ProbeCore").glob("*.swift")) + sorted((root / "ProbeApp").glob("*.swift"))
refs, builds = [], []
for path in sources:
    relative = "../" + str(path.relative_to(root))
    ref = obj(str(path), f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{relative}"; sourceTree = "<group>";')
    refs.append(ref)
    builds.append(obj("build" + str(path), f"isa = PBXBuildFile; fileRef = {ref};"))
product = obj("product", 'isa = PBXFileReference; explicitFileType = wrapper.application; path = OpenMP3Probe.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj("group", f'isa = PBXGroup; children = ({",".join(refs + [product])}); sourceTree = "<group>";')
obj("sources", f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)}); runOnlyForDeploymentPostprocessing = 0;')
for name in ["Debug", "Release"]:
    settings = f'''SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = {minimum}; SWIFT_VERSION = 5.0;
    PRODUCT_NAME = OpenMP3Probe; PRODUCT_BUNDLE_IDENTIFIER = org.openmp3.FeasibilityProbe;
    INFOPLIST_FILE = GeneratedInfo.plist; TARGETED_DEVICE_FAMILY = 1; CODE_SIGN_STYLE = Automatic;
    SWIFT_OPTIMIZATION_LEVEL = "{'-Onone' if name == 'Debug' else '-O'}";
    ENABLE_USER_SCRIPT_SANDBOXING = YES;'''
    obj("config" + name, f'isa = XCBuildConfiguration; name = {name}; buildSettings = {{ {settings} }};')
obj("configs", f'isa = XCConfigurationList; buildConfigurations = ({ident("configDebug")},{ident("configRelease")}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;')
obj("target", f'isa = PBXNativeTarget; name = OpenMP3Probe; productName = OpenMP3Probe; productReference = {product}; productType = "com.apple.product-type.application"; buildConfigurationList = {ident("configs")}; buildPhases = ({ident("sources")}); buildRules = (); dependencies = ();')
obj("project", f'isa = PBXProject; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en,Base); mainGroup = {ident("group")}; buildConfigurationList = {ident("configs")}; targets = ({ident("target")}); projectDirPath = ""; projectRoot = "";')
(project / "project.pbxproj").write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(objects) + f'\n}}; rootObject = {ident("project")}; }}\n')
info = dict(CFBundleExecutable="$(EXECUTABLE_NAME)", CFBundleIdentifier="$(PRODUCT_BUNDLE_IDENTIFIER)", CFBundleName="OpenMP3", CFBundleDisplayName="OpenMP3", CFBundlePackageType="APPL", CFBundleShortVersionString="0.1", CFBundleVersion="1", LSRequiresIPhoneOS=True, UILaunchScreen={}, UIBackgroundModes=["audio"], UISupportedInterfaceOrientations=["UIInterfaceOrientationPortrait"])
# Compile app controls from the sole canonical source; do not duplicate product limits here.
def number(pattern):
    match = re.search(pattern, baseline)
    if not match:
        raise SystemExit("Canonical scan limit missing: " + pattern)
    return int(match.group(1).replace(",", ""))
info["OpenMP3ScanControls"] = dict(
    tracks=number(r"Maximum MP3s per root scan:\*\* \*\*([\d,]+)"),
    folders=number(r"Maximum actual folders per root scan:\*\* \*\*([\d,]+)"),
    listingRequests=number(r"Provisional listing-request budget:\*\* \*\*(\d+)"),
    seconds=number(r"Provisional wall-clock budget:\*\* \*\*(\d+)"),
    retriesPerRequest=number(r"Provisional retry budgets:\*\* \*\*(\d+)"),
    totalRetries=number(r"failed request, (\d+) additional attempts across"),
    retryDelay=number(r"scan, with a (\d+)-second delay"))
(root / "ProbeApp/GeneratedInfo.plist").write_bytes(plistlib.dumps(info))
print(project)
