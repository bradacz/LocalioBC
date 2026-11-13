# LocalioBC website — Google measurement

Updated 13 November 2026. Scope: public website only; macOS app has no analytics SDK.

- Google account: marian.tomanek@gmail.com; GA account MyLocalio `416230214`.
- GA4 property `564290399`, web stream `16338219656`, measurement `G-HFRP7KWGWE`.
- Stream URL `https://localiobc.mylocalio.com`; Europe/Prague, CZK.
- Search Console https://localiobc.mylocalio.com/ is verified siteOwner via the permanent HTML meta tag. Do not remove the tag.
- `public/analytics.js` loads Google only after explicit consent, expires choice after 180 days, supports Czech/English, rejects by default, restricts production host/public paths, omits query/hash/form contents and advertising personalization. Preferences allow revocation and remove host analytics cookies. No earlier cookie notice is treated as Analytics consent.
- Cloudflare Pages is built automatically from GitHub main, root website, command python3 build.py, output dist. Build ignores temporary editor/media files.
- Eliška named Google reporting is connected; daily email remains TwoUp, MyLocalio, FLOOXI and LocalioBuzz only.
- Acceptance: shared consent code passed opt-in, rejection, revocation, expiry, blocked-storage, host-boundary and URL-redaction tests. Production deployment 8b7629ff-3d38-4070-81f7-f86fcac5ec85 succeeded. CNAME now points to localiobc-web.pages.dev; Cloudflare reports domain, validation and verification active. HTTPS serves the GitHub build. Google confirmed ownership and GA Realtime returned page_view, first_visit and session_start after a normal consented visit on 13/14 November. These acceptance visits are not representative traffic. Enhanced automatic measurement was disabled on 14 November; controlled page views remain enabled.

## Oprava inicializace 14. 11. 2026

Google tag GTM-M8HZKXQH, účet 6405006390, kontejner 286852667: publikována živá verze 2. Výchozí Initialization - All Pages ignorovalo webové gtag config a způsobovalo duplicitní page_view. Nahrazeno jediným pravidlem Inicializace podle konfigurace webu s podporou gtag(config), čekáním na vlastní kontejner a přesné ID G-HFRP7KWGWE. Původní pravidlo odstraněno. Nastavení send_page_view:false i soukromí nyní řídí kód webu. Automatické rozšířené měření zůstává vypnuté.

Kontrolovaná návštěva se souhlasem po publikování přidala právě jedno page_view (Realtime 1 → 2). Jde o technický test, nikoli historickou návštěvnost. Přehledy v Elišce používají přesná GA/GSC ID; nová historie se nevytváří zpětně.
