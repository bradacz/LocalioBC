#!/usr/bin/env python3
"""Build the static, consent-based product, support and privacy website."""
from pathlib import Path
from html.parser import HTMLParser
import shutil
from urllib.parse import urlsplit, parse_qs
root = Path(__file__).resolve().parent
# Public referral URL verified in the owner's Bunny Affiliate dashboard.
affiliate = 'https://bunny.net?ref=gm93y8cppz'
parsed = urlsplit(affiliate)
assert parsed.scheme == 'https' and parsed.netloc == 'bunny.net'
assert parse_qs(parsed.query).get('ref', [''])[0], 'A verified affiliate reference is required'


class AffiliateLinks(HTMLParser):
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        hostname = urlsplit(attrs.get('href', '')).hostname if tag == 'a' else None
        bunny_host = hostname == 'bunny.net' or (hostname is not None and hostname.endswith('.bunny.net'))
        if tag == 'a' and (bunny_host or 'bunny-signup' in attrs.get('class', '').split()):
            assert attrs.get('href') == affiliate, 'Every public Bunny link must use the verified affiliate URL'
            assert 'sponsored' in attrs.get('rel', '').split(), 'Affiliate links must be disclosed to search engines'


for page in (root / 'public').rglob('*.html'):
    AffiliateLinks().feed(page.read_text())
output = root / 'dist'
if output.exists():
    shutil.rmtree(output)
shutil.copytree(root / 'public', output, ignore=shutil.ignore_patterns('*.sb-*', '.DS_Store'))
print('Built website/dist')
