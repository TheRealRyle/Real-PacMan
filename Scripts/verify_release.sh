#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
archive_path="${1:-/private/tmp/RealPacman-Release/RealPacman-1.0.xcarchive}"
if [[ "${2:-}" != "--verify-only" ]]; then
  xcodebuild -project 'Real Pacman.xcodeproj' -scheme 'Real Pacman' \
    -configuration Release -destination 'generic/platform=iOS' \
    -derivedDataPath /private/tmp/realpacman-release-device \
    -archivePath "$archive_path" CODE_SIGNING_ALLOWED=NO archive
fi
python3 - "$archive_path/Products/Applications/Real Pacman.app" <<'PY'
from pathlib import Path
import plistlib, sys
bundle = Path(sys.argv[1])
info = plistlib.loads((bundle/'Info.plist').read_bytes())
manifest = plistlib.loads((bundle/'PrivacyInfo.xcprivacy').read_bytes())
assert info['CFBundleIdentifier'] == 'coconut-factory.Real-Pacman'
assert info['CFBundleIcons']['CFBundlePrimaryIcon']['CFBundleIconName'] == 'AppIcon'
assert info['NSLocationWhenInUseUsageDescription']
assert 'NSLocationAlwaysAndWhenInUseUsageDescription' not in info
ats = info.get('NSAppTransportSecurity', {})
assert not ats.get('NSAllowsArbitraryLoads', False)
assert not ats.get('NSAllowsLocalNetworking', False)
assert 'location' not in info.get('UIBackgroundModes', [])
assert manifest['NSPrivacyTracking'] is False
assert any(x['NSPrivacyAccessedAPIType'] == 'NSPrivacyAccessedAPICategoryUserDefaults'
           and 'CA92.1' in x['NSPrivacyAccessedAPITypeReasons'] for x in manifest['NSPrivacyAccessedAPITypes'])
assert (bundle/'Frameworks/MapLibre.framework/PrivacyInfo.xcprivacy').exists()
assert manifest == plistlib.loads(Path('Real Pacman/PrivacyInfo.xcprivacy').read_bytes()), 'Archive privacy manifest is stale'
print('PASS: Release icon, current privacy manifests, foreground location and HTTPS settings')
print('Version:', info['CFBundleShortVersionString'], 'Build:', info['CFBundleVersion'])
print('Unsigned archive verified. Install through Xcode with your signing team.')
PY
