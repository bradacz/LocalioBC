# Submission preparation status

Prepared on November 12, 2026. **Ready for App Store Connect entry/upload; not submitted to Apple review.**

| Item | Result |
| --- | --- |
| Store build | LocalioBC 1.0.0 (3), universal arm64/x86_64 |
| Package export | Passed, with Mac App Store installer/distribution signing |
| Packaged application checks | Strict signature, both CPU architectures, sandbox, user-selected file access, no debugger entitlement, embedded provisioning profile, privacy manifest and MIT licence passed |
| Regression suite | 24 passed, 0 failed, on Apple Silicon/macOS 26.5.1 |
| Native smoke test | File-picker import, batch crop and separate export of two clips succeeded in the sandboxed Store-configuration preview |
| Localizations | English and Czech; Czech system language uses Czech, all others use English; manual override verified |
| Listing | Both localizations prepared, emphasizing quick and simple video cropping |
| Price | EUR 4.99 one-time purchase prepared; account-side price not yet set |
| Screenshots | Six RGB PNGs, 1280 × 800, three per language |
| Review contact | Complete, in ignored private local JSON; absent from public source |
| Product/support/privacy site | Public on https://localiobc.mylocalio.com/; TLS active; all six English/Czech pages verified |
| Apple upload/review | Not performed; Apple server validation/processing and App Review remain |

Intel slices are verified in the exported package; no runtime test on physical Intel hardware is claimed. The declared minimum OS is macOS 14; the runtime tests were performed on macOS 26.5.1.

Remaining account-side steps: create/confirm the App Store Connect app record, confirm agreements/bank/tax/trader details, configure EUR 4.99 and availability, upload/select build 3, paste metadata/screenshots/privacy/review contact, complete Apple's questionnaires and submit review. Use manual release after approval. See `README.md` for the exact workflow.
