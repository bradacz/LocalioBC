#!/bin/bash
# Archive and export locally for App Store Connect. Never uploads or submits review.
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="${1:-$project_dir/dist/app-store}"
version="${RELEASE_VERSION:-$(python3 "$project_dir/Scripts/read-release-version.py" LocalioBC-AppStore AppStore MARKETING_VERSION)}"
build_number="${BUILD_NUMBER:-$(python3 "$project_dir/Scripts/read-release-version.py" LocalioBC-AppStore AppStore CURRENT_PROJECT_VERSION)}"
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
python3 "$project_dir/Scripts/validate-release-app.py" store "$app" --version "$version" --build "$build_number" --store-archive
xcodebuild -exportArchive -archivePath "$archive" -exportPath "$output_dir/export" \
    -exportOptionsPlist "$project_dir/AppStore/ExportOptions.plist" -allowProvisioningUpdates \
    > "$output_dir/export.log" 2>&1
pkg="$output_dir/export/LocalioBC.pkg"
pkgutil --check-signature "$pkg" > "$output_dir/package-signature.txt"
verification_dir="$(mktemp -d "${TMPDIR:-/tmp}/LocalioBC-store-check.XXXXXX")"
trap 'rm -rf "$verification_dir"' EXIT
pkgutil --expand-full "$pkg" "$verification_dir/expanded"
packaged_app="$verification_dir/expanded/com.localiobvideo.app.pkg/Payload/LocalioBC.app"
python3 "$project_dir/Scripts/validate-release-app.py" store "$packaged_app" --version "$version" --build "$build_number"
(cd "$output_dir/export" && shasum -a 256 LocalioBC.pkg > SHA256SUMS.txt)
echo "Prepared App Store archive: $archive"
echo "Prepared upload package: $pkg"
echo 'No upload or review submission was performed.'
