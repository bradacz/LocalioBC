#!/bin/bash
# Build a universal, signed release and a branded drag-to-Applications DMG.
# Prerequisites: Xcode, a Python venv with Scripts/requirements-dmg.txt installed.
# Optional NOTARY_PROFILE is the name of a notarytool profile in the Keychain.
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="${1:-$project_dir/dist}"
identity="${SIGN_IDENTITY:--}"
dmgbuild_bin="${DMGBUILD_BIN:-dmgbuild}"
# Xcode resolves the version from MARKETING_VERSION when building.
version="${RELEASE_VERSION:-1.0.0}"
timestamp_flag="--timestamp"
if [[ "$identity" == "-" ]]; then timestamp_flag="--timestamp=none"; fi
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
dmg="$output_dir/LocalioBC-$version-universal.dmg"
if [[ -e "$dmg" ]]; then
    echo "Refusing to overwrite existing release: $dmg" >&2
    exit 1
fi
task_tmp="$(mktemp -d "${TMPDIR:-/tmp}/LocalioBC-release.XXXXXX")"
verification_mount=""
cleanup() {
    if [[ -n "$verification_mount" ]]; then /usr/bin/hdiutil detach "$verification_mount" >/dev/null 2>&1 || true; fi
    rm -rf "$task_tmp"
}
trap cleanup EXIT

xcodebuild -project "$project_dir/LocalioBC.xcodeproj" -scheme LocalioBC \
    -configuration Release -derivedDataPath "$task_tmp/build" \
    ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO MARKETING_VERSION="$version" \
    CODE_SIGN_IDENTITY="$identity" DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}" \
    ENABLE_HARDENED_RUNTIME=YES OTHER_CODE_SIGN_FLAGS="$timestamp_flag" build \
    > "$output_dir/build.log" 2>&1
app="$task_tmp/build/Build/Products/Release/LocalioBC.app"
/usr/bin/lipo "$app/Contents/MacOS/LocalioBC" -verify_arch arm64 x86_64
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app"
/usr/bin/codesign --display --entitlements :- "$app" > "$task_tmp/entitlements.plist" 2>/dev/null
python3 -c 'import plistlib,sys; d=plistlib.load(open(sys.argv[1], "rb")); assert not d.get("com.apple.security.get-task-allow"), "Release must not allow debugger attachment"' "$task_tmp/entitlements.plist"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    /usr/bin/ditto -c -k --keepParent "$app" "$task_tmp/LocalioBC.zip"
    xcrun notarytool submit "$task_tmp/LocalioBC.zip" --keychain-profile "$NOTARY_PROFILE" \
        --wait --output-format json > "$output_dir/notarization-app.json"
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("status")=="Accepted", d' "$output_dir/notarization-app.json"
    xcrun stapler staple "$app"
    xcrun stapler validate "$app"
fi

swift "$project_dir/Scripts/generate-dmg-background.swift" "$task_tmp/background.png"
"$dmgbuild_bin" -s "$project_dir/Scripts/dmg-settings.py" \
    -D "app=$app" -D "background=$task_tmp/background.png" "LocalioBC $version" "$dmg"
if [[ "$identity" != "-" ]]; then
    /usr/bin/codesign --sign "$identity" --timestamp "$dmg"
    /usr/bin/codesign --verify --verbose=2 "$dmg"
fi
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" \
        --wait --output-format json > "$output_dir/notarization-dmg.json"
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("status")=="Accepted", d' "$output_dir/notarization-dmg.json"
    xcrun stapler staple "$dmg"
    xcrun stapler validate "$dmg"
fi
/usr/bin/hdiutil verify "$dmg"
# Verify the packaged app too: packaging must not mutate its signed bundle.
verification_mount="$task_tmp/verify-volume"
mkdir -p "$verification_mount"
/usr/bin/hdiutil attach -readonly -nobrowse -mountpoint "$verification_mount" "$dmg" >/dev/null
/usr/bin/codesign --verify --deep --strict --verbose=2 "$verification_mount/LocalioBC.app"
/usr/bin/lipo "$verification_mount/LocalioBC.app/Contents/MacOS/LocalioBC" -verify_arch arm64 x86_64
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun stapler validate "$verification_mount/LocalioBC.app"
    /usr/sbin/spctl --assess --type execute --verbose=2 "$verification_mount/LocalioBC.app"
    /usr/sbin/spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
fi
/usr/bin/hdiutil detach "$verification_mount" >/dev/null
verification_mount=""
(cd "$output_dir" && /usr/bin/shasum -a 256 "$(basename "$dmg")" > SHA256SUMS.txt)
echo "Created $dmg"
