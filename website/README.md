# LocalioBC product website

Public product, support and privacy pages, in English and Czech, for https://localiobc.mylocalio.com/.

The static source is in `public/`; `python3 build.py` copies it to `dist/`. There are no application dependencies, forms, analytics tags, third-party player embeds or advertising cookies. Language navigation and FAQ disclosure controls work without JavaScript. The website uses a clean light palette matching the app: white and light-grey surfaces with LocalioBC blue. A supplied native screenshot is shown without distortion, at its original aspect ratio. Both flag controls remain available and preserve the current page when switching language.

Hosted using Sites, project `appgprj_6af5c725b70c81918f92ee2b358f6e7f`, with public access. The custom hostname and HTTPS certificate were activated on November 12, 2026. The isolated source synchronization checkout used for publication is `/private/tmp/localiobc-product-site`; `.openai/hosting.json` preserves the project identity for future edits. Credentials must be obtained at runtime through the Sites tools and never stored in source or this file.

## Routes

| English | Czech |
| --- | --- |
| `/` | `/cs/` |
| `/support/` | `/cs/support/` |
| `/privacy/` | `/cs/privacy/` |

## DNS

Only records for the new `localiobc` hostname were added in the mylocalio.com Cloudflare zone. Existing apex, wildcard, mail and other subdomain records were preserved.

- `localiobc.mylocalio.com` CNAME `custom-domains.chatgpt.site`, DNS only, automatic TTL.
- `_openai-site-verification.localiobc.mylocalio.com` TXT: ownership verification managed by Sites.
- `_cf-custom-hostname.localiobc.mylocalio.com` TXT: certificate/hostname verification managed by Sites.

Keep verification records while the custom hostname is in use. Refresh the Sites custom-domain state after any DNS changes.

The page advertises the App Store edition as coming soon at EUR 4.99. It links to the full free direct download, explicitly stating that all features are included with no time limits, paid unlocks or watermarks. A GitHub source link is available in the footer. Add a genuine App Store product URL after Apple approves and releases the listing; do not insert a guessed app ID or non-working store badge.

## Scroll effects

A local `motion.js` progressively adds staggered content reveals, a subtle screenshot parallax, a sticky translucent header and a thin scroll-progress bar. It makes no network requests, uses no storage, and honours `prefers-reduced-motion` (including changes during the session). The content and navigation remain usable without JavaScript. Scroll work is throttled with `requestAnimationFrame` and a passive listener.

## Hero section

The introduction uses the white page canvas without a background video or external media requests. The supplied app screenshot remains undistorted and is lazy-loaded below the text.
