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
| `/blog/why-localiobc/` | `/cs/blog/proc-vzniklo-localiobc/` |
| `/blog/bunny-video-hosting/` | `/cs/blog/bunny-hosting-videa/` |

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

Both homepages place optional support links below the free download: the owner's verified Buy Me a Coffee profile (`https://buymeacoffee.com/mariantomay`) and the live Stripe Payment Link (`https://buy.stripe.com/bJe3cu5Rz2y99LU1Mk4Rq01`). Stripe uses customer-chosen EUR pricing with a suggested one-time contribution of €10; visitors can edit the amount. These are plain external links with no embedded payment scripts or on-site payment fields. No app entitlement or download depends on contributing.

The owner approved the thank-you design on 15 November 2026 with both languages: `/thank-you/` and `/cs/dekujeme/`. They have a language switcher and a link back to the product, do not claim verified payment status, and do not receive payment data or run analytics. Stripe's live after-payment redirect was saved and re-opened for verification as `https://localiobc.mylocalio.com/thank-you/`; the page includes the Czech language switch. Do not append session identifiers to this static thank-you page. Buy Me a Coffee handles its own checkout and confirmation.

The owner supplied a new English application screenshot on 15 November 2026. It is copied byte-for-byte to `public/editor-preview.png` (2584 × 1648, SHA-256 `efc881c6bdc7fe96ee15f2772128f690444d71d5222c7c6b0fbeb965b2ea06db`). Both homepages display the full image with its original macOS window frame, without an added frame, crop or retouching.

On 15 November 2026, the owner's Buy Me a Coffee profile was updated in English with the tagline “creating free, open-source tools”. The public About text explains that contributions support development, testing, maintenance, hosting, developer tools and future updates of free open-source software. The saved English copy was independently verified on the public profile.

Deployment checks confirmed English/Czech support links, both thank-you pages, only 1.2.1 direct download URLs, and an exact production match for the owner-supplied PNG. The support buttons were checked side by side at 320 CSS pixels with 44-pixel touch targets and no horizontal overflow. Stripe's public checkout showed the editable €10 preset; its saved redirect was verified in the Dashboard. No payment was initiated during verification. The app release and signed updater feed were not changed by this website update.

The owner later changed the suggested Stripe contribution to €10 and the Czech hero line to “Jednoduše.” The live Checkout styling uses the website's white background (`#ffffff`), blue button color (`#3157c8`), system font and rounded controls. Stripe shares this Checkout styling across the company's Checkout and Payment Links; it retains its own payment form layout.

## Search and developer use case

The English and Czech homepages emphasize free, ad-free, open-source video cropping and compression on macOS, including audio removal and preparing assets for website headers. The origin story is available at `/blog/why-localiobc/` and `/cs/blog/proc-vzniklo-localiobc/`, linked from the homepages. Both versions use the team's first-person plural, with Localio Labs credited as the author. Website copy and SEO use “v macOS” / “on macOS” consistently; the proper name Mac App Store is preserved. “Video for a website header” describes the app's use case; the website has no video player or header video.

Every indexable page has its own title/description, canonical URL, reciprocal English/Czech hreflang links, Open Graph/Twitter metadata and static JSON-LD. Homepages describe the free direct edition as SoftwareApplication; articles use BlogPosting. No ratings/reviews are invented. The XML sitemap includes the ten indexable URLs and their language alternates. Thank-you pages remain noindex and outside the sitemap. The Search Console verification meta tag is preserved. New article paths are added to the existing consent-gated analytics allowlist; thank-you paths remain excluded. See `SEO.md` for validation and source references.

## Bunny.net hosting article and affiliate links

The English and Czech hosting guides explain preparing smaller website video files on macOS with LocalioBC and delivering them through Bunny Storage and a connected CDN Pull Zone. They distinguish Storage from Stream, link to official documentation and explain separate Bunny usage charges. They explicitly identify 1.2.1 as the currently published version, with manual dashboard uploads; optional direct uploads are described as a forthcoming feature. Publishing the article does not publish a new application release.

The owner-authorized Affiliate Program was enabled in the owner's authenticated Bunny dashboard on 15 November 2026. The verified public referral URL is `https://bunny.net?ref=gm93y8cppz`. It is recorded as a public constant in `build.py`, which rejects signup links that differ from this URL or omit `rel="sponsored"`. Every public page has a plainly marked affiliate signup link in its header. Both homepages link to the article and include a signup link with a commission disclosure. The articles repeat the disclosure beside their registration action. There is no generic signup fallback, custom redirect, embedded Bunny player or Bunny tracking script.

`public/bunny-logo.svg` is the unchanged official 149 × 43 Bunny.net wordmark, including its rabbit, retrieved from `https://bunny.net/static/bunnynet-dark-d6a41260b1e4b665cb2dc413e3eb84ca.svg`. Its SHA-256 is `d3b6c26c84f8c6cd4225d5639a710a21fd4c3e2392abc4c73eafa3cb99c92452`. It is served locally and has explicit intrinsic dimensions. Bunny trademarks remain the property of their owner; see `public/THIRD-PARTY-NOTICES.txt`. The logo is not included in LocalioBC's MIT artwork grant.

The header keeps one native navigation tree. Its links wrap on narrow screens without JavaScript, custom menu roles or hidden controls. The new affiliate action has a 44-pixel minimum target, an explicit focus outline and a visible affiliate label. English and Czech flag controls retain the current page, including the new article pair.

Privacy pages now distinguish local editing, explicit optional uploads in supporting versions, and referral links. Merely displaying a referral link sends no request to Bunny because the logo is local. Existing app downloads, supplied screenshots and signed update files remain unchanged. Source validation covers local links, metadata JSON, sitemap language pairs and all affiliate URLs; native browser layout QA and production verification are recorded by the publishing task when completed.
