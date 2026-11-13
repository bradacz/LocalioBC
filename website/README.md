# LocalioBC product website

Public product, support and privacy pages, in English and Czech, for https://localiobc.mylocalio.com/.

The static source is in `public/`; `python3 build.py` copies it to `dist/`. There are no application dependencies, forms, third-party player embeds or advertising cookies. Optional Google Analytics loads only after explicit website consent; the macOS app has no analytics SDK. Language navigation and FAQ disclosure controls work without JavaScript. The website uses a clean light palette matching the app: white and light-grey surfaces with LocalioBC blue. A supplied native screenshot is shown without distortion, at its original aspect ratio. Both flag controls remain available and preserve the current page when switching language.

## GitHub → Cloudflare Pages

Production source: `bradacz/LocalioBC`, branch `main`, directory `website`.
Cloudflare Pages project: `localiobc-web` (`localiobc-web.pages.dev`). Build command `python3 build.py`, output `dist`, root `website`; preview builds disabled.
The initial GitHub deployment `2ccb08e9-bfaa-4665-b4d3-95fdc6978922` succeeded on 13 November 2026. Custom-domain cutover is being verified; do not claim it complete before DNS and HTTPS checks.
The previous Sites project `appgprj_6af5c725b70c81918f92ee2b358f6e7f` is historical and is no longer the intended publishing workflow. Do not publish from its temporary checkout.

See [Google measurement and verification](GOOGLE.md) for IDs, consent behavior and acceptance state.

## Routes

| English | Czech |
| --- | --- |
| `/` | `/cs/` |
| `/support/` | `/cs/support/` |
| `/privacy/` | `/cs/privacy/` |

## DNS

Only records for the new `localiobc` hostname were added in the mylocalio.com Cloudflare zone. Existing apex, wildcard, mail and other subdomain records were preserved.

- Target after verified cutover: `localiobc.mylocalio.com` CNAME `localiobc-web.pages.dev`. Previous target was `custom-domains.chatgpt.site`.
- `_openai-site-verification.localiobc.mylocalio.com` TXT: ownership verification managed by Sites.
- `_cf-custom-hostname.localiobc.mylocalio.com` TXT: certificate/hostname verification managed by Sites.

The two TXT records above belong to the historical Sites hosting. Do not remove unrelated DNS records. Verify the Pages custom-domain status and HTTPS after cutover.

The page advertises the App Store edition as coming soon at EUR 4.99. It links to the full free direct download, explicitly stating that all features are included with no time limits, paid unlocks or watermarks. A GitHub source link is available in the footer. Add a genuine App Store product URL after Apple approves and releases the listing; do not insert a guessed app ID or non-working store badge.

## Scroll effects

A local `motion.js` progressively adds staggered content reveals, a subtle screenshot parallax, a sticky translucent header and a thin scroll-progress bar. It makes no network requests, uses no storage, and honours `prefers-reduced-motion` (including changes during the session). The content and navigation remain usable without JavaScript. Scroll work is throttled with `requestAnimationFrame` and a passive listener.

## Hero section

The introduction uses the white page canvas without a background video or external media requests. The supplied app screenshot remains undistorted and is lazy-loaded below the text.

### Final cutover check — 14 November 2026

The production CNAME points to localiobc-web.pages.dev. Cloudflare domain and certificate validation are active, HTTPS serves the GitHub build, Search Console ownership is verified and GA Realtime receives consented page views. See GOOGLE.md.
