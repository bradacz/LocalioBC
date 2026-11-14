#!/usr/bin/env python3
"""Validate packaged direct/Store apps without exposing signing account details."""
import argparse
import base64
from pathlib import Path
import plistlib
import subprocess


def run(*args):
    result = subprocess.run(args, check=True, capture_output=True)
    return result.stdout, result.stderr


def entitlements(path):
    output, _ = run('/usr/bin/codesign', '--display', '--entitlements', ':-', str(path))
    return plistlib.loads(output) if output.strip() else {}


def signing_details(path):
    _, output = run('/usr/bin/codesign', '--display', '--verbose=4', str(path))
    return output.decode()


def macho_files(app):
    magics = {b'\xfe\xed\xfa\xce', b'\xce\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xcf\xfa\xed\xfe',
              b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca', b'\xca\xfe\xba\xbf', b'\xbf\xba\xfe\xca'}
    for path in app.rglob('*'):
        if path.is_file() and not path.is_symlink():
            with path.open('rb') as source:
                if source.read(4) in magics:
                    yield path


def validate(app, channel, version=None, build=None, store_archive=False):
    assert not store_archive or channel == 'store', '--store-archive requires the Store channel'
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    assert info['CFBundleDevelopmentRegion'] == 'en', 'English must be the fallback language'
    if version:
        assert info['CFBundleShortVersionString'] == version, 'Unexpected release version'
    if build:
        assert info['CFBundleVersion'] == build, 'Unexpected build number'
    run('/usr/bin/codesign', '--verify', '--deep', '--strict', str(app))
    binary = app / 'Contents/MacOS' / info['CFBundleExecutable']
    run('/usr/bin/lipo', str(binary), '-verify_arch', 'arm64', 'x86_64')
    grants = entitlements(app)
    assert grants.get('com.apple.security.app-sandbox') is True, 'Sandbox is required'
    assert grants.get('com.apple.security.files.user-selected.read-write') is True
    assert not grants.get('com.apple.security.get-task-allow'), 'Release allows debugger attachment'
    assert (app / 'Contents/Resources/LICENSE').is_file(), 'License is missing'
    privacy = plistlib.loads((app / 'Contents/Resources/PrivacyInfo.xcprivacy').read_bytes())
    assert privacy['NSPrivacyTracking'] is False
    assert not privacy['NSPrivacyCollectedDataTypes']
    exception = 'com.apple.security.temporary-exception.mach-lookup.global-name'
    if channel == 'store':
        assert not any(key.startswith('SU') for key in info), 'Store contains updater configuration'
        assert not grants.get(exception), 'Store contains updater sandbox exceptions'
        assert not grants.get('com.apple.security.network.client'), 'Store unexpectedly has network access'
        # Automatic signing can omit the profile in the development-signed archive.
        # Export adds it; the final package must always pass the default strict check.
        if not store_archive:
            assert (app / 'Contents/embedded.provisionprofile').is_file(), 'Store profile is missing'
        for path in app.rglob('*'):
            assert 'sparkle' not in path.name.lower(), 'Store contains Sparkle files'
            if path.name == 'Info.plist' and path.is_file():
                nested = plistlib.loads(path.read_bytes())
                assert 'sparkle' not in nested.get('CFBundleIdentifier', '').lower(), 'Store contains a Sparkle helper'
        for executable in macho_files(app):
            libraries, _ = run('/usr/bin/otool', '-L', str(executable))
            assert b'sparkle' not in libraries.lower(), 'Store executable links Sparkle'
    else:
        public_key = base64.b64decode(info['SUPublicEDKey'], validate=True)
        assert len(public_key) == 32, 'Invalid Ed25519 public key'
        assert info['SUFeedURL'] == 'https://localiobc.mylocalio.com/updates/appcast.xml'
        for key in ('SURequireSignedFeed', 'SUVerifyUpdateBeforeExtraction',
                    'SUEnableInstallerLauncherService', 'SUEnableDownloaderService'):
            assert info.get(key) is True, f'{key} must be enabled'
        assert info.get('SUSignedFeedFailureExpirationInterval') == 0
        assert info.get('SUEnableSystemProfiling') is False
        assert info.get('SUAutomaticallyUpdate') is False
        assert not grants.get('com.apple.security.network.client'), 'Downloader service owns update connections'
        expected = {info['CFBundleIdentifier'] + suffix for suffix in ('-spks', '-spki')}
        assert set(grants.get(exception, [])) == expected, 'Updater sandbox exceptions are missing'
        framework = app / 'Contents/Frameworks/Sparkle.framework'
        assert framework.is_dir(), 'Direct release is missing Sparkle'
        versioned = framework / 'Versions/B'
        nested_code = [versioned / 'XPCServices/Installer.xpc',
                       versioned / 'XPCServices/Downloader.xpc',
                       versioned / 'Autoupdate', versioned / 'Updater.app', framework, app]
        team = next((line for line in signing_details(app).splitlines() if line.startswith('TeamIdentifier=')), None)
        assert team and team != 'TeamIdentifier=not set', 'Signing team is missing'
        for code in nested_code:
            assert code.exists(), f'Missing updater component: {code.name}'
            run('/usr/bin/codesign', '--verify', '--strict', str(code))
            details = signing_details(code)
            assert 'Authority=Developer ID Application:' in details, f'{code.name} is not Developer ID signed'
            assert team in details.splitlines(), f'{code.name} has a different signing team'
            assert '(runtime)' in details, f'{code.name} lacks hardened runtime'
            assert not entitlements(code).get('com.apple.security.get-task-allow'), f'{code.name} allows debugging'
        for executable in macho_files(framework):
            run('/usr/bin/lipo', str(executable), '-verify_arch', 'arm64', 'x86_64')
    print(f'{channel.capitalize()} application: universal architecture, signature, sandbox, privacy and distribution isolation OK')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('channel', choices=('direct', 'store'))
    parser.add_argument('app', type=Path)
    parser.add_argument('--version')
    parser.add_argument('--build')
    parser.add_argument('--store-archive', action='store_true',
                        help='Validate a pre-export Store archive; require its profile after export')
    arguments = parser.parse_args()
    try:
        validate(arguments.app, arguments.channel, arguments.version, arguments.build, arguments.store_archive)
    except (AssertionError, KeyError, ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'Release validation failed: {error}\n')
