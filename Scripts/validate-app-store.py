#!/usr/bin/env python3
"""Check metadata, screenshot format, privacy declarations and optional public URLs."""
import argparse
import json
from pathlib import Path
import plistlib
import struct
import subprocess

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--check-live-urls', action='store_true')
args = parser.parse_args()
limits = {'name': 30, 'subtitle': 30, 'promotional_text': 170, 'keywords': 100, 'description': 4000, 'whats_new': 4000}
report = {'metadata': {}, 'screenshots': [], 'privacy': 'OK', 'public_urls': {}}
for locale in ['en-US', 'cs']:
    folder = root / 'AppStore/metadata' / locale
    fields = {}
    for field, limit in limits.items():
        text = (folder / (field + '.txt')).read_text().strip()
        assert text and len(text) <= limit, (locale, field, len(text), limit)
        if field == 'keywords':
            assert len(text.encode('utf-8')) <= 100, (locale, 'keywords exceed 100 bytes')
        fields[field] = len(text)
    report['metadata'][locale] = fields
    screenshots = sorted((root / 'AppStore/screenshots' / locale).glob('*.png'))
    assert len(screenshots) == 3
    for path in screenshots:
        data = path.read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n'
        width, height = struct.unpack('>II', data[16:24])
        assert (width, height) in [(1280, 800), (1440, 900), (2560, 1600), (2880, 1800)]
        assert data[25] == 2, (path.name, 'RGB PNG without alpha required')
        report['screenshots'].append({'file': str(path.relative_to(root)), 'width': width, 'height': height, 'alpha': False})
    for field in ['marketing_url', 'support_url', 'privacy_url']:
        url = (folder / (field + '.txt')).read_text().strip()
        assert url.startswith('https://localiobc.mylocalio.com/')
        if args.check_live_urls:
            result = subprocess.run(['curl', '--fail', '--silent', '--show-error', '--location',
                '--max-time', '30', '--write-out', '\n%{http_code}', url], check=True, capture_output=True, text=True)
            body, status = result.stdout.rsplit('\n', 1)
            assert status == '200' and 'LocalioBC' in body
            assert 'Privacy Policy' in body or 'Zásady ochrany soukromí' in body or field != 'privacy_url'
            assert 'Sign in to' not in body
            report['public_urls'][url] = int(status)
manifest = plistlib.loads((root / 'PrivacyInfo.xcprivacy').read_bytes())
assert manifest['NSPrivacyTracking'] is False
assert not manifest['NSPrivacyCollectedDataTypes'] and not manifest['NSPrivacyTrackingDomains']
assert len((root / 'AppStore/review/notes-en.txt').read_text()) <= 4000
assert (root / 'AppStore/review/demo-clips.zip').stat().st_size > 0
submission = json.loads((root / 'AppStore/submission.json').read_text())
assert submission['price']['amount'] == '4.99' and submission['price']['currency'] == 'EUR'
assert submission['build'] == '3' and submission['release_mode'] == 'manual'
assert submission['review_contact']['phone'] is None, 'Private phone must remain outside public metadata'
report['status'] = 'passed'
print(json.dumps(report, ensure_ascii=False, indent=2))
