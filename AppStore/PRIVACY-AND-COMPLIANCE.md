# App privacy and submission answers — 1.3.0 (9)

Prepared on 15 November 2026 for the Bunny-enabled Mac App Store edition. This document describes source behavior and the intended submission answers; [STATUS.md](STATUS.md) records what was actually uploaded or submitted. The historical 1.2.1 (7) package and its local-only privacy answers are not the current release candidate. The first local 1.3.0 (8) archive is retained unchanged; build 9 aligns the manifest with the optional media-upload disclosure.

## Data inventory

| Function | Data and destination | Retention/control |
| --- | --- | --- |
| Import, edit, preview, export | User-selected local video/audio, processed on the Mac | No account or network is required. Source files are preserved. |
| Optional Bunny upload | Final video, including its audio if retained, filename/path, byte length and SHA-256 checksum, directly over HTTPS to the user's configured Bunny Storage region/account | Only after explicit confirmation. Bunny retains the uploaded object under the user's account and terms; CDN visibility follows that user's Pull Zone configuration. Localio Labs does not receive the file. |
| Bunny authentication | Storage Zone write password, sent in the authenticated HTTPS request to Bunny | Stored locally in macOS Keychain; never placed in a URL, exported configuration or app telemetry. Disconnect removes the local saved credential, not remote objects. |
| Local transfer queue | Profile, source-file fingerprints, security-scoped bookmarks, progress/history and CDN links | Stored in the app container. Restored interrupted transfers require an explicit retry. |
| Affiliate signup | A public referral code shared by all users, opened in the external browser | No app/device identifier, advertising ID, embedded browser, affiliate SDK or click telemetry is supplied by the app. Bunny controls subsequent registration, website cookies and billing. |
| App Store purchase | Handled outside the app by Apple | No payment details are received by LocalioBC. |

## Prepared App Privacy label

**Data collected: Yes.** Declare only:

| Apple category | Purpose | Linked to user | Used for tracking |
| --- | --- | --- | --- |
| User Content → Photos or Videos | App Functionality | Yes | No |
| User Content → Audio Data | App Functionality | Yes | No |

The label covers optional uploads, including video sound. Association with the user's Bunny account supports Linked to User; the app does not anonymize that stored content. Local-only editing, Keychain storage and local queue history do not themselves constitute off-device collection. Do not infer contact, purchase, analytics, location or device-ID collection from these features. The per-file random identifier is not a user identifier.

This classification applies Apple's published rules to LocalioBC; Apple does not provide a Bunny-specific ruling. Its media-upload FAQ requires the relevant media category, and the collection/optional-disclosure rules do not give a blanket exemption for a user-initiated transfer or customer-owned account. The app must therefore not reuse the historical Data Not Collected answer. See [App privacy details](https://developer.apple.com/app-store/app-privacy-details/) (Data collection, Optional disclosure, Data linked to the user, and Additional guidance: free-form fields/media uploads), checked 15 November 2026.

The affiliate link contains no per-user app data and is not an analytics integration. Under the observed implementation, do not mark the uploaded media as used for advertising or tracking. If referral implementation or Bunny-side use changes to link app user/device data for advertising measurement, reassess the label and ATT before release.

Public policies explain the optional transfer and distinguish Bunny's retention from Localio Labs:

- English: https://localiobc.mylocalio.com/privacy/
- Czech: https://localiobc.mylocalio.com/cs/privacy/
- In-app summary: Settings → About → Privacy Policy.

## Privacy manifest

`PrivacyInfo.xcprivacy` declares no tracking and no tracking domains. It declares exactly `NSPrivacyCollectedDataTypePhotosorVideos` and `NSPrivacyCollectedDataTypeAudioData`, both with `NSPrivacyCollectedDataTypeLinked = true`, `NSPrivacyCollectedDataTypeTracking = false`, and the sole purpose `NSPrivacyCollectedDataTypePurposeAppFunctionality`. The final signed binary must contain this aligned manifest. Apple's [TN3184](https://developer.apple.com/documentation/technotes/tn3184-adding-data-collection-details-to-your-privacy-manifest) and [collected-data type values](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype) define the structure and exact constants.

Required-reason API declarations are unchanged:

| Category | Reasons | Actual use |
| --- | --- | --- |
| User defaults | CA92.1 | Local language/appearance preferences in the app's own defaults |
| File metadata/timestamps | 3B52.1, C617.1 | Inspect user-selected sources/outputs, detect changed queued files and manage temporary files. File timestamps and local preferences are not uploaded. |

## Age rating and content rights

Answer the current questionnaire from the actual app. Advertising is **Yes** because the clearly identified affiliate signup promotes an external paid service. This is not an advertising SDK or ad network. Apple defines advertising as paid product/service promotion and calculates regional ratings; do not hard-code the previous 4+ rating or suppress a changed regional result. See [age rating definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/).

There is no embedded unrestricted browser, public feed, messaging, social discovery, gambling or health feature. User uploads target their own storage; the app does not broadly redistribute or display other users' content. Built-in/reviewer demo content is original geometric artwork. The owner previously confirmed content rights and absence of objectionable content; use None/No for the corresponding mature-content descriptors. Do not claim rights over users' own media.

## Export compliance

`ITSAppUsesNonExemptEncryption = NO` remains the prepared answer. LocalioBC **does use encrypted networking**: Bunny uploads and verification use HTTPS/TLS supplied by Apple's system networking APIs, credentials use macOS Keychain, and checksums use system CryptoKit SHA-256. It includes no proprietary encryption, bundled non-system TLS implementation, VPN, secure-messaging service or DRM. Answer any question about use of encryption accurately; the false flag means no non-exempt encryption, not an absence of TLS.

Apple's [encryption documentation table](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption/) states that encryption limited to the Apple operating system requires no App Store Connect documentation. Recheck the current questionnaire against the final binary. See also [export-compliance overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/).

## Licensing, paid distribution and review access

Code is MIT licensed; the full notice is bundled and available in About. MIT permits paid distribution. Use the standard Apple EULA unless the Account Holder supplies an approved custom EULA. The App Store edition is a one-time EUR 4.99 purchase with Apple-generated local equivalents; it has no app subscription or IAP. Bunny's separately billed storage/CDN account is optional and does not unlock local features. App Store updates are delivered by Apple; Sparkle, its configuration/helpers and mach exceptions are physically excluded.

No app account or demo login is needed for all local functionality. Optional live Bunny transfers need the reviewer's own Storage Zone credentials; the public review notes explain this openly. Do not put a password, private review contact, account identifier or private App Store Connect URL into this repository. If Apple requests a dedicated test Storage Zone, provide its limited access details privately through App Review.

Account-wide agreements, trader information, banking/tax and the current review state must be verified in App Store Connect. Their latest observed state belongs in STATUS.md and ignored private records, not inferred from a successful archive/export.
