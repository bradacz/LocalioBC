# App privacy and submission answers

Checked against the exported and submitted **Mac App Store edition 1.2.0 (6)** on 15 November 2026. The final package excludes Sparkle, updater settings/helpers and network-client access, and includes the privacy manifest and `ITSAppUsesNonExemptEncryption = NO`. These answers describe the Store binary; optional direct-edition update connections are documented separately. Apple accepted the submission and it is Waiting for Review; see [STATUS.md](STATUS.md).

## App Privacy

Select **Data Not Collected**. The app sends no video, audio, filenames, preferences, identifiers, analytics or diagnostics to Localio Labs. No account, tracking, advertising SDK or third-party SDK is included. Do not declare App Store payment information as data collected by this app: Apple handles the purchase outside the app. Website hosting connection information and voluntary support email are described separately in the public policy.

Public English URL: https://localiobc.mylocalio.com/privacy/

Czech localization: https://localiobc.mylocalio.com/cs/privacy/

The offline summary is always available in Settings → About → Privacy Policy.

`PrivacyInfo.xcprivacy` declares no tracking, no tracking domains and no collected data. Required-reason API declarations:

| Category | Reasons | Actual use |
| --- | --- | --- |
| User defaults | CA92.1 | Local language/appearance preferences in the app's own defaults |
| File metadata/timestamps | 3B52.1, C617.1 | File attributes for user-selected media/outputs and temporary files in the app container; no off-device transfer |

## Age rating questionnaire

Expected general rating: **4+**, subject to Apple's current questionnaire and regional calculation. Built-in demo content is an original geometric graphic. Select **None/No** for violence, sexual content/nudity, profanity, horror, alcohol/tobacco/drugs, gambling, medical advice, messaging/social features, advertising and online user-generated content. The app edits files selected locally; it does not host a public content feed. External links open a browser; there is no embedded unrestricted browser. Do not override Apple's calculated regional ratings without a real reason.

## Export compliance

`ITSAppUsesNonExemptEncryption = NO` is included. This app does not implement proprietary cryptography, VPN, secure messaging, DRM or encrypted networking. It uses Apple media/system frameworks. The prepared answer is no non-exempt encryption; review the current Apple questionnaire before submission and reassess if functionality changes.

## Content and licensing

LocalioBC code is MIT licensed. Full copyright and permission text are bundled as `LICENSE` and viewable in About. MIT permits commercial distribution. All supplied screenshot/demo artwork was created for this project from the owner's LocalioBuzz brand reference; no stock footage, music or external image licence is required. Users choose their own media and are responsible for their rights to it.

Use the standard Apple EULA unless the Account Holder has a reviewed custom EULA. This does not remove the bundled open-source notices. No subscription terms, account deletion flow, tracking-consent prompt or third-party sign-in is applicable to this version.

## Paid distribution and EU trader information

The updated Paid Apps Agreement was accepted with explicit owner approval on 15 November 2026 and verified Active before successful submission. Bank/tax forms and Digital Services Act showed Active. DAC7 was completed and verified Active at 00:48 CET the same day: the owner confirmed that none of the account's apps provide personal services, and No was saved. Reassess this account-wide answer if the services offered change. For future submissions, confirm an active agreement, bank and tax details. For the seller Localio Labs s.r.o., maintain the EU trader declaration and verify the legal address, contact email and telephone in App Store Connect. The App Review phone number is not automatically the public EU trader number; confirm the public business contact separately. Do not copy personal/private contact data into the repository.

## Sources checked

- [Apple required-reason API categories](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Current App Store requirements](https://developer.apple.com/news/upcoming-requirements/)
- [EU trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- [DAC7 declaration and personal services](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-information-for-directive-on-administrative-cooperation-7th-amendment)
- [MIT license](https://opensource.org/license/mit)
