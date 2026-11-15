import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

// These DOM/storage doubles cannot fetch scripts or send real analytics events.
const source = readFileSync(new URL('../public/analytics.js', import.meta.url), 'utf8');
const key = 'localiobc_analytics_consent_v1';
const measurementId = 'G-HFRP7KWGWE';
const download = 'https://github.com/bradacz/LocalioBC/releases/download/v1.3.0/LocalioBC-1.3.0-universal.dmg';
const signup = 'https://bunny.net?ref=gm93y8cppz';
const now = 1_795_000_000_000;
const savedChoice = (choice, at = now) => JSON.stringify({choice, at});
const plain = value => JSON.parse(JSON.stringify(value));

class Target {
  listeners = new Map();
  addEventListener(type, handler) {
    const handlers = this.listeners.get(type) || [];
    handlers.push(handler);
    this.listeners.set(type, handlers);
  }
  emit(type, properties = {}) {
    const event = {type, button: 0, defaultPrevented: false, ...properties};
    for (const handler of this.listeners.get(type) || []) handler(event);
    return event;
  }
}

class Element extends Target {
  attributes = {};
  children = [];
  dataset = {};
  hidden = false;
  selectors = new Map();
  constructor(tag = 'div', parent = null) {
    super();
    this.tagName = tag.toUpperCase();
    this.parentElement = parent;
  }
  setAttribute(name, value) { this.attributes[name] = value; }
  append(...children) {
    for (const child of children) {
      child.parentElement = this;
      this.children.push(child);
    }
  }
  appendChild(child) { this.append(child); return child; }
  set innerHTML(value) {
    // The production consent panel is a fixed developer-authored template.
    assert.ok(value.includes('data-choice="granted"'));
    for (const selector of ['strong', 'span', 'a', '[data-choice="granted"]', '[data-choice="denied"]', '[data-close]']) {
      const child = new Element(selector === 'a' ? 'a' : 'button', this);
      this.selectors.set(selector, child);
    }
    this.selectors.get('[data-choice="granted"]').dataset.choice = 'granted';
    this.selectors.get('[data-choice="denied"]').dataset.choice = 'denied';
  }
  querySelector(selector) { return this.selectors.get(selector); }
  querySelectorAll(selector) {
    assert.equal(selector, '[data-choice]');
    return [this.querySelector('[data-choice="granted"]'), this.querySelector('[data-choice="denied"]')];
  }
  closest(selector) {
    const matches = element => {
      if (selector === 'a[href]') return element.tagName === 'A' && Boolean(element.href);
      if (selector === 'article.prose') return element.tagName === 'ARTICLE' && (element.className || '').split(' ').includes('prose');
      if (selector === '.hero') return (element.className || '').split(' ').includes('hero');
      return element.tagName === selector.toUpperCase();
    };
    for (let element = this; element; element = element.parentElement) if (matches(element)) return element;
    return null;
  }
}

function harness({saved = null, host = 'localiobc.mylocalio.com', path = '/', blockedStorage = false, lang = 'en'} = {}) {
  let clock = now;
  const window = new Target();
  const document = new Target();
  document.head = new Element('head');
  document.body = new Element('body');
  document.documentElement = {lang};
  document.cookie = '_ga=old; _ga_EXAMPLE=old; unrelated=keep';
  document.createElement = tag => new Element(tag);
  const location = {
    hostname: host,
    origin: `https://${host}`,
    pathname: path,
    search: '?email=private@example.com&utm_source=sensitive',
    hash: '#secret'
  };
  let stored = saved;
  const localStorage = {
    getItem(name) { assert.equal(name, key); if (blockedStorage) throw new Error('Storage blocked'); return stored; },
    setItem(name, value) { assert.equal(name, key); if (blockedStorage) throw new Error('Storage blocked'); stored = value; }
  };
  const observers = [];
  class MutationObserver {
    constructor(callback) { observers.push(callback); }
    observe() {}
  }
  class Clock extends Date { static now() { return clock; } }
  const context = {window, document, location, localStorage, MutationObserver, Date: Clock, URL};
  vm.runInNewContext(source, context, {filename: 'analytics.js'});
  const calls = () => (window.dataLayer || []).map(call => Array.from(call));
  const events = name => plain(calls().filter(call => call[0] === 'event' && (!name || call[1] === name)));
  const panel = () => document.body.children.find(child => child.className === 'localio-analytics-consent');
  const choose = choice => panel().querySelector(`[data-choice="${choice}"]`).emit('click');
  const click = (href, {placement = 'content', nested = false, type = 'click', ...options} = {}) => {
    const parent = new Element(placement === 'header' || placement === 'footer' ? placement : placement === 'article' ? 'article' : 'section');
    parent.className = placement === 'hero' ? 'hero' : placement === 'article' ? 'prose story-article' : '';
    const link = new Element('a', parent);
    link.href = href;
    link.textContent = 'Never collect arbitrary private link text';
    const target = nested ? new Element('img', link) : link;
    return document.emit(type, {target, ...options});
  };
  return {window, document, location, calls, events, panel, choose, click, observers, scripts: () => document.head.children,
    setSaved(value) { stored = value; }, stored: () => stored, advance(ms) { clock += ms; }};
}

test('unknown or denied consent makes no Google request and emits no click events', () => {
  for (const saved of [null, savedChoice('denied')]) {
    const h = harness({saved});
    h.click(download);
    h.click(signup);
    h.window.emit('pageshow', {persisted: true});
    assert.equal(h.scripts().length, 0);
    assert.equal(h.calls().length, 0);
    assert.equal(h.window['ga-disable-' + measurementId], true);
  }
});

test('preview hosts and unlisted/private paths do not initialize analytics or a consent UI', () => {
  for (const options of [
    {host: '127.0.0.1'}, {host: 'preview.localiobc.mylocalio.com'}, {host: 'localiobc.mylocalio.com.evil.test'},
    {path: '/404.html'}, {path: '/cs/dekujeme/'}, {path: '/unknown-private-path/'}
  ]) {
    const h = harness({saved: savedChoice('granted'), ...options});
    h.click(download);
    assert.equal(h.scripts().length, 0);
    assert.equal(h.calls().length, 0);
    assert.equal(h.document.body.children.length, 0);
  }
});

test('saved consent loads one SDK with ads denied and a sanitized manual page view', () => {
  const h = harness({saved: savedChoice('granted'), path: '/cs/'});
  assert.equal(h.scripts().length, 1);
  assert.equal(h.scripts()[0].src, 'https://www.googletagmanager.com/gtag/js?id=' + measurementId);
  const consent = plain(h.calls().find(call => call[0] === 'consent'));
  assert.equal(consent[2].analytics_storage, 'granted');
  for (const option of ['ad_storage', 'ad_user_data', 'ad_personalization']) assert.equal(consent[2][option], 'denied');
  const config = plain(h.calls().find(call => call[0] === 'config'))[2];
  assert.equal(config.send_page_view, false);
  assert.equal(config.page_referrer, '');
  assert.equal(config.page_location, 'https://localiobc.mylocalio.com/cs/');
  assert.equal(config.allow_google_signals, false);
  assert.equal(config.allow_ad_personalization_signals, false);
  assert.deepEqual(h.events('page_view')[0][2], {
    page_location: 'https://localiobc.mylocalio.com/cs/', page_referrer: '',
    page_title: 'LocalioBC — /cs/', send_to: measurementId
  });
});

test('native mouse, nested image, keyboard click, modified click and middle click each count once', () => {
  const h = harness({saved: savedChoice('granted')});
  h.click(download, {placement: 'hero'});
  h.click(signup, {placement: 'header', nested: true});
  h.click(download, {placement: 'article', detail: 0}); // Enter activation is a native click.
  h.click(signup, {placement: 'content', ctrlKey: true});
  h.click(download, {type: 'auxclick', button: 1, placement: 'footer'});
  assert.equal(h.events('file_download').length, 3);
  assert.equal(h.events('bunny_signup_click').length, 2);
  assert.deepEqual(h.events().slice(1).map(event => event[2].link_placement), ['hero', 'header', 'article', 'content', 'footer']);
  assert.equal(h.scripts().length, 1);
});

test('right click, cancelled actions and non-link targets produce no action event', () => {
  const h = harness({saved: savedChoice('granted')});
  h.click(download, {type: 'click', button: 1});
  h.click(download, {type: 'auxclick', button: 2});
  h.click(download, {defaultPrevented: true});
  h.document.emit('click', {target: new Element('button')});
  h.document.emit('click', {target: {}});
  assert.equal(h.events().length, 1);
});

test('only vetted HTTPS release and affiliate destinations are classified', () => {
  const h = harness({saved: savedChoice('granted')});
  for (const href of [
    'javascript:alert(1)', 'not a URL', download.replace('https:', 'http:'),
    download.replace('github.com', 'github.com.evil.test'), download.replace('v1.3.0/', 'v1.2.0/'),
    download.replace('github.com', 'user:password@github.com'),
    'https://bunny.net/', 'https://bunny.net/docs/?ref=gm93y8cppz',
    'https://bunny.net.evil.test/?ref=gm93y8cppz', 'https://bunny.net/?ref=other',
    'https://github.com/bradacz/LocalioBC'
  ]) h.click(href);
  assert.equal(h.events().length, 1);
});

test('click payloads never contain link text, referral codes, arbitrary URLs, query or fragments', () => {
  const h = harness({saved: savedChoice('granted'), path: '/cs/blog/bunny-hosting-videa/'});
  h.click(download + '?secret=private-download-token#private', {placement: 'article'});
  h.click(signup + '&secret=private-affiliate-token#private', {placement: 'article'});
  const serialized = JSON.stringify(h.events());
  for (const secret of ['private', '?', '#', 'gm93y8cppz', 'utm_source', 'link_text', 'link_url']) assert.ok(!serialized.includes(secret), secret);
  const downloadPayload = h.events('file_download')[0][2];
  assert.equal(downloadPayload.file_name, 'LocalioBC-1.3.0-universal.dmg');
  assert.equal(downloadPayload.file_extension, 'dmg');
  assert.equal(downloadPayload.link_domain, 'github.com');
  assert.equal(downloadPayload.page_location, 'https://localiobc.mylocalio.com/cs/blog/bunny-hosting-videa/');
  assert.equal(downloadPayload.page_referrer, '');
  assert.equal(h.events('bunny_signup_click')[0][2].link_domain, 'bunny.net');
});

test('normal pageshow and duplicate navigation notifications do not duplicate page views', () => {
  const h = harness({saved: savedChoice('granted')});
  h.window.emit('pageshow', {persisted: false});
  h.window.emit('popstate');
  h.window.emit('localio:page');
  assert.equal(h.events('page_view').length, 1);
  h.location.pathname = '/cs/';
  h.window.emit('popstate');
  h.window.emit('localio:page');
  assert.equal(h.events('page_view').length, 2);
  h.location.pathname = '/private/';
  h.window.emit('popstate');
  h.click(download);
  assert.equal(h.events().length, 2);
});

test('each bfcache restore counts one new visit, followed by popstate without a duplicate', () => {
  const h = harness({saved: savedChoice('granted')});
  for (let visit = 2; visit <= 3; visit++) {
    h.window.emit('pageshow', {persisted: true});
    h.window.emit('popstate');
    h.window.emit('localio:page');
    assert.equal(h.events('page_view').length, visit);
  }
  assert.equal(h.scripts().length, 1);
});

test('bfcache restore rechecks consent revoked elsewhere before any new telemetry', () => {
  const h = harness({saved: savedChoice('granted')});
  h.setSaved(savedChoice('denied'));
  h.window.emit('pageshow', {persisted: true});
  h.click(download);
  assert.equal(h.events().length, 1);
  assert.equal(h.window['ga-disable-' + measurementId], true);
  assert.equal(h.panel().hidden, true);
  h.setSaved(null);
  h.window.emit('pageshow', {persisted: true});
  assert.equal(h.panel().hidden, false);
  assert.equal(h.events().length, 1);
});

test('grant, revoke and regrant never reload the SDK or replay clicks made without consent', () => {
  const h = harness();
  h.click(download);
  h.choose('granted');
  h.click(download);
  h.choose('denied');
  h.click(signup);
  assert.equal(h.window['ga-disable-' + measurementId], true);
  assert.ok(h.document.cookie.includes('Max-Age=0'));
  h.choose('granted');
  h.click(signup);
  assert.equal(h.events('page_view').length, 2);
  assert.equal(h.events('file_download').length, 1);
  assert.equal(h.events('bunny_signup_click').length, 1);
  assert.equal(h.scripts().length, 1);
  assert.equal(h.window['ga-disable-' + measurementId], false);
});

test('cross-tab consent changes gate action events and clear resets consent', () => {
  const h = harness();
  h.setSaved(savedChoice('granted'));
  h.window.emit('storage', {key: 'unrelated'});
  assert.equal(h.scripts().length, 0);
  h.window.emit('storage', {key});
  h.click(signup);
  h.setSaved(savedChoice('denied'));
  h.window.emit('storage', {key});
  h.click(download);
  h.setSaved(null);
  h.window.emit('storage', {key: null});
  assert.equal(h.events('page_view').length, 1);
  assert.equal(h.events('bunny_signup_click').length, 1);
  assert.equal(h.events('file_download').length, 0);
  assert.equal(h.panel().hidden, false);
});

test('invalid, future and expired choices do not load Google', () => {
  for (const saved of ['invalid JSON', '{}', savedChoice('other'), savedChoice('granted', now + 1), savedChoice('granted', now - 180 * 86400000)]) {
    const h = harness({saved});
    assert.equal(h.scripts().length, 0);
    assert.equal(h.panel().hidden, false);
  }
});

test('blocked storage allows explicit consent for the current page and remains revocable', () => {
  const h = harness({blockedStorage: true});
  h.choose('granted');
  h.click(download);
  h.choose('denied');
  h.click(signup);
  assert.equal(h.events('file_download').length, 1);
  assert.equal(h.events('bunny_signup_click').length, 0);
  assert.equal(h.scripts().length, 1);
});

test('saved consent expires on a long-open document before the next click is measured', () => {
  const h = harness({saved: savedChoice('granted', now - 180 * 86400000 + 1000)});
  h.advance(999);
  h.click(download);
  assert.equal(h.events('file_download').length, 1);
  h.advance(1);
  h.click(download);
  h.click(signup);
  h.location.pathname = '/cs/';
  h.window.emit('popstate');
  assert.equal(h.events('file_download').length, 1);
  assert.equal(h.events('bunny_signup_click').length, 0);
  assert.equal(h.events('page_view').length, 1);
  assert.equal(h.window['ga-disable-' + measurementId], true);
  assert.equal(h.panel().hidden, false);
  assert.equal(h.panel().querySelector('[data-close]').hidden, true);
  assert.ok(h.document.cookie.includes('Max-Age=0'));
});

test('explicit consent also expires before page events when storage is blocked, and can be renewed', () => {
  const h = harness({blockedStorage: true});
  h.choose('granted');
  h.advance(180 * 86400000 - 1);
  h.click(signup);
  assert.equal(h.events('bunny_signup_click').length, 1);
  h.advance(1);
  h.location.pathname = '/cs/';
  h.window.emit('localio:page');
  h.click(download);
  assert.equal(h.events('page_view').length, 1);
  assert.equal(h.events('file_download').length, 0);
  assert.equal(h.window['ga-disable-' + measurementId], true);
  assert.equal(h.panel().hidden, false);
  h.choose('granted');
  h.click(download);
  assert.equal(h.events('page_view').length, 2);
  assert.equal(h.events('file_download').length, 1);
  assert.equal(h.window['ga-disable-' + measurementId], false);
  assert.equal(h.scripts().length, 1);
});

test('localized consent explains page views, downloads and Bunny clicks, and language changes remain supported', () => {
  const h = harness();
  assert.match(h.panel().querySelector('span').textContent, /page views.*download and Bunny\.net links/);
  h.document.documentElement.lang = 'cs';
  h.observers[0]();
  assert.match(h.panel().querySelector('span').textContent, /zobrazení stránek.*stažení aplikace.*Bunny\.net/);
  assert.equal(h.panel().querySelector('a').href, '/cs/privacy/');
});

test('every current website DMG CTA matches the vetted analytics destination', () => {
  for (const page of ['index.html', 'cs/index.html', 'blog/localiobc-1-3-bunny-storage/index.html', 'cs/blog/localiobc-1-3-bunny-storage/index.html']) {
    const html = readFileSync(new URL('../public/' + page, import.meta.url), 'utf8');
    const links = [...html.matchAll(/href="(https:\/\/github\.com\/bradacz\/LocalioBC\/releases\/download\/[^\"]+)"/g)].map(match => match[1]);
    assert.ok(links.length > 0, page);
    assert.ok(links.every(link => link === download), 'Update analytics release destination with the download CTA: ' + page);
  }
});
