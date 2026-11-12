#!/usr/bin/env python3
"""Build the static, tracker-free product, support and privacy website."""
from pathlib import Path
import shutil
root = Path(__file__).resolve().parent
output = root / 'dist'
if output.exists():
    shutil.rmtree(output)
shutil.copytree(root / 'public', output)
print('Built website/dist')
