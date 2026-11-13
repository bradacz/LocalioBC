/* Optional public website analytics. No Google request before explicit consent. */
(() => {
  'use strict';
  const config = {"name": "LocalioBC", "id": "G-HFRP7KWGWE", "hosts": ["localiobc.mylocalio.com"], "key": "localiobc_analytics_consent_v1", "paths": ["/", "/cs/", "/support/", "/cs/support/", "/privacy/", "/cs/privacy/"], "privacy": "/privacy/", "privacyCs": "/cs/privacy/"};
  if (!config.hosts.includes(location.hostname)) return;
  const key = config.key;
  const lifetime = 180 * 24 * 60 * 60 * 1000;
  const read = () => {
    try {
      const saved = JSON.parse(localStorage.getItem(key));
      return saved && ['granted', 'denied'].includes(saved.choice) && saved.at <= Date.now() && Date.now() - saved.at < lifetime ? saved.choice : null;
    } catch { return null; }
  };
  let choice = read();
  let loaded = false;
  let lastPage = null;
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
  const page = () => {
    if (choice !== 'granted' || !config.paths.includes(location.pathname) || lastPage === location.pathname) return;
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
    panel.querySelector('span').textContent = cs ? 'Google Analytics měří návštěvnost pouze s vaším souhlasem. Volbu můžete kdykoli změnit. Bez reklamního měření.' : 'Google Analytics measures website usage only with your consent. You can change your choice at any time. No advertising measurement.';
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
    try { localStorage.setItem(key, JSON.stringify({choice: value, at: Date.now()})); } catch { /* This page only. */ }
    if (choice === 'granted') enable(); else disable();
    show(false);
  };
  panel.querySelectorAll('[data-choice]').forEach(button => button.addEventListener('click', () => choose(button.dataset.choice)));
  panel.querySelector('[data-close]').addEventListener('click', () => show(false));
  settings.addEventListener('click', () => show(panel.hidden));
  window.addEventListener('storage', event => {
    if (event.key !== key && event.key !== null) return;
    choice = read();
    if (choice === 'granted') enable(); else disable();
    show(choice === null);
  });
  window.addEventListener('localio:page', page);
  window.addEventListener('popstate', page);
  new MutationObserver(renderLanguage).observe(document.documentElement, {attributes: true, attributeFilter: ['lang']});
  document.body.append(panel, settings);
  renderLanguage();
  show(choice === null);
  if (choice === 'granted') enable(); else disable();
})();
