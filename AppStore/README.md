# Mac App Store submission kit

LocalioBC **1.2.0 (6)** is submitted and waiting for review as a one-time paid Mac App Store app at **EUR 4.99**. The product positioning is **simple, quick video cropping**, with trimming, compression and batch export as supporting features. The public GitHub/direct edition remains free. Store builds do not claim to be free and contain no GitHub link.

## Current submission

**Verified in App Store Connect on 15 November 2026 at 00:39 CET (Europe/Prague):** version **1.2.0 (6)** is **Waiting for Review**, submitted at 00:38 CET. The owner authorized replacing the pending 1.0.0 (3) submission. The new package was delivered through Transporter, processed and selected; English/Czech descriptions, six screenshots and reviewer notes now reflect 1.2.0. Release remains manual after approval. The free direct edition 1.2.0 (6) is already published.

The outdated Paid Apps Agreement initially blocked submission. It was updated with explicit owner approval and verified Active; submission then succeeded. The separate DAC7 account item remains Missing Info. See [current status and next steps](STATUS.md). Private identifiers and account URLs remain in ignored `SubmissionStatus.local.json`.

## Submitted 1.2.0 artifacts

- `dist/app-store-1.2.0-build6/export/LocalioBC.pkg`: signed Mac App Store upload package.
- `dist/app-store-1.2.0-build6/LocalioBC-1.2.0-6.xcarchive`: universal archive with symbols for Xcode Organizer.
- `dist/app-store-1.2.0-build6/export/SHA256SUMS.txt`: package checksum.
- `metadata/en-US/` and `metadata/cs/`: ready-to-paste name, subtitle, description, promotional text, keywords, first-release notes and URLs.
- `screenshots/en-US/` and `screenshots/cs/`: three screenshots per language, PNG, **1280 × 800**, RGB without alpha. Upload in numbered order. Raw captures are ignored by Git.
- `assets/icon-1024.png`: source icon. Xcode bundles the macOS AppIcon asset automatically.
- `review/notes-en.txt` and `review/demo-clips.zip`: reviewer instructions and original demo footage.
- `PRIVACY-AND-COMPLIANCE.md`: prepared privacy, age-rating, content-rights and encryption answers.
- `submission.json`: structured common fields and the remaining account-side steps.
- `ReviewContact.local.json`: complete private App Review contact, excluded from Git. Never add this file to a public release or public website.

The exported `.pkg` is for App Store Connect/Transporter, not direct installation by customers. Use the existing notarized GitHub DMG for direct distribution. App Store signing/provisioning and Apple's review are separate from Developer ID notarization.

## Store account configuration

Use the existing Localio Labs s.r.o. team **4RY8J45UR3**. Register/select the explicit macOS App ID **com.localiobvideo.app**, then create or select its App Store Connect app record:

| Field | Prepared value |
| --- | --- |
| Platform | macOS |
| Name | LocalioBC |
| Primary language | English (US), with Czech localization |
| SKU | LOCALIOBC-MAC-001 |
| Bundle ID | com.localiobvideo.app |
| Version/build | 1.2.0 / 6 |
| Primary category | Photo & Video |
| macOS requirement | 14.0 or later |
| Devices | Apple Silicon and Intel Macs |
| Monetization | Paid upfront, one-time purchase; no IAP/subscription |
| Release | Manual release after approval |

For future submissions, the Account Holder must confirm active developer membership, the **Paid Apps Agreement**, bank/tax details and EU trader information; the current verified state and remaining DAC7 item are recorded in `STATUS.md`. These account/legal actions are not automatically accepted by the build scripts. Enter the private review contact from `ReviewContact.local.json`; no demo account is needed.

## Set the EUR 4.99 price

In Pricing and Availability, choose an EUR base storefront (suggested: **Germany**) and select **EUR 4.99**. Review the entire generated price table before confirming. Other currencies use Apple's local equivalents; do not interpret EUR 4.99 as the same numeric price in CZK or USD. Confirm the EUR storefronts show the intended price and choose the required availability regions. No subscription or in-app purchase product needs to be created.

Pricing is saved in App Store Connect: Germany EUR 4.99, with Apple-generated equivalents (Czech Republic CZK 99). The store listing must not claim the App Store download is free.

## Upload and submit a future Store build

1. Confirm the live marketing/support/privacy URLs in `metadata/` are publicly accessible over HTTPS, without sign-in.
2. Create and validate a fresh `LocalioBC-AppStore` archive/package for the intended version/build (current source: 1.2.0 / 6). Open it in Xcode Organizer and choose Distribute App → App Store Connect, or upload the exported `.pkg` with Apple's Transporter. Use the Localio Labs team. The existing `dist/app-store-final` package is the historical 1.0.0 (3) upload, not 1.2.0.
3. Wait for Apple processing. Resolve validation issues, then select the matching build for the macOS version. If replacing a pending submission, remove that version from review first as required by App Store Connect. A successful local export does not mean a build was uploaded, reviewed or approved.
4. Update the English and Czech metadata, screenshots and review notes for the intended release before uploading them. The current kit describes the submitted 1.2.0 feature set. First-release notes are retained in `whats_new.txt`; Apple did not expose a What’s New field for this first Store release, so the descriptions and reviewer notes carry the feature details.
5. Select Data Not Collected and enter the localized privacy URLs. Complete the current age-rating and export-compliance questionnaires using `PRIVACY-AND-COMPLIANCE.md` as the source-specific preparation.
6. Paste the reviewer notes, attach `review/demo-clips.zip`, set Sign-in required to No and enter the private contact.
7. Confirm price, regions, copyright, content rights, company/trader information and manual release. Submit for review after checking all required fields.
8. Release manually after Apple approval. Replace the website's coming-soon text with the actual App Store link only when available.

The scripts do not upload or submit automatically. The current package was uploaded through Transporter and submitted through App Store Connect on November 15, 2026. Public Store release remains pending review and manual release.

## Rebuild and validate

Xcode 26.3 was used for this preparation. Automatic signing is configured for the Localio Labs team; Xcode archives with a managed development identity and re-signs for App Store distribution during export. Required Store/installer profiles and certificates are managed by Xcode when the signed-in account permits it. Secrets remain in the Keychain/Xcode account, not this repository.

```sh
python3 Scripts/validate-app-store.py --check-live-urls  # current 1.2.0 listing kit
bash Scripts/build-app-store.sh dist/app-store-1.2.0-build6-rebuild
```

Use a new output directory on each build. `RELEASE_VERSION` and `BUILD_NUMBER` can override the defaults read from the `LocalioBC-AppStore` target (currently **1.2.0 and 6**). To reproduce the historical submission, explicitly set `RELEASE_VERSION=1.0.0 BUILD_NUMBER=3` and use the matching historical source; changing version strings alone does not reproduce that binary. The pre-export validator uses `--store-archive` because an automatically development-signed archive may lack an embedded profile; exported package validation always requires the distribution profile. Both phases check updater isolation. The script verifies both CPU architectures, package signing, the packaged app's strict signature, sandbox/file grants, disabled debugger attachment, embedded profile, bundled privacy manifest/license and SHA-256. It never uploads or submits review.

```sh
xcodebuild -project LocalioBC.xcodeproj -scheme LocalioBC \
  -configuration Debug -derivedDataPath /tmp/localiobc-store-tests \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 30 \
  -maximum-test-execution-time-allowance 60 test
```

The signed App Store package and developer archive are generated locally and ignored by Git. The shipping Store archive contains no screenshot fixtures or extra test entitlements. A separate ad-hoc Store-configuration preview with an isolated bundle identifier was used for current native screenshots, import, speed and crop UI checks. Historical 1.0.0 smoke testing also verified separate file export; see the 1.2.0 validation report for the current shared regression suite.

## Reproduce screenshot artwork

Import the original demo clips in the Store-configuration preview build and capture the editor, pending 9:16 crop, and separate export in each language. Capture only the app window using the native UI tool; place originals in `screenshots/raw/{en,cs}-{editor,crop,export}.png`. The app window is 1180 × 760 logical points. Move the pointer to the native title bar before capture. Restore language to Follow system afterwards.

```sh
swiftc Scripts/build-store-screenshots.swift -o /tmp/localiobc-build-store-screenshots
/tmp/localiobc-build-store-screenshots
```

The compositor preserves the actual app UI, excludes the native title bar/screen-sharing indicator, and adds localized marketing headings. It does not draw fake controls or change video content. All output screenshots are 16:10, 1280 × 800 RGB PNGs.

## Apple references

- [App Store provisioning](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile/)
- [Screenshot sizes](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Pricing](https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/)
- [App privacy](https://developer.apple.com/app-store/app-privacy-details/)
- [Current submission requirements](https://developer.apple.com/news/upcoming-requirements/)
