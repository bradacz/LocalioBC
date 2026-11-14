# Mac App Store status

Last verified directly in App Store Connect on **15 November 2026 at 00:13 CET (Europe/Prague)**.

**Version 1.0.0, build 3 is still Waiting for Review.** It was submitted on 13 November 2026. It has not been approved or publicly released. Release is configured as **manual after approval**.

| Distribution channel | Current state |
| --- | --- |
| Mac App Store submission | **1.0.0 (3)** — Waiting for Review |
| App Store Connect uploads | Only **1.0.0 (3)** is listed; upload status **Complete** |
| TestFlight | **1.0.0 (3)** — Ready to Submit; this is the beta-testing status, separate from the App Store review status |
| Current Store source | **1.2.0 (6)** in the `LocalioBC-AppStore` target; local Release build passed, but no 1.2.0 Store archive/package has been exported, uploaded or submitted |
| Free direct/GitHub edition | **1.2.0 (6)** published; signed/notarized DMG, signed update feed and English/Czech website verified on 15 November 2026 |

The 1.2.0 direct release did **not** replace or update the pending App Store submission. Sparkle is included only in the direct edition; the Store target excludes it. Store customers receive updates through Apple.

Private App Store Connect identifiers and the review URL are stored only in ignored `SubmissionStatus.local.json`.

## Submitted 1.0.0 package and preparation

The preparation results below belong to the submitted 1.0.0 (3) package. Account configuration was recorded during submission on 13 November; review status, selected build, upload list and manual release were rechecked on 15 November.

| Item | Result |
| --- | --- |
| Store build | LocalioBC 1.0.0 (3), universal arm64/x86_64 |
| Package export | Passed, with Mac App Store installer/distribution signing |
| Packaged application checks | Strict signature, both CPU architectures, sandbox, user-selected file access, no debugger entitlement, embedded provisioning profile, privacy manifest and MIT licence passed |
| Regression suite | 24 passed, 0 failed, on Apple Silicon/macOS 26.5.1 |
| Native smoke test | File-picker import, batch crop and separate export of two clips succeeded in the sandboxed Store-configuration preview |
| Localizations | English and Czech; Czech system language uses Czech, all others use English; manual override verified |
| Listing | English and Czech metadata saved, emphasizing quick and simple video cropping |
| Price | EUR 4.99 one-time purchase configured; Germany base, Apple local equivalents (Czech Republic CZK 99) |
| Screenshots | Six RGB PNGs, 1280 × 800, three per language, uploaded |
| Review contact | Saved in App Store Connect from ignored private local JSON; absent from public source |
| Product/support/privacy site | Public on https://localiobc.mylocalio.com/; TLS active; all six English/Czech pages verified |
| Apple upload/review | Package delivered and processed; build 3 selected; submission accepted, Waiting for Review |

Intel slices are verified in the exported package; no runtime test on physical Intel hardware is claimed. The declared minimum OS is macOS 14; the runtime tests were performed on macOS 26.5.1.

Configured in App Store Connect: Photo & Video category, English/Czech subtitles and URLs, Data Not Collected privacy responses, calculated age rating 4+, no third-party catalogue content, no sign-in, review notes and demo-clips.zip, all 175 countries/regions after release, manual release after approval. The branded app icon was visually verified in the selected build's Included Assets.

## Remaining work

1. Await Apple's review of 1.0.0 (3) and address any feedback; release manually only after approval.
2. Prepare 1.2.0 (6) separately for the Store: create and validate a signed Store archive/package, update Store metadata/screenshots/reviewer notes for the newer features, upload and submit it for review. A successful local build or the GitHub DMG is not an App Store upload.
3. If 1.2.0 should replace the version currently waiting for review, App Store Connect explicitly requires removing 1.0.0 from review before selecting a new build. The current submission was left unchanged during this status check.
4. Add the actual public App Store link to the website only after the Store release is available. Public GitHub/direct distribution stays free.

Current evidence (local, ignored): `dist/app-store-status-2026-11-15.png` and `dist/app-store-builds-2026-11-15.png`. Historical evidence: `dist/app-store-waiting-for-review.png` and `dist/app-store-icon-confirmed.png`. The screenshot of the review page contains account context and is not added to the public repository.
