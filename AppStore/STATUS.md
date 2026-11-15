# Mac App Store status

Verified directly in App Store Connect on **15 November 2026 at 04:34 CET (Europe/Prague)**: **LocalioBC 1.3.0, build 9 is Waiting for Review**. Apple returned **1 Item Submitted**, then App Review showed version 1.3.0 (9) and the 04:34 CET submission time. The Store edition has not been approved or publicly released; release remains **manual after approval**.

| Distribution channel | Current verified state |
| --- | --- |
| Mac App Store submission | **1.3.0 (9)** — Waiting for Review, submitted 15 November at 04:34 CET |
| App Store Connect upload | Build 9 delivered through Transporter at **04:24 CET**, processed and selected for review |
| TestFlight | Processing and selection for App Review were verified; no separate beta-testing status is claimed |
| Previous Store submission | **1.2.1 (7)** withdrawn before replacement; Apple showed **Developer Rejected** |
| Submitted Store package | Signed universal build 9 PKG, Apple Distribution payload and distribution profile validated |
| Free direct/GitHub edition | **1.3.0 (9)** published; anonymous download matched the final signed/notarized DMG |
| Production website | English/Czech 1.3.0 pages deployed successfully through Cloudflare from web commit `51fb2f9`; seven checked public resources returned HTTP 200 |
| Direct in-app update | An unchanged signed **1.2.1 (7)** copy offered build 9, downloaded it, installed and relaunched successfully as **1.3.0 (9)** |

Private account identifiers, review links, contacts and account screenshots remain local and are not included in these public records.

## Submitted build 9

Version 1.3.0 adds optional, explicitly initiated uploads of finished exports to the user's own Bunny Storage account, Keychain credentials, a persistent transfer queue and disclosed affiliate signup links. Editing and local export still work offline without an account. Both editions have outgoing-network access and app-scoped bookmarks. The direct updater uses the host's network entitlement with Downloader XPC disabled. Sparkle, its helpers, updater keys and mach exceptions are physically excluded from the Store package; Store updates are delivered by Apple.

| Item | Verified result |
| --- | --- |
| Store build | LocalioBC **1.3.0 (9)**, universal arm64/x86_64, macOS 14 minimum |
| Package checks | Valid installer and strict app signatures, distribution profile, sandbox, user-selected read/write, bookmarks, network client, bundled license and matching privacy manifest; no debugger entitlement |
| Store isolation | No Sparkle files, linked framework/helpers, SU configuration or updater mach exceptions |
| Regression suite | **58 passed, zero failures/skips and zero compiler diagnostics**; see [1.3.0 validation](../docs/releases/v1.3.0-development-validation.md) |
| Native checks | Czech/English, light/dark, default/minimum windows, representative merged/separate quality/target/lossless states, crop validation, progress/completion and Bunny result/queue UI |
| Listing | New English/Czech descriptions and promotional text, plus build 9 review notes, saved in App Store Connect |
| Screenshots | Existing six editor/crop/export artwork images retained because the underlying editing UI is unchanged; **these are not fresh build 9 captures** |
| Icon | Build 9 app icon observed in App Store Connect |
| App Privacy | **Photos or Videos** and **Audio Data**, App Functionality, linked to the user, not used for tracking; disclosures published |
| Age rating | Advertising **Yes** saved for the disclosed affiliate promotion; Apple displayed **4+** |
| Review access | App sign-in not required for local functionality; optional Bunny uploads require the user's own Storage Zone credentials |
| Availability/price | Public distribution, all **175 countries/regions**; Germany **EUR 4.99**, Czech Republic **CZK 99** verified |
| Release | Manual after Apple approval |
| Apple result | **1 Item Submitted → Waiting for Review**, 15 November 2026 at **04:34 CET** |

Submitted package: `dist/app-store-1.3.0-build9/export/LocalioBC.pkg`, **2,845,231 bytes**.

SHA-256: `dbf2c064467bd7b25ca881ef223e3e33859dd8b42ea5168f39a9faf7410af694`.

The source-matching manifest declares the two optional media types with linked=true, tracking=false and App Functionality only. Required-reason values remain CA92.1, 3B52.1 and C617.1. HTTPS/TLS comes from Apple system networking; `ITSAppUsesNonExemptEncryption = NO` does not mean unencrypted networking. See [privacy and compliance](PRIVACY-AND-COMPLIANCE.md).

## Published direct edition and live update

[GitHub release 1.3.0](https://github.com/bradacz/LocalioBC/releases/tag/v1.3.0) contains the signed, notarized universal DMG, **2,617,903 bytes**. Its SHA-256 is `f205d9f9947948f268749fd804d3f007d903568602da46a0171e915f8ebaf505`. An anonymous public download matched those bytes.

The production website's 1.3.0 deployment succeeded through Cloudflare. Seven checked public web resources returned HTTP 200. The owner-supplied screenshot remained byte-for-byte unchanged. The public update feed matched the signed source bytes; its SHA-256 is `ec82ce23f972870977730c74eb6656a3426d0120f7995ae47a83b61e721fa3ca`, and EdDSA verification passed.

A pristine, unchanged signed 1.2.1 (7) copy queried the real production feed, offered 1.3.0 (9), downloaded it and completed Install and Relaunch. The relaunched app showed the new Bunny launch information. Post-update strict signatures, stapled notarization ticket and Gatekeeper checks passed; the installed payload matched the final build 9 distribution payload. This was an actual installed-update check, not just a feed parse. Version 1.2.0 was the first updater-enabled direct edition; earlier direct versions need one manual installation of the current release.

## Account configuration and privacy

Photo & Video category, English/Czech listing, one-time price, all 175 regions, public distribution and manual release were verified for the new submission. The historical Data Not Collected answer was replaced by the published optional media-upload categories. A disclosed affiliate link is treated as advertising in the age-rating questionnaire; uploaded media is not used for advertising or tracking.

The Paid Apps Agreement was accepted with explicit owner approval and verified Active earlier on 15 November; bank/tax forms and Digital Services Act showed Active. DAC7 was completed and verified Active at 00:48 CET, with No saved after the owner confirmed that none of the account's apps offer personal services. These account-wide declarations must be reassessed if the business changes. No private banking, tax or review-contact details are published here.

## Submission history and immutable artifacts

- **1.0.0 (3):** submitted 13 November; withdrawn and replaced on 15 November. Historical package remains in `dist/app-store-final/`.
- **1.2.0 (6):** delivered at 00:24 CET, submitted at 00:38 CET and verified Waiting for Review at 00:39 CET on 15 November. Withdrawn before 1.2.1, with Developer Rejected shown. Package `dist/app-store-1.2.0-build6/export/LocalioBC.pkg`: 2,090,268 bytes, SHA-256 `6a32847386b34a73198a70f8a16a9715ceb1c80ec5c0f624a97d07c01e87bee1`.
- **1.2.1 (7):** delivered at 01:17 CET and submitted at 01:27 CET on 15 November. It remained Waiting for Review until withdrawn for the authorized 1.3.0 replacement, then showed Developer Rejected. Its immutable package remains at `dist/app-store-1.2.1-build7/export/LocalioBC.pkg`: 2,056,081 bytes, SHA-256 `9bba802b7a5fb2d4c3d81c65052b4edf41b019ebb45116682b2979691110eaa1`. Historical direct artifacts and the [1.2.1 validation record](../docs/releases/v1.2.1-validation.md) remain unchanged.
- **Local 1.3.0 (8):** signed preparation artifacts retained unchanged, never published or uploaded. Build 9 corrected the manifest disclosures before distribution.
- **1.3.0 (9):** delivered at 04:24 CET, processed/selected, and submitted at 04:34 CET on 15 November. Current Store state is Waiting for Review; direct distribution and the live update path are published and verified.

## Remaining work and validation limits

1. Await Apple's review of **1.3.0 (9)** and respond to feedback.
2. Release the Store edition manually after approval, then add a verified public App Store link to the website. Until then, the paid Store edition remains coming soon; the direct edition is available free.

No real-account Bunny upload was performed as a release check. Automated Bunny tests use controlled transports/responses and synthetic credentials. Native runtime checks used Apple Silicon on the available macOS host; no physical Intel or macOS 14 runtime test is claimed. Local QA apps and synthetic harnesses are distinct from the signed shipping packages. HTTP retries restart the file, and transfers require the app to remain open.
