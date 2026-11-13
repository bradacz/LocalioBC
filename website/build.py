#!/usr/bin/env python3
"""Build the static, consent-based product, support and privacy website."""
from pathlib import Path
import shutil
root = Path(__file__).resolve().parent
output = root / 'dist'
if output.exists():
    shutil.rmtree(output)
shutil.copytree(root / 'public', output, ignore=shutil.ignore_patterns('*.sb-*', '.DS_Store'))
print('Built website/dist')
