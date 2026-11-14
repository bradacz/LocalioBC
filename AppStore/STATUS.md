# Mac App Store status

Review submission verified directly in App Store Connect on **15 November 2026 at 00:39 CET (Europe/Prague)**. Account DAC7 completion verified at **00:48 CET** the same day.

**Version 1.2.0, build 6 is Waiting for Review.** Apple accepted the new submission on **15 November 2026 at 00:38 CET**. The owner authorized withdrawing the pending 1.0.0 (3) submission and replacing it with 1.2.0 (6). The app has not been approved or publicly released. Release remains **manual after approval**.

| Distribution channel | Current state |
| --- | --- |
| Mac App Store submission | **1.2.0 (6)** — Waiting for Review |
| App Store Connect upload | **1.2.0 (6)** delivered through Transporter, processed and selected for review; upload listed at 00:24 CET |
| TestFlight | Build **6**, version **1.2.0**, showed Ready to Submit after processing; this is the beta-testing status, separate from App Store review |
| Previous Store submission | **1.0.0 (3)**, originally submitted on 13 November, withdrawn and replaced on 15 November |
| Current Store source/package | **1.2.0 (6)**, universal archive and signed distribution package validated and uploaded |
| Free direct/GitHub edition | **1.2.0 (6)** published; signed/notarized DMG, signed update feed and English/Czech website verified on 15 November |

Sparkle, its helpers, update configuration and sandbox exceptions are physically excluded from the Store package. Store customers receive updates through Apple. The separately released direct edition includes Sparkle.

Private App Store Connect identifiers and the review URL are stored only in ignored `SubmissionStatus.local.json`.

## Submitted 1.2.0 package and validation

| Item | Result |
| --- | --- |
| Store build | LocalioBC 1.2.0 (6), universal arm64/x86_64, macOS 14 minimum |
| Archive/export | Passed; Xcode automatically re-signed the development archive for App Store distribution during export |
| Final package checks | Valid installer signature; packaged app strict signature, both CPU architectures, sandbox, user-selected file access, no debugger entitlement, embedded profile, privacy manifest and MIT licence passed |
| Store isolation | No Sparkle files, linked framework, updater Info.plist keys, network-client entitlement or updater Mach exceptions |
| Shared release regression suite | 38 tests passed on the direct target; see [1.2.0 validation](../docs/releases/v1.2.0-validation.md). Store-specific compilation/package checks are recorded separately above |
| Store native verification | Isolated sandboxed Store preview imported two original clips; continuous speed at 1.32×, crop controls and separate-export UI verified in Czech and English |
| Listing | English/Czech descriptions updated for continuous 0.25×–4× speed; reviewer notes identify 1.2.0 (6) and Store updater isolation |
| Screenshots | Six fresh RGB PNGs, 1280 × 800, three per language, uploaded in editor/crop/export order |
| Review information | Existing private contact and demo-clips.zip retained; sign-in not required |
| Public URLs | English/Czech product, support and privacy URLs returned HTTPS 200 during submission preparation |
| Apple result | 1 Item Submitted; App Review shows 1.2.0 (6), Waiting for Review, submitted 00:38 CET |

Local package: `dist/app-store-1.2.0-build6/export/LocalioBC.pkg` (2,090,268 bytes).

SHA-256: `6a32847386b34a73198a70f8a16a9715ceb1c80ec5c0f624a97d07c01e87bee1`.

Intel slices are verified in the package; no runtime test on physical Intel hardware or macOS 14 is claimed. Runtime checks used Apple Silicon on macOS 26.5.1. The isolated screenshot preview used a separate bundle identifier and ad-hoc signature; the uploaded package retains its production identity and Apple distribution signing.

## Account configuration

Photo & Video category, English/Czech subtitles and URLs, Data Not Collected, age rating 4+, no third-party catalogue content, no sign-in, EUR 4.99 one-time price (Germany base; Czech equivalent CZK 99), 175 countries/regions and manual release are retained.

Apple initially blocked submission because the Paid Apps Agreement was outdated. The owner explicitly authorized accepting the updated Schedule 2 and 3; the agreement was accepted and verified **Active** on 15 November before submission succeeded. Bank/tax forms and Digital Services Act showed Active.

**DAC7 is Active**, completed and verified on 15 November at 00:48 CET. In Business → Compliance → DAC7 → Add Info, the answer to whether any apps provide personal services was saved as **No**, after the owner confirmed that none of the account's apps offer such services. The previous Missing Info item is resolved. No banking or tax identification details were changed. Reassess the declaration if the account's apps begin offering paid personal services.

## Remaining work

1. Await Apple's review of **1.2.0 (6)** and respond to any feedback.
2. Release manually after approval, then add the working public App Store URL to the website. Until release, the website correctly says the paid Store edition is coming soon; direct distribution is already available free.

Evidence (local, ignored): `dist/app-store-1.2.0-build6/submitted.png`, `transporter-delivered.png`, `paid-agreement-active.png`, `dac7-completed.png` and `listing-validation.json` in the same directory. Account screenshots are not committed to the public repository. Historical package: `dist/app-store-final/` (1.0.0 build 3); it must not be mistaken for the current upload.
