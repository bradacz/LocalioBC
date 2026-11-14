#!/usr/bin/env python3
"""Sign a final DMG and publish a signed Sparkle feed with embedded EN/CS notes.

Run only after signing, notarizing and stapling the app and disk image. The
private Ed25519 key stays in the macOS Keychain; this script never exports it.
"""
import argparse
import base64
from datetime import datetime, timezone
from email.utils import format_datetime
import hashlib
from pathlib import Path
import plistlib
import subprocess
import tempfile
import xml.etree.ElementTree as ET

SPARKLE = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
XML = 'http://www.w3.org/XML/1998/namespace'
WEBSITE = 'https://localiobc.mylocalio.com'
ET.register_namespace('sparkle', SPARKLE)


def run(*arguments):
    return subprocess.run(arguments, check=True, capture_output=True, text=True).stdout.strip()


def build_feed(args):
    project = Path(__file__).resolve().parent.parent
    info = plistlib.loads((args.app / 'Contents/Info.plist').read_bytes())
    version, build = info['CFBundleShortVersionString'], info['CFBundleVersion']
    assert build.isdecimal(), 'Use a monotonically increasing numeric build number'
    assert args.dmg.name == f'LocalioBC-{version}-universal.dmg', 'DMG version does not match app'
    sign = args.tools_dir / 'sign_update'
    keys = args.tools_dir / 'generate_keys'
    public = run(str(keys), '--account', args.account, '-p')
    assert public == info['SUPublicEDKey'], 'Keychain public key does not match the app'
    assert info['SUFeedURL'] == WEBSITE + '/updates/appcast.xml'
    assert info.get('SURequireSignedFeed') and info.get('SUVerifyUpdateBeforeExtraction')
    # Verify Apple signatures/tickets before applying the independent Sparkle signature.
    run('/usr/bin/codesign', '--verify', '--deep', '--strict', str(args.app))
    run('/usr/bin/xcrun', 'stapler', 'validate', str(args.app))
    run('/usr/bin/codesign', '--verify', str(args.dmg))
    run('/usr/bin/xcrun', 'stapler', 'validate', str(args.dmg))
    digest = hashlib.sha256(args.dmg.read_bytes()).hexdigest()
    signature = run(str(sign), '--account', args.account, '-p', str(args.dmg))
    assert len(base64.b64decode(signature, validate=True)) == 64
    run(str(sign), '--account', args.account, '--verify', str(args.dmg), signature)
    assert hashlib.sha256(args.dmg.read_bytes()).hexdigest() == digest, 'Signing mutated the DMG'

    feed = args.output or project / 'website/public/updates/appcast.xml'
    feed.parent.mkdir(parents=True, exist_ok=True)
    if feed.exists():
        run(str(sign), '--account', args.account, '--verify', str(feed))
        root = ET.parse(feed).getroot()
        channel = root.find('channel')
        assert channel is not None
    else:
        root = ET.Element('rss', {'version': '2.0'})
        channel = ET.SubElement(root, 'channel')
        ET.SubElement(channel, 'title').text = 'LocalioBC updates'
        ET.SubElement(channel, 'link').text = WEBSITE
        ET.SubElement(channel, 'description').text = 'Signed updates for the direct-download edition of LocalioBC.'
        ET.SubElement(channel, 'language').text = 'en'

    publication = format_datetime(datetime.now(timezone.utc), usegmt=True)
    for existing in list(channel.findall('item')):
        old_build = existing.findtext(f'{{{SPARKLE}}}version', default='0')
        assert old_build.isdecimal() and int(old_build) <= int(build), 'Refusing to downgrade the feed'
        if old_build == build:
            enclosure = existing.find('enclosure')
            assert enclosure is not None and enclosure.get(f'{{{SPARKLE}}}edSignature') == signature, \
                'Refusing to replace an existing build with a different payload'
            publication = existing.findtext('pubDate') or publication
            channel.remove(existing)

    item = ET.Element('item')
    ET.SubElement(item, 'title').text = f'LocalioBC {version}'
    ET.SubElement(item, 'link').text = WEBSITE
    ET.SubElement(item, f'{{{SPARKLE}}}version').text = build
    ET.SubElement(item, f'{{{SPARKLE}}}shortVersionString').text = version
    minimum = info['LSMinimumSystemVersion'].split('.')
    ET.SubElement(item, f'{{{SPARKLE}}}minimumSystemVersion').text = '.'.join((minimum + ['0', '0'])[:3])
    ET.SubElement(item, 'pubDate').text = publication
    # Embedded markdown avoids extra requests, unsigned notes and legacy HTML web views.
    for language in ('en', 'cs'):
        path = project / 'docs/releases' / f'v{version}.{language}.md'
        notes = ET.SubElement(item, 'description', {f'{{{XML}}}lang': language, f'{{{SPARKLE}}}format': 'markdown'})
        notes.text = path.read_text(encoding='utf-8')
    ET.SubElement(item, f'{{{SPARKLE}}}fullReleaseNotesLink').text = WEBSITE + '/#news-title'
    ET.SubElement(item, 'enclosure', {
        'url': f'https://github.com/bradacz/LocalioBC/releases/download/v{version}/{args.dmg.name}',
        f'{{{SPARKLE}}}edSignature': signature,
        'length': str(args.dmg.stat().st_size),
        'type': 'application/octet-stream',
    })
    channel.insert(4, item)
    ET.indent(root, space='  ')
    with tempfile.TemporaryDirectory(prefix='LocalioBC-feed-') as staging:
        temporary = Path(staging) / 'appcast.xml'
        ET.ElementTree(root).write(temporary, encoding='utf-8', xml_declaration=True)
        run(str(sign), '--account', args.account, str(temporary))
        run(str(sign), '--account', args.account, '--verify', str(temporary))
        # Byte-for-byte copy: build and hosting must not rewrite signed XML.
        feed.write_bytes(temporary.read_bytes())
    args.dmg.with_suffix('.dmg.edsig').write_text(signature + '\n', encoding='ascii')
    print(f'Generated signed feed for {version} (build {build}); DMG SHA-256 {digest}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('dmg', type=Path)
    parser.add_argument('--app', type=Path, required=True)
    parser.add_argument('--tools-dir', type=Path, required=True)
    parser.add_argument('--account', default='com.localiolabs.LocalioBC.sparkle')
    parser.add_argument('--output', type=Path)
    arguments = parser.parse_args()
    try:
        build_feed(arguments)
    except (AssertionError, KeyError, ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'Update feed generation failed: {error}\n')
