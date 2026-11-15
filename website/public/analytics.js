/* Optional public website analytics. No Google request before explicit consent. */
(() => {
  'use strict';
  const config = {"name": "LocalioBC", "id": "G-HFRP7KWGWE", "hosts": ["localiobc.mylocalio.com"], "key": "localiobc_analytics_consent_v1", "paths": ["/", "/cs/", "/support/", "/cs/support/", "/privacy/", "/cs/privacy/", "/blog/why-localiobc/", "/cs/blog/proc-vzniklo-localiobc/", "/blog/bunny-video-hosting/", "/cs/blog/bunny-hosting-videa/", "/blog/localiobc-1-3-bunny-storage/", "/cs/blog/localiobc-1-3-bunny-storage/"], "privacy": "/privacy/", "privacyCs": "/cs/privacy/"};
  if (!config.hosts.includes(location.hostname) || !config.paths.includes(location.pathname)) return;
  // Match public release/signup destinations, never collect arbitrary link URLs or text.
  const downloadPath = '/bradacz/LocalioBC/releases/download/v1.3.0/LocalioBC-1.3.0-universal.dmg';
  const key = config.key;
  const lifetime = 180 * 24 * 60 * 60 * 1000;
  const read = () => {
    try {
      const saved = JSON.parse(localStorage.getItem(key));
      return saved && ['granted', 'denied'].includes(saved.choice) && Number.isFinite(saved.at) && saved.at <= Date.now() && Date.now() - saved.at < lifetime ? saved : null;
    } catch { return null; }
  };
  const saved = read();
  let choice = saved?.choice ?? null;
  let expiresAt = saved ? saved.at + lifetime : 0;
  let loaded = false;
  let lastPage = null;
  const restoreChoice = () => {
    const saved = read();
    choice = saved?.choice ?? null;
    expiresAt = saved ? saved.at + lifetime : 0;
  };
  const disable = () => {
    window['ga-disable-' + config.id] = true;
    lastPage = null;
    for (const entry of document.cookie.split(';')) {
      const name = entry.split('=')[0].trim();
      if (!/^_ga(?:_|$)/.test(name)) continue;
      document.cookie = name + '=; Max-Age=0; path=/; SameSite=Lax; Secure';
      document.cookie = name + '=; Max-Age=0; path=/; SameSite=Lax; Secure; domain=' + location.hostname;
    }
  };
  const hasConsent = () => {
    if (choice !== 'granted') return false;
    if (Date.now() >= expiresAt || Date.now() < expiresAt - lifetime) {
      choice = null;
      expiresAt = 0;
      disable();
      show(true);
      return false;
    }
    return true;
  };
  const page = () => {
    if (!hasConsent() || !config.paths.includes(location.pathname) || lastPage === location.pathname) return;
    lastPage = location.pathname;
    // Only known public paths; never send query strings, fragments or form values.
    window.gtag('event', 'page_view', {
      page_location: location.origin + location.pathname,
      page_referrer: '', page_title: config.name + ' — ' + location.pathname,
      send_to: config.id
    });
  };
  const enable = () => {
    if (choice !== 'granted') return;
    window['ga-disable-' + config.id] = false;
    if (!loaded) {
      loaded = true;
      window.dataLayer = window.dataLayer || [];
      window.gtag = function () { window.dataLayer.push(arguments); };
      window.gtag('consent', 'default', {
        analytics_storage: 'granted', ad_storage: 'denied',
        ad_user_data: 'denied', ad_personalization: 'denied'
      });
      window.gtag('js', new Date());
      window.gtag('config', config.id, {
        send_page_view: false, allow_google_signals: false,
        allow_ad_personalization_signals: false, cookie_domain: 'none',
        cookie_expires: 15552000, cookie_update: false,
        page_location: location.origin + (config.paths.includes(location.pathname) ? location.pathname : '/'),
        page_referrer: '', page_title: config.name
      });
      const script = document.createElement('script');
      script.async = true;
      script.src = 'https://www.googletagmanager.com/gtag/js?id=' + config.id;
      document.head.appendChild(script);
    }
    page();
  };
  const trackLink = event => {
    if (!hasConsent() || !config.paths.includes(location.pathname) || event.defaultPrevented) return;
    if ((event.type === 'click' && event.button !== 0) || (event.type === 'auxclick' && event.button !== 1)) return;
    const link = event.target?.closest?.('a[href]');
    if (!link) return;
    let url;
    try { url = new URL(link.href); } catch { return; }
    if (url.username || url.password) return;
    let name;
    let details;
    if (url.origin === 'https://github.com' && url.pathname === downloadPath) {
      name = 'file_download';
      details = {file_name: 'LocalioBC-1.3.0-universal.dmg', file_extension: 'dmg', link_domain: 'github.com'};
    } else if (url.origin === 'https://bunny.net' && url.pathname === '/' && url.searchParams.get('ref') === 'gm93y8cppz') {
      name = 'bunny_signup_click';
      details = {link_domain: 'bunny.net'};
    } else return;
    const placement = link.closest('header') ? 'header' : link.closest('.hero') ? 'hero' : link.closest('article.prose') ? 'article' : link.closest('footer') ? 'footer' : 'content';
    window.gtag('event', name, {
      ...details, link_placement: placement,
      page_location: location.origin + location.pathname,
      page_referrer: '', page_title: config.name + ' — ' + location.pathname,
      send_to: config.id
    });
  };
  const panel = document.createElement('section');
  panel.className = 'localio-analytics-consent';
  panel.innerHTML = '<p><strong></strong><br><span></span> <a></a></p><div><button type="button" data-choice="granted"></button><button type="button" data-choice="denied"></button><button type="button" data-close></button></div>';
  const settings = document.createElement('button');
  settings.type = 'button';
  settings.className = 'localio-analytics-settings';
  const renderLanguage = () => {
    const cs = document.documentElement.lang === 'cs';
    panel.setAttribute('aria-label', cs ? 'Nastavení statistik návštěvnosti' : 'Website analytics preferences');
    panel.querySelector('strong').textContent = cs ? 'Pomůžete nám vylepšovat web?' : 'Help us improve this website?';
    panel.querySelector('span').textContent = cs ? 'S vaším souhlasem Google Analytics měří zobrazení stránek a kliknutí na stažení aplikace a odkazy Bunny.net. Volbu můžete kdykoli změnit. Bez reklamního měření.' : 'With your consent, Google Analytics measures page views and clicks on download and Bunny.net links. You can change your choice at any time. No advertising measurement.';
    const link = panel.querySelector('a');
    link.textContent = cs ? 'Soukromí' : 'Privacy';
    link.href = cs ? config.privacyCs : config.privacy;
    panel.querySelector('[data-choice="granted"]').textContent = cs ? 'Povolit statistiky' : 'Allow analytics';
    panel.querySelector('[data-choice="denied"]').textContent = cs ? 'Odmítnout' : 'Reject';
    panel.querySelector('[data-close]').textContent = cs ? 'Zavřít' : 'Close';
    settings.textContent = cs ? 'Nastavení statistik' : 'Analytics preferences';
  };
  const show = visible => {
    panel.hidden = !visible;
    settings.setAttribute('aria-expanded', String(visible));
    panel.querySelector('[data-close]').hidden = choice === null;
  };
  const choose = value => {
    choice = value;
    const at = Date.now();
    expiresAt = at + lifetime;
    try { localStorage.setItem(key, JSON.stringify({choice: value, at})); } catch { /* This page only. */ }
    if (choice === 'granted') enable(); else disable();
    show(false);
  };
  panel.querySelectorAll('[data-choice]').forEach(button => button.addEventListener('click', () => choose(button.dataset.choice)));
  panel.querySelector('[data-close]').addEventListener('click', () => show(false));
  settings.addEventListener('click', () => show(panel.hidden));
  window.addEventListener('storage', event => {
    if (event.key !== key && event.key !== null) return;
    restoreChoice();
    if (choice === 'granted') enable(); else disable();
    show(choice === null);
  });
  window.addEventListener('localio:page', page);
  window.addEventListener('popstate', page);
  window.addEventListener('pageshow', event => {
    if (!event.persisted) return;
    // Cached documents retain JS state; refresh consent before counting the new visit.
    restoreChoice();
    lastPage = null;
    if (choice === 'granted') enable(); else disable();
    show(choice === null);
  });
  // Native click covers mouse, touch and keyboard activation without delaying navigation.
  document.addEventListener('click', trackLink);
  document.addEventListener('auxclick', trackLink);
  new MutationObserver(renderLanguage).observe(document.documentElement, {attributes: true, attributeFilter: ['lang']});
  document.body.append(panel, settings);
  renderLanguage();
  show(choice === null);
  if (choice === 'granted') enable(); else disable();
})();
