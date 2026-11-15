# Mac App Store status

Review submission verified directly in App Store Connect on **15 November 2026 at 01:27 CET (Europe/Prague)**. Production direct distribution was verified at **01:24 CET**. Account DAC7 completion was verified at **00:48 CET** the same day.

**Version 1.2.1, build 7 is Waiting for Review.** Apple accepted the new submission on **15 November 2026 at 01:27 CET**. The owner authorized the new release for both channels. The pending 1.2.0 (6) submission was cancelled, showed Developer Rejected, and was replaced with 1.2.1 (7). The Store app has not been approved or publicly released. Release remains **manual after approval**.

| Distribution channel | Current state |
| --- | --- |
| Mac App Store submission | **1.2.1 (7)** — Waiting for Review |
| App Store Connect upload | **1.2.1 (7)** delivered through Transporter at 01:17 CET, processed and selected for review |
| TestFlight | Build processing and selection for App Review were verified; a separate beta-testing status was not read for build 7 |
| Previous Store submission | **1.2.0 (6)** cancelled on 15 November and replaced; Apple showed Developer Rejected after cancellation |
| Current Store source/package | **1.2.1 (7)**, universal archive and signed distribution package validated and uploaded |
| Free direct/GitHub edition | **1.2.1 (7)** published; signed/notarized DMG, signed update feed and English/Czech website verified at 01:24 CET |

Sparkle, its helpers, update configuration and sandbox exceptions are physically excluded from the Store package. Store customers receive updates through Apple. The separately released direct edition includes Sparkle. Version 1.2.0 was the first updater-enabled direct release; earlier versions need one manual installation of the current direct edition.

Private App Store Connect identifiers and the review URL are stored only in ignored `SubmissionStatus.local.json`.

## Submitted 1.2.1 package and validation

| Item | Result |
| --- | --- |
| Store build | LocalioBC 1.2.1 (7), universal arm64/x86_64, macOS 14 minimum |
| Archive/export | Passed; Xcode re-signed the development archive for App Store distribution during export |
| Final package checks | Valid installer signature; packaged app strict signature, both CPU architectures, sandbox, user-selected file access, no debugger entitlement, embedded profile, privacy manifest and MIT licence passed |
| Store isolation | No Sparkle files, linked framework, updater Info.plist keys, network-client entitlement or updater Mach exceptions |
| Shared release regression suite | 38 tests passed with no failures on the direct target; see [1.2.1 validation](../docs/releases/v1.2.1-validation.md) |
| Native verification | Isolated sandboxed Store preview checked the compact panel, merged/separate exports, progress/completion and simultaneous target-size/crop/result messages at the supported minimum size; details and limits are in the validation report |
| Listing | Existing English/Czech feature descriptions retained; saved reviewer notes identify 1.2.1 (7), the clean export panel and Store updater isolation |
| Screenshots | Six fresh RGB PNGs, 1280 × 800: Czech/light and English/dark, three per language, uploaded in editor/crop/export order |
| Review information | Existing private contact and demo-clips.zip retained; sign-in not required |
| Release setting | Manual release selected and verified before submission |
| Apple result | 1 Item Submitted; App Review shows 1.2.1 (7), Waiting for Review, submitted 01:27 CET |

Local package: `dist/app-store-1.2.1-build7/export/LocalioBC.pkg` (2,056,081 bytes).

SHA-256: `9bba802b7a5fb2d4c3d81c65052b4edf41b019ebb45116682b2979691110eaa1`.

Intel slices are verified in the package; no runtime test on physical Intel hardware or macOS 14 is claimed. Runtime checks used Apple Silicon on macOS 26.5.1. The isolated screenshot preview used a separate bundle identifier and ad-hoc signature; the uploaded package retains its production identity and Apple distribution signing.

## Published direct edition

[GitHub release 1.2.1](https://github.com/bradacz/LocalioBC/releases/tag/v1.2.1) contains the signed, notarized universal DMG (2,188,411 bytes). Its SHA-256 is `5f742171c81e3c2c7e264a510f5a352b1081e0ef7c6843e02b1753ce49f06b1a`.

Anonymous download matched the final artifact. The English/Czech production pages, current editor screenshot and exact signed feed bytes were verified at 01:24 CET. The feed publishes 1.2.1 (7) and retains 1.2.0 (6). At 01:29–01:30 CET, an unchanged signed copy of 1.2.0 queried the production feed, offered 1.2.1, installed it and relaunched as 1.2.1 (7); post-install signature and notarization-ticket checks passed. See the [release validation report](../docs/releases/v1.2.1-validation.md).

## Account configuration

Photo & Video category, English/Czech subtitles and URLs, Data Not Collected, age rating 4+, no third-party catalogue content, no sign-in, EUR 4.99 one-time price (Germany base; Czech equivalent CZK 99), 175 countries/regions and manual release are retained.

The outdated Paid Apps Agreement initially blocked the earlier 1.2.0 submission. The owner explicitly authorized accepting the updated Schedule 2 and 3; the agreement was accepted and verified **Active** before that submission succeeded at 00:38 CET on 15 November. Bank/tax forms and Digital Services Act showed Active. The agreement was not accepted again for 1.2.1.

**DAC7 is Active**, completed and verified on 15 November at 00:48 CET. In Business → Compliance → DAC7 → Add Info, the answer to whether any apps provide personal services was saved as **No**, after the owner confirmed that none of the account's apps offer such services. The previous Missing Info item is resolved. No banking or tax identification details were changed. Reassess the declaration if the account's apps begin offering paid personal services.

## Submission history

- **1.0.0 (3):** submitted on 13 November; withdrawn and replaced with 1.2.0 on 15 November. Historical package: `dist/app-store-final/`.
- **1.2.0 (6):** uploaded through Transporter at 00:24 CET, submitted at 00:38 CET and verified Waiting for Review at 00:39 CET on 15 November. Cancelled and replaced with 1.2.1 the same day. Its immutable package remains at `dist/app-store-1.2.0-build6/export/LocalioBC.pkg` (2,090,268 bytes, SHA-256 `6a32847386b34a73198a70f8a16a9715ceb1c80ec5c0f624a97d07c01e87bee1`). The direct 1.2.0 release remains available in GitHub history.

## Remaining work

1. Await Apple's review of **1.2.1 (7)** and respond to any feedback.
2. Release manually after approval, then add the working public App Store URL to the website. Until release, the website correctly says the paid Store edition is coming soon; direct distribution is already available free.

Current submission evidence (local, ignored): `dist/app-store-1.2.1-build7/submitted.png`. Historical submission/upload and account evidence remain under `dist/app-store-1.2.0-build6/`, including `paid-agreement-active.png` and `dac7-completed.png`. Account screenshots are not committed to the public repository.
