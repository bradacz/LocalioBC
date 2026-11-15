# Mac App Store submission kit

The submitted Store version is **LocalioBC 1.3.0 (9)**, a one-time paid Mac App Store app at **EUR 4.99**, with Apple-generated local prices. It remains a simple, quick solution for video cropping; trimming, compression, speed control and batch export support that workflow. This version adds optional, explicitly initiated uploads of finished exports to the user's own Bunny Storage account.

The owner authorized both distribution channels on 15 November 2026. Transporter delivered build 9 at **04:24 CET**; Apple processed it and accepted the review submission at **04:34 CET**, showing **Waiting for Review**. The Store edition is not yet approved or publicly released and remains manual after approval. The free direct 1.3.0 edition, production website and signed update feed are published and verified, including an actual 1.2.1-to-1.3.0 installed update. See [STATUS.md](STATUS.md) for the verified record; private account identifiers, contacts, review links and screenshots remain local.

## Historical submission and release integrity

Version **1.2.1 (7)** was submitted and verified **Waiting for Review** on 15 November at 01:27 CET. It was withdrawn before the authorized replacement and Apple showed **Developer Rejected**. Processed build **1.3.0 (9)** is now selected and submitted. The previous 1.2.0 (6) submission had already been withdrawn before 1.2.1; see STATUS.md for the full verified history.

The submitted build 7 archive/package and published direct 1.2.1 assets are immutable. The first local 1.3.0 (8) artifacts are also preserved unchanged and were not published or submitted. **Use build 9**, which aligns the privacy manifest with optional video/audio upload disclosures. Do not distribute build 8, overwrite published/submitted build 9 artifacts or relabel historical binaries.

## Published/submitted artifacts

| Channel | Local artifact | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| Mac App Store upload | `dist/app-store-1.3.0-build9/export/LocalioBC.pkg` | 2,845,231 | `dbf2c064467bd7b25ca881ef223e3e33859dd8b42ea5168f39a9faf7410af694` |
| Free direct edition | `dist/v1.3.0-build9/LocalioBC-1.3.0-universal.dmg` | 2,617,903 | `f205d9f9947948f268749fd804d3f007d903568602da46a0171e915f8ebaf505` |

The Store archive is `dist/app-store-1.3.0-build9/LocalioBC-1.3.0-9.xcarchive`. It contains arm64/x86_64 code and symbols. Exported app signing is Apple Distribution, with a distribution profile; the installer uses the Apple-issued Mac Developer Installer certificate. Strict signature, sandbox, file/bookmark and network grants, privacy manifest, license and Store updater isolation checks passed for the actual packaged app. The Store package contains no Sparkle framework/helpers, SU configuration or updater mach exceptions.

The direct app and DMG are Developer ID signed, notarization Accepted and stapled; strict nested signatures and Gatekeeper assessments passed. Both contain the same build 9 media-upload privacy manifest. Store customers receive updates from Apple; the direct edition uses Sparkle with Downloader XPC disabled because the host has outgoing-network access.

The `.pkg` is an App Store Connect/Transporter upload, not a customer installer. The DMG is the direct-distribution installer. Generated archives, packages, reports and signing material remain excluded from Git. For test detail and limitations, see [1.3.0 validation](../docs/releases/v1.3.0-development-validation.md).

## Saved listing and review material

- `metadata/en-US/` and `metadata/cs/`: localized name, subtitle, description, promotional text, keywords, version notes and public URLs for 1.3.0.
- `review/notes-en.txt`: build 9 review steps, local/offline access, optional Bunny credentials, HTTPS/Keychain handling, separate service costs and disclosed affiliate signup.
- `review/demo-clips.zip`: original demo footage; no private media or account details.
- `PRIVACY-AND-COMPLIANCE.md`: source-specific App Privacy, manifest, age-rating, encryption and licensing preparation.
- `assets/icon-1024.png`: source icon; the shipping macOS AppIcon is bundled by Xcode.
- `screenshots/en-US/` and `screenshots/cs/`: existing six numbered 1280 × 800 RGB editor/crop/export artwork images retained in the listing because the underlying editing UI is unchanged. These are not fresh build 9 captures. The build 9 icon was observed in App Store Connect.
- `ReviewContact.local.json`: complete private App Review contact, ignored by Git. Never publish it or add credentials/account screenshots to the review attachment archive.

No app account or sign-in is needed for import, editing, previews or local export. Optional Bunny transfers require a user-owned Storage Zone and write password; no real Bunny upload or account login was used in the automated release checks. If Apple asks to test this optional network feature with dedicated credentials, provide limited test access privately through App Review.

## App Store configuration

| Field | Verified value |
| --- | --- |
| Platform | macOS |
| Name | LocalioBC |
| Primary language | English (US), with Czech localization |
| Bundle ID | com.localiobvideo.app |
| Submitted version/build | 1.3.0 / 9 |
| Category | Photo & Video |
| macOS requirement | 14.0 or later |
| Architectures | Apple Silicon and Intel |
| Monetization | One-time EUR 4.99 purchase; no app subscription or IAP |
| Availability | Public distribution in all 175 authorized countries/regions |
| Release | Manual after Apple approval |

Retain the existing Localio Labs team/app record. Verify active membership, Paid Apps Agreement, banking/tax, EU trader and DAC7 status in App Store Connect rather than inferring them from signing success. Germany EUR 4.99 and the Czech Republic CZK 99 equivalent were verified for this submission. The listing must not claim that the Store download is free. The free direct edition is a separate distribution channel and is not an app-feature unlock or alternate in-app payment flow.

## Published privacy and encryption disclosures

For optional Bunny uploads, the published App Privacy label declares **Photos or Videos** and **Audio Data**, each used for **App Functionality**, **linked to the user** through their Bunny account, and **not used for tracking**. Build 9's manifest contains those exact categories and purposes, no tracking domains, and the unchanged required-reason API declarations. Do not reuse the historical Data Not Collected answer or claim that video always stays on the Mac.

Local editing/export stays offline; only a confirmed upload sends final media, including retained audio, directly over HTTPS to the user's Bunny Storage account. Localio Labs does not receive the media or Storage Zone password. The password is stored in macOS Keychain. Connection settings, source bookmarks and queue history stay local. Bunny Storage/CDN charges belong to the user's separate Bunny account and do not unlock LocalioBC features.

The external signup link is clearly identified as affiliate and contains the same public referral code for everyone, without app/device identifiers or an embedded SDK/browser. Advertising = Yes was saved in the age-rating questionnaire for this promotion, and Apple displayed 4+. This is not advertising use of uploaded media or tracking; Apple calculates regional ratings.

The app uses system HTTPS/TLS and Keychain, so it does use encryption. The prepared `ITSAppUsesNonExemptEncryption = NO` means no non-exempt encryption; it does not mean unencrypted networking. See the [compliance preparation](PRIVACY-AND-COMPLIANCE.md) and Apple's current questionnaire.

## Completed delivery and deployment

- Transporter delivered **1.3.0 (9)** at **04:24 CET** on 15 November. Apple processed it; the processed build was selected for review.
- The prior 1.2.1 submission was withdrawn and showed Developer Rejected before replacement. Apple returned **1 Item Submitted**, then **Waiting for Review**, for 1.3.0 (9) at **04:34 CET**.
- English/Czech descriptions and promotional text, build 9 review notes, published media-upload privacy, age-rating answers, icon, price, 175 regions/public distribution and manual release were verified. The six existing editor/crop/export artwork images were retained; no fresh build 9 listing captures are claimed.
- [Direct release 1.3.0](https://github.com/bradacz/LocalioBC/releases/tag/v1.3.0) is public. An anonymous download matched the final DMG bytes. The production website's Cloudflare deployment succeeded from web commit `51fb2f9`, seven checked public resources returned HTTP 200, and the owner-supplied screenshot stayed byte-for-byte unchanged.
- The public update feed matched the signed source and passed EdDSA verification. Its SHA-256 is `ec82ce23f972870977730c74eb6656a3426d0120f7995ae47a83b61e721fa3ca`.
- An unchanged signed 1.2.1 (7) copy offered build 9 from the live feed, downloaded, installed and relaunched into the new Bunny launch screen. Strict signatures, stapled ticket, Gatekeeper and final payload equality checks passed after installation.

The remaining Store work is to await review, respond to any feedback, and release manually after approval. Publish the Store link only after the paid edition actually becomes available. The build scripts themselves never upload or submit automatically.

## Rebuild and validate

Xcode automatic signing uses the existing Localio Labs account and keeps certificates/credentials in Keychain. The script exports locally and checks the actual packaged app. Use a new directory for every archive; source changes after published/submitted build 9 require a new build number and new artifacts. Historical packages must be validated with their matching source revision because current validators expect the Bunny manifest and network/bookmark grants.

```sh
python3 Scripts/validate-app-store.py --check-live-urls
RELEASE_VERSION=1.3.0 BUILD_NUMBER=9 bash Scripts/build-app-store.sh dist/app-store-1.3.0-build9-rebuild-01
python3 Scripts/validate-release-app.py store dist/app-store-1.3.0-build9/LocalioBC-1.3.0-9.xcarchive/Products/Applications/LocalioBC.app --version 1.3.0 --build 9 --store-archive
```

The complete build 9 direct-target regression suite passed **58 tests, zero failures and zero skips**, with no compiler diagnostics. It includes the shared video pipeline, optional uploads, transport, editor handoff and updater lifecycle. To rerun against the same frozen source using fresh result paths:

```sh
xcodebuild -project LocalioBC.xcodeproj -scheme LocalioBC \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/localiobc-1.3.0-build9-verify \
  -resultBundlePath /private/tmp/localiobc-1.3.0-build9-verify.xcresult \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 30 \
  -maximum-test-execution-time-allowance 60 test
```

Runtime checks used Apple Silicon on the available macOS host. Both architectures are present in the signed packages, but no physical Intel or macOS 14 runtime test is claimed. Ad-hoc isolated QA apps and synthetic queue harnesses are separate from the signed distribution packages.

## Reproduce screenshot artwork

For a future screenshot refresh, capture the current native editor, pending 9:16 crop and separate export in both languages. The current 1.3.0 listing retains the existing six artwork images and does not claim new build 9 captures. Use actual app-window captures; do not draw fake controls. Place ignored originals in `AppStore/screenshots/raw/{en,cs}-{editor,crop,export}.png`, with the pointer on the title bar. The standard window is 1180 × 760 logical points.

```sh
swiftc Scripts/build-store-screenshots.swift -o /private/tmp/localiobc-build-store-screenshots
/private/tmp/localiobc-build-store-screenshots
```

The existing compositor excludes the native title bar/screen-sharing indicator, preserves the app content and adds localized marketing headings. Output is 16:10, 1280 × 800 RGB PNG without alpha. Inspect all six final images before upload. Restore the app's system-language preference after screenshot work.

## Apple references

- [App Store provisioning](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Pricing](https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/)
- [App privacy](https://developer.apple.com/app-store/app-privacy-details/)
- [Privacy manifest data declarations](https://developer.apple.com/documentation/technotes/tn3184-adding-data-collection-details-to-your-privacy-manifest)
- [Encryption documentation](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption/)
