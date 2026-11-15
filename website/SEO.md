# LocalioBC search preparation

Prepared on 15 November 2026 for the English and Czech public website.

## Search intent and visible content

Homepages and the origin article describe free video cropping/trimming on macOS, reducing video file size, removing audio, open source and no advertising. The developer use case is preparing video assets for website headers or hero sections. The origin story follows the owner's account in the team's first-person plural: a need for simple controls and quick crop, mute and compression work. No video player or autoplay background was added to the site.

Website copy, titles, descriptions, social metadata and JSON-LD consistently use “v macOS” in Czech and “on macOS” in English for editing tasks. Product descriptions use “pro macOS” / “for macOS” where appropriate. The article and its homepage teaser use the team voice; BlogPosting credits the existing Localio Labs organization rather than an individual. The proper name Mac App Store remains unchanged. Support requests refer to the computer model and HEVC hardware availability without relabeling hardware as an operating system.

The existing Czech hero headline ends with **Jednoduše.** The supporting text puts file-size reduction first and states free/open-source/no ads. Paid Store distribution is still described separately; the free offer in structured data refers to the direct download.

## Indexable pages

| English | Czech |
| --- | --- |
| `/` | `/cs/` |
| `/support/` | `/cs/support/` |
| `/privacy/` | `/cs/privacy/` |
| `/blog/why-localiobc/` | `/cs/blog/proc-vzniklo-localiobc/` |
| `/blog/bunny-video-hosting/` | `/cs/blog/bunny-hosting-videa/` |

Each page has a unique title and description, one H1, a self-referencing HTTPS canonical, reciprocal `en`/`cs`/`x-default` alternates, localized sharing metadata and a large-image preview directive. The sitemap includes all ten URLs and language alternates; `robots.txt` points to its permanent URL. Article pages are linked from the homepages and link back to the product. Content is present in static HTML and works without JavaScript.

The thank-you pages retain `noindex,follow`, stay outside the sitemap and have no analytics. The existing Search Console ownership token remains unchanged. The new public article paths are included in the consent-based analytics allowlist; the consent implementation is otherwise unchanged.

## Structured data

Static JSON-LD describes Organization, WebSite and WebPage. Homepages add the real SoftwareApplication, its macOS requirement, current version, MIT license, features and zero-price direct-download offer. Articles add BlogPosting, publication date, author and language. No ratings, reviews, statistics or unsupported claims were invented.

Schema.org description and Google's rich-result eligibility are distinct: Google requires a real rating/review for the SoftwareApplication rich result. None is claimed or fabricated here. Search indexing, result titles/snippets and rich-result display remain Google's decision; the local JSON check does not claim a Google Rich Results Test pass.

## Verification

The Bunny hosting article adds two source pages on 15 November 2026. Local checks parse their metadata and BlogPosting JSON-LD, validate reciprocal language links and local assets, and check every signup CTA against the account-verified affiliate URL. Both article paths are in the consent-gated analytics allowlist. Signup links use `rel="sponsored"`, short visible Affiliate labels and a separate-service cost notice; all public anchors to Bunny.net use the verified referral URL, including checks for its subdomains. The owner-requested documentation/pricing sentences were removed, and the provider privacy-policy reference remains plain text. The unchanged official logo is served locally. The current application download remains 1.2.1, and direct upload is explicitly identified as forthcoming. The following browser, production and Google evidence describes the previous eight-page deployment; new article deployment and indexing must be verified separately.

The two homepage article teasers are presented together as image cards, using local SVG illustrations with explicit dimensions, lazy loading and descriptive alternatives. Each card has one native heading link with a full-card hit area, preserving a short accessible link name. The story teaser uses the team's first-person plural in both languages. This presentation does not change the article metadata, public URLs, sitemap entries, current application version or affiliate targets.

- Parsed all eight sitemap pages: one H1 each, unique title/description, matching canonical/sharing URLs, JSON-LD parsed, self/language alternates and internal links valid.
- Sitemap language alternates match the HTML; only current 1.2.1 direct download URLs remain.
- Native browser checks covered the Czech article at desktop size, both article languages at 320 CSS pixels, language switching and the mobile homepage. No horizontal overflow was found; content remained readable.
- The owner-supplied screenshot and signed updater feed retain their exact previously verified SHA-256 values.
- Production verification confirmed an exact match for all eight HTML pages and the sitemap after deployment. Public browser checks confirmed the updated Czech homepage, article language switching and current support/download links.
- Search Console accepted the sitemap submission for `https://localiobc.mylocalio.com/` on 15 November 2026. Processing and indexing of the new articles have not been independently confirmed.
- The existing GA4 property `564290399` showed both article paths in Realtime after controlled production visits with explicit analytics consent. These are technical verification visits, not evidence of organic traffic. The detailed Google setup and current state are recorded in `GOOGLE.md`.
- Local evidence stays in ignored `dist/seo-validation/`: `local.json`, `production.json`, `google-verification.json` and browser captures. Account screenshots are not committed.

## Primary references

- [Google Search Essentials](https://developers.google.com/search/docs/essentials)
- [Titles in search results](https://developers.google.com/search/docs/appearance/title-link)
- [Meta descriptions](https://developers.google.com/search/docs/appearance/snippet)
- [Localized page versions](https://developers.google.com/search/docs/specialty/international/localized-versions)
- [SoftwareApplication rich-result requirements](https://developers.google.com/search/docs/appearance/structured-data/software-app)
