# LocalioBC product website

Public product, support and privacy pages, in English and Czech, for https://localiobc.mylocalio.com/.

The static source is in `public/`; `python3 build.py` copies it to `dist/`. There are no application dependencies, forms, third-party player embeds or advertising cookies. Optional Google Analytics loads only after explicit website consent; the macOS app has no analytics SDK. Language navigation and FAQ disclosure controls work without JavaScript. The website uses a clean light palette matching the app: white and light-grey surfaces with LocalioBC blue. A supplied native screenshot is shown without distortion, at its original aspect ratio. Both flag controls remain available and preserve the current page when switching language.

## GitHub → Cloudflare Pages

Production source: `bradacz/LocalioBC`, branch `main`, directory `website`.
Cloudflare Pages project: `localiobc-web` (`localiobc-web.pages.dev`). Build command `python3 build.py`, output `dist`, root `website`; preview builds disabled.
The initial GitHub deployment `2ccb08e9-bfaa-4665-b4d3-95fdc6978922` succeeded on 13 November 2026. Custom-domain cutover was verified on 14 November; the 1.2.1 production pages, screenshot and signed feed were verified again on 15 November at 01:24 CET.
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

- Verified production target: `localiobc.mylocalio.com` CNAME `localiobc-web.pages.dev`. Previous target was `custom-domains.chatgpt.site`.
- `_openai-site-verification.localiobc.mylocalio.com` TXT: ownership verification managed by Sites.
- `_cf-custom-hostname.localiobc.mylocalio.com` TXT: certificate/hostname verification managed by Sites.

The two TXT records above belong to the historical Sites hosting. Do not remove unrelated DNS records. Verify the Pages custom-domain status and HTTPS after cutover.

The page advertises the App Store edition as coming soon at EUR 4.99. Version 1.2.1 (7) was uploaded on 15 November 2026 at 01:17 CET, processed, selected and submitted at 01:27 CET. App Review was verified as **Waiting for Review**, replacing the cancelled 1.2.0 (6) submission. Release remains manual after Apple approval. See [Store status](../AppStore/STATUS.md) for the latest verified state. The website links to the full free direct download, explicitly stating that all features are included with no time limits, paid unlocks or watermarks. A GitHub source link is available in the footer. Add a genuine App Store product URL after Apple approves and releases the listing; do not insert a guessed app ID or non-working store badge.

## Scroll effects

A local `motion.js` progressively adds staggered content reveals, a subtle screenshot parallax, a sticky translucent header and a thin scroll-progress bar. It makes no network requests, uses no storage, and honours `prefers-reduced-motion` (including changes during the session). The content and navigation remain usable without JavaScript. Scroll work is throttled with `requestAnimationFrame` and a passive listener.

## Hero section

Both homepages show the approved blue cut/crop illustration shifted left behind the headline. The illustration stays absolutely positioned behind the introduction at every screen width, without adding a separate row or extra page height. On smaller screens it scales to the available width and becomes softer behind the copy. A white gradient and darker supporting text preserve readability; decorative layers never intercept clicks. The local decorative WebP asset has 600px and 1200px variants, explicit dimensions, and high fetch priority. The supplied app screenshot remains undistorted and lazy-loaded below the introduction. Existing scroll reveals, screenshot parallax and navigation remain unchanged.

### Final cutover check — 14 November 2026

The production CNAME points to localiobc-web.pages.dev. Cloudflare domain and certificate validation are active, HTTPS serves the GitHub build, Search Console ownership is verified and GA Realtime receives consented page views. See GOOGLE.md.

## Release news

The public [GitHub release 1.2.1](https://github.com/bradacz/LocalioBC/releases/tag/v1.2.1), build 7, is available as of 15 November 2026. Anonymous download of the signed, notarized universal DMG was verified against the final package SHA-256. Both homepages introduce its clean, compact export panel with readable labels and controls visible without scrolling at the default and minimum window sizes. Format, compression, estimates and export share one continuous surface without nested frames or darker section fills. The primary CTA and latest article link to the 1.2.1 universal DMG. The initial 1.2.1 deployment used a cropped Czech capture. It was later replaced with the owner-supplied English screenshot, including its native macOS frame; see Optional support below. The repository README retains its separate English capture. Versions 1.2.0 and 1.1.0 remain as release news without download links. The owner requires the website to offer only the current release for download; this rule is recorded in AGENTS.md. Users of 1.2.0 can update in the app; users of 1.1.0 or earlier can install 1.2.1 manually once to gain the updater. The signed feed includes 1.2.1 (7) and preserves 1.2.0 (6); the website build was checked to preserve its exact bytes. Publish the feed only after the referenced release asset is publicly available, then verify served bytes and signatures after deployment.

The English and Czech privacy pages distinguish local offline editing from optional update connections. They identify Cloudflare and GitHub Releases, explain ordinary connection logs (including IP address and version-bearing User-Agent), and state that no system profile, clip data or media files are sent. The macOS app contains no analytics SDK. App Store updates remain Apple's responsibility; Sparkle is absent from that edition. Do not promise hosting-provider log retention periods.

The signed feed and release notes under `public/updates/` are maintained by the release process. Do not modify their bytes after signing, inject website analytics into them, or publish them before the referenced DMG is available.

Production verification on 15 November at 01:24 CET confirmed both homepages, the current screenshot and byte-exact signed feed. At 01:29–01:30 CET, an unchanged signed copy of direct 1.2.0 retrieved this production feed and successfully installed/relaunched as 1.2.1 (7); the installed signature and notarization ticket passed. See the [release validation report](../docs/releases/v1.2.1-validation.md).

## Optional support

Both homepages place optional support links below the free download: the owner's verified Buy Me a Coffee profile (`https://buymeacoffee.com/mariantomay`) and the live Stripe Payment Link (`https://buy.stripe.com/bJe3cu5Rz2y99LU1Mk4Rq01`). Stripe uses customer-chosen EUR pricing with a suggested one-time contribution of €5; visitors can edit the amount. These are plain external links with no embedded payment scripts or on-site payment fields. No app entitlement or download depends on contributing.

The owner approved the thank-you design on 15 November 2026 with both languages: `/thank-you/` and `/cs/dekujeme/`. They have a language switcher and a link back to the product, do not claim verified payment status, and do not receive payment data or run analytics. Stripe's after-payment redirect is configured separately in the live Dashboard; do not append session identifiers to this static thank-you page. Buy Me a Coffee handles its own checkout and confirmation.

The owner supplied a new English application screenshot on 15 November 2026. It is copied byte-for-byte to `public/editor-preview.png` (2584 × 1648, SHA-256 `efc881c6bdc7fe96ee15f2772128f690444d71d5222c7c6b0fbeb965b2ea06db`). Both homepages display the full image with its original macOS window frame, without an added frame, crop or retouching.
