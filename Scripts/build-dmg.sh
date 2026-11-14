#!/bin/bash
# Archive/export a universal Developer ID release and a branded installation DMG.
# Prerequisites: Xcode, SIGN_IDENTITY, and Scripts/requirements-dmg.txt installed.
# NOTARY_PROFILE names an existing notarytool profile in the Keychain.
# Sign the final stapled DMG with Sparkle only after this script completes.
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="${1:-$project_dir/dist}"
identity="${SIGN_IDENTITY:?Set SIGN_IDENTITY to your Developer ID Application identity}"
team="${DEVELOPMENT_TEAM:-4RY8J45UR3}"
dmgbuild_bin="${DMGBUILD_BIN:-dmgbuild}"
source_packages="${SOURCE_PACKAGES_DIR:-$project_dir/build/SourcePackages}"
version="${RELEASE_VERSION:-$(python3 "$project_dir/Scripts/read-release-version.py" LocalioBC Release MARKETING_VERSION)}"
build_number="${BUILD_NUMBER:-$(python3 "$project_dir/Scripts/read-release-version.py" LocalioBC Release CURRENT_PROJECT_VERSION)}"
if [[ "$identity" == "-" ]]; then
    echo 'Distributable releases require a Developer ID Application identity.' >&2
    exit 1
fi
mkdir -p "$output_dir" "$source_packages"
output_dir="$(cd "$output_dir" && pwd)"
source_packages="$(cd "$source_packages" && pwd)"
dmg="$output_dir/LocalioBC-$version-universal.dmg"
archive="$output_dir/LocalioBC-$version-$build_number.xcarchive"
if [[ -e "$dmg" || -e "$archive" || -e "$output_dir/export/LocalioBC.app" ]]; then
    echo "Choose a new output directory to preserve existing release artifacts." >&2
    exit 1
fi
task_tmp="$(mktemp -d "${TMPDIR:-/tmp}/LocalioBC-release.XXXXXX")"
verification_mount=""
cleanup() {
    if [[ -n "$verification_mount" ]]; then /usr/bin/hdiutil detach "$verification_mount" >/dev/null 2>&1 || true; fi
    rm -rf "$task_tmp"
}
trap cleanup EXIT
# A real Archive/Developer ID export re-signs Sparkle's nested helpers correctly.
xcodebuild -project "$project_dir/LocalioBC.xcodeproj" -scheme LocalioBC \
    -configuration Release -destination 'generic/platform=macOS' \
    -archivePath "$archive" -derivedDataPath "$task_tmp/build" \
    -clonedSourcePackagesDirPath "$source_packages" -onlyUsePackageVersionsFromResolvedFile \
    ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build_number" \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$identity" DEVELOPMENT_TEAM="$team" \
    ENABLE_HARDENED_RUNTIME=YES OTHER_CODE_SIGN_FLAGS='--timestamp' archive \
    > "$output_dir/archive.log" 2>&1
python3 - "$project_dir/Scripts/ExportOptions-DeveloperID.plist" "$task_tmp/ExportOptions.plist" "$identity" "$team" <<'PY'
import plistlib, sys
from pathlib import Path
options = plistlib.loads(Path(sys.argv[1]).read_bytes())
options['signingCertificate'] = sys.argv[3]
options['teamID'] = sys.argv[4]
Path(sys.argv[2]).write_bytes(plistlib.dumps(options))
PY
xcodebuild -exportArchive -archivePath "$archive" -exportPath "$output_dir/export" \
    -exportOptionsPlist "$task_tmp/ExportOptions.plist" > "$output_dir/export.log" 2>&1
app="$output_dir/export/LocalioBC.app"
python3 "$project_dir/Scripts/validate-release-app.py" direct "$app" --version "$version" --build "$build_number"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$task_tmp/LocalioBC.zip"
    xcrun notarytool submit "$task_tmp/LocalioBC.zip" --keychain-profile "$NOTARY_PROFILE" \
        --wait --output-format json > "$output_dir/notarization-app.json"
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("status")=="Accepted", d' "$output_dir/notarization-app.json"
    xcrun stapler staple "$app"
    xcrun stapler validate "$app"
fi

swift "$project_dir/Scripts/generate-dmg-background.swift" "$task_tmp/background.png"
"$dmgbuild_bin" -s "$project_dir/Scripts/dmg-settings.py" \
    -D "app=$app" -D "background=$task_tmp/background.png" "LocalioBC $version" "$dmg"
/usr/bin/codesign --sign "$identity" --timestamp "$dmg"
/usr/bin/codesign --verify --verbose=2 "$dmg"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" \
        --wait --output-format json > "$output_dir/notarization-dmg.json"
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("status")=="Accepted", d' "$output_dir/notarization-dmg.json"
    xcrun stapler staple "$dmg"
    xcrun stapler validate "$dmg"
fi
/usr/bin/hdiutil verify "$dmg"
verification_mount="$task_tmp/verify-volume"
mkdir -p "$verification_mount"
/usr/bin/hdiutil attach -readonly -nobrowse -mountpoint "$verification_mount" "$dmg" >/dev/null
python3 "$project_dir/Scripts/validate-release-app.py" direct "$verification_mount/LocalioBC.app" --version "$version" --build "$build_number"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun stapler validate "$verification_mount/LocalioBC.app"
    /usr/sbin/spctl --assess --type execute --verbose=2 "$verification_mount/LocalioBC.app"
    /usr/sbin/spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
fi
/usr/bin/hdiutil detach "$verification_mount" >/dev/null
verification_mount=""
(cd "$output_dir" && /usr/bin/shasum -a 256 "$(basename "$dmg")" > SHA256SUMS.txt)
echo "Created $dmg"
echo 'The final DMG is ready for Sparkle signing; do not modify it after signing.'
