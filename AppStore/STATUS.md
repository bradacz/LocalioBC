# Submission preparation status

Submitted on November 13, 2026. **Waiting for Review** in App Store Connect. Version 1.0.0, build 3.

Private App Store Connect identifiers and the review URL are stored only in ignored `SubmissionStatus.local.json`.

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

Apple accepted the submission. Approval is still pending; no public App Store release has occurred. Wait for Apple's decision, address any review feedback, then release manually. Do not change the website to claim App Store availability before release. Public GitHub/direct distribution stays free.

Evidence (local, ignored): `dist/app-store-waiting-for-review.png`, `dist/app-store-icon-confirmed.png`. The screenshot of the review page contains account context and is not added to the public repository.
