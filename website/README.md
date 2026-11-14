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

The page advertises the App Store edition as coming soon at EUR 4.99. App Store Connect was rechecked on 15 November 2026 at 00:39 CET: Store version 1.2.0 (6) was submitted at 00:38 CET and is Waiting for Review with manual release. It replaces the withdrawn 1.0.0 (3) submission. See [Store status](../AppStore/STATUS.md). It links to the full free direct download, explicitly stating that all features are included with no time limits, paid unlocks or watermarks. A GitHub source link is available in the footer. Add a genuine App Store product URL after Apple approves and releases the listing; do not insert a guessed app ID or non-working store badge.

## Scroll effects

A local `motion.js` progressively adds staggered content reveals, a subtle screenshot parallax, a sticky translucent header and a thin scroll-progress bar. It makes no network requests, uses no storage, and honours `prefers-reduced-motion` (including changes during the session). The content and navigation remain usable without JavaScript. Scroll work is throttled with `requestAnimationFrame` and a passive listener.

## Hero section

Both homepages show the approved blue cut/crop illustration shifted left behind the headline. The illustration stays absolutely positioned behind the introduction at every screen width, without adding a separate row or extra page height. On smaller screens it scales to the available width and becomes softer behind the copy. A white gradient and darker supporting text preserve readability; decorative layers never intercept clicks. The local decorative WebP asset has 600px and 1200px variants, explicit dimensions, and high fetch priority. The supplied app screenshot remains undistorted and lazy-loaded below the introduction. Existing scroll reveals, screenshot parallax and navigation remain unchanged.

### Final cutover check — 14 November 2026

The production CNAME points to localiobc-web.pages.dev. Cloudflare domain and certificate validation are active, HTTPS serves the GitHub build, Search Console ownership is verified and GA Realtime receives consented page views. See GOOGLE.md.

## Release news

Both homepages lead with LocalioBC 1.2.0, dated 15 November 2026: a continuous 0.25×–4× speed slider with a 1× reset, optional Sparkle update checks for the direct edition, optional automatic downloads, and installation safeguards for exports and in-memory edits. The primary CTA and latest article link to the 1.2.0 universal DMG on GitHub Releases. Version 1.1.0 remains as release history with its original download link. Users of 1.1.0 or earlier must install 1.2.0 manually once to gain the updater. Publish only after the signed, notarized release asset and signed update feed are available.

The English and Czech privacy pages distinguish local offline editing from optional update connections. They identify Cloudflare and GitHub Releases, explain ordinary connection logs (including IP address and version-bearing User-Agent), and state that no system profile, clip data or media files are sent. The macOS app contains no analytics SDK. App Store updates remain Apple's responsibility; Sparkle is absent from that edition. Do not promise hosting-provider log retention periods.

The signed feed and release notes under `public/updates/` are maintained by the release process. Do not modify their bytes after signing, inject website analytics into them, or publish them before the referenced DMG is available.
