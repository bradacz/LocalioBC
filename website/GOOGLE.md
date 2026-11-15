# LocalioBC website — Google measurement

Updated 15 November 2026. Scope: the public website only; the macOS app has no analytics SDK. Private account details and account screenshots stay outside the public repository.

## Production and ownership

- Website: `https://localiobc.mylocalio.com/`.
- Existing GA4 web measurement: `G-HFRP7KWGWE`. This public tag ID is not a credential. Keep the existing property and history; do not create a second tag or property.
- Search Console ownership uses the existing permanent HTML verification meta tag. Preserve it.
- Production deploys automatically from GitHub `bradacz/LocalioBC`, branch `main`, root `website`, build command `python3 build.py`, output `dist`. Temporary editor/media files are excluded.

## Consent and data minimization

`public/analytics.js` loads Google only after explicit analytics consent on the exact production hostname and known public page paths. A choice expires after 180 days. Rejecting or withdrawing consent stops further collection and clears this site's analytics cookies. Blocked storage is handled without preventing navigation or downloads. Consent preferences are available in Czech and English.

Page URLs omit queries and fragments. Referring-page addresses, arbitrary link text, complete destination URLs, affiliate referral codes and form values are not sent. Advertising storage, personalization and Google Signals remain disabled. This intentionally limits traffic-source and campaign attribution; it is not an analytics outage. Do not restore arbitrary referrers or UTM/query collection as a routine measurement fix.

Thank-you and error pages do not load analytics and are outside the measured-page allowlist. Ordinary local editing, exports and Bunny uploads in the app are not measured by this website tag.

## Controlled events

Enhanced automatic measurement stays **off** to prevent duplicate or uncontrolled events. The website owns these explicit events:

| Event | Meaning |
| --- | --- |
| `page_view` | A known public page visit after consent, including a restored Back/Forward cache visit. Normal initialization and navigation callbacks are deduplicated. |
| `file_download` | A click on a vetted LocalioBC release DMG download link. It does not prove a completed transfer or installation. |
| `bunny_signup_click` | A click on a Bunny.net registration link. It does not prove registration, payment or affiliate revenue. |

Both click events are configured as GA4 key events, counted once per event with no assigned default monetary value. The event-scoped **Link placement** custom dimension reads `link_placement` (`header`, `hero`, `article`, `footer`, `content`). These settings do not turn a click into a completed installation or sale. New custom-dimension reports need Google processing time.

Interaction parameters use fixed public categories and bounded placements rather than arbitrary DOM text or URLs. Revocation, consent expiry, cross-tab changes and restoration from the browser's Back/Forward cache must be checked before sending events. Rejected actions are not replayed later when consent changes.

Run the isolated regression suite with `node --test website/tests/analytics.test.mjs`. It uses mocks and sends no events to Google. Real production acceptance visits must be identified as technical tests rather than customer traffic.

## Google tag initialization

The existing Google tag configuration was corrected on 14 November 2026 to respect the website's `gtag(config)` and `send_page_view:false`, replacing a duplicate all-pages initialization rule. Keep the single controlled initialization and enhanced measurement disabled.

## Search Console

The sitemap contains twelve indexable English/Czech pages and their language alternates. Search Console accepted its resubmission on 15 November 2026 and reported **Success, 12 discovered pages**. The homepage was confirmed indexed; a live inspection of the Czech Bunny hosting article confirmed that Google could access and index it. A successful live test or sitemap submission does not mean every page is already indexed, nor does it guarantee ranking.

Earlier eight-page acceptance records describe the site before the two localized Bunny articles and the two 1.3.0 release articles were added. They are not the current sitemap count. See [SEO notes](SEO.md) for the current page list and technical checks.

## Missing pages

Root `public/404.html` disables Cloudflare Pages' implicit SPA fallback. `public/cs/404.html` provides the nearest Czech error page. Missing addresses must return HTTP **404**, never a successful homepage response. Both error documents use `noindex,follow`, omit analytics and canonical/hreflang claims, and link to real home/support pages. Keep them outside the sitemap.

## Primary references

- [Cloudflare Pages not-found behavior](https://developers.cloudflare.com/pages/configuration/serving-pages/#not-found-behavior)
- [Search Console sitemap submission and processing](https://support.google.com/webmasters/answer/7451001)
- [GA4 events and key events](https://support.google.com/analytics/answer/9322688)
- [Back/Forward cache measurement](https://web.dev/articles/bfcache)
