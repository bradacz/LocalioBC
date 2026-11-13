# LocalioBC website — Google measurement

Updated 13 November 2026. Scope: public website only; macOS app has no analytics SDK.

- Google account: marian.tomanek@gmail.com; GA account MyLocalio `416230214`.
- GA4 property `564290399`, web stream `16338219656`, measurement `G-HFRP7KWGWE`.
- Stream URL `https://localiobc.mylocalio.com`; Europe/Prague, CZK.
- Search Console URL-prefix ownership verification is pending; do not claim verified yet.
- `public/analytics.js` loads Google only after explicit consent, expires choice after 180 days, supports Czech/English, rejects by default, restricts production host/public paths, omits query/hash/form contents and advertising personalization. Preferences allow revocation and remove host analytics cookies. No earlier cookie notice is treated as Analytics consent.
- Cloudflare Pages is built automatically from GitHub main, root website, command python3 build.py, output dist. Build ignores temporary editor/media files.
- Eliška named Google reporting is being connected; daily email remains TwoUp, MyLocalio, FLOOXI and LocalioBuzz only.
- Acceptance: shared consent code passed opt-in, rejection, revocation, expiry, blocked-storage, host-boundary and URL-redaction tests. Production receipt of GA events and GSC ownership still require verification after deployment.
