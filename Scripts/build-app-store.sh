#!/bin/bash
# Archive and export locally for App Store Connect. Never uploads or submits review.
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="${1:-$project_dir/dist/app-store}"
version="${RELEASE_VERSION:-1.0.0}"
build_number="${BUILD_NUMBER:-3}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
archive="$output_dir/LocalioBC-$version-$build_number.xcarchive"
if [[ -e "$archive" || -e "$output_dir/export/LocalioBC.pkg" ]]; then
    echo "Choose a new output directory to preserve existing release artifacts." >&2
    exit 1
fi
xcodebuild -project "$project_dir/LocalioBC.xcodeproj" -scheme LocalioBC-AppStore \
    -configuration AppStore -destination 'generic/platform=macOS' \
    -archivePath "$archive" MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build_number" \
    ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO -allowProvisioningUpdates archive \
    > "$output_dir/archive.log" 2>&1
app="$archive/Products/Applications/LocalioBC.app"
lipo "$app/Contents/MacOS/LocalioBC" -verify_arch arm64 x86_64
plutil -lint "$app/Contents/Resources/PrivacyInfo.xcprivacy"
test -s "$app/Contents/Resources/LICENSE"
xcodebuild -exportArchive -archivePath "$archive" -exportPath "$output_dir/export" \
    -exportOptionsPlist "$project_dir/AppStore/ExportOptions.plist" -allowProvisioningUpdates \
    > "$output_dir/export.log" 2>&1
pkg="$output_dir/export/LocalioBC.pkg"
pkgutil --check-signature "$pkg" > "$output_dir/package-signature.txt"
verification_dir="$(mktemp -d "${TMPDIR:-/tmp}/LocalioBC-store-check.XXXXXX")"
trap 'rm -rf "$verification_dir"' EXIT
pkgutil --expand-full "$pkg" "$verification_dir/expanded"
packaged_app="$verification_dir/expanded/com.localiobvideo.app.pkg/Payload/LocalioBC.app"
codesign --verify --deep --strict --verbose=2 "$packaged_app"
lipo "$packaged_app/Contents/MacOS/LocalioBC" -verify_arch arm64 x86_64
codesign --display --entitlements :- "$packaged_app" > "$verification_dir/entitlements.plist" 2>/dev/null
python3 - "$verification_dir/entitlements.plist" "$packaged_app" <<'PY'
import plistlib, sys
from pathlib import Path
entitlements = plistlib.loads(Path(sys.argv[1]).read_bytes())
assert entitlements.get('com.apple.security.app-sandbox') is True
assert entitlements.get('com.apple.security.files.user-selected.read-write') is True
assert not entitlements.get('com.apple.security.get-task-allow')
app = Path(sys.argv[2])
assert (app / 'Contents/embedded.provisionprofile').is_file()
assert (app / 'Contents/Resources/LICENSE').is_file()
manifest = plistlib.loads((app / 'Contents/Resources/PrivacyInfo.xcprivacy').read_bytes())
assert manifest['NSPrivacyTracking'] is False
assert not manifest['NSPrivacyCollectedDataTypes']
print('Packaged application: sandbox, entitlements, provisioning, privacy and license OK')
PY
(cd "$output_dir/export" && shasum -a 256 LocalioBC.pkg > SHA256SUMS.txt)
echo "Prepared App Store archive: $archive"
echo "Prepared upload package: $pkg"
echo 'No upload or review submission was performed.'
