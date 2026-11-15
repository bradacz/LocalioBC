# LocalioBC search preparation

Prepared on 15 November 2026 for the English and Czech public website.

## Search intent and visible content

Homepages and the founder article describe free video cropping/trimming on Mac, reducing video file size, removing audio, open source and no advertising. The developer use case is preparing video assets for website headers or hero sections. The founder story follows the owner's account: a need for simple controls and quick crop, mute and compression work. No video player or autoplay background was added to the site.

The existing Czech hero headline ends with **Jednoduše.** The supporting text puts file-size reduction first and states free/open-source/no ads. Paid Store distribution is still described separately; the free offer in structured data refers to the direct download.

## Indexable pages

| English | Czech |
| --- | --- |
| `/` | `/cs/` |
| `/support/` | `/cs/support/` |
| `/privacy/` | `/cs/privacy/` |
| `/blog/why-localiobc/` | `/cs/blog/proc-vzniklo-localiobc/` |

Each page has a unique title and description, one H1, a self-referencing HTTPS canonical, reciprocal `en`/`cs`/`x-default` alternates, localized sharing metadata and a large-image preview directive. The sitemap includes all eight URLs and language alternates; `robots.txt` points to its permanent URL. Article pages are linked from the homepages and link back to the product. Content is present in static HTML and works without JavaScript.

The thank-you pages retain `noindex,follow`, stay outside the sitemap and have no analytics. The existing Search Console ownership token remains unchanged. The new public article paths are included in the consent-based analytics allowlist; the consent implementation is otherwise unchanged.

## Structured data

Static JSON-LD describes Organization, WebSite and WebPage. Homepages add the real SoftwareApplication, its macOS requirement, current version, MIT license, features and zero-price direct-download offer. Articles add BlogPosting, publication date, author and language. No ratings, reviews, statistics or unsupported claims were invented.

Schema.org description and Google's rich-result eligibility are distinct: Google requires a real rating/review for the SoftwareApplication rich result. None is claimed or fabricated here. Search indexing, result titles/snippets and rich-result display remain Google's decision; the local JSON check does not claim a Google Rich Results Test pass.

## Verification

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
