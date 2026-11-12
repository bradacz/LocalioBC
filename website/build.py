#!/usr/bin/env python3
"""Build the static, tracker-free product, support and privacy website."""
from pathlib import Path
import shutil
root = Path(__file__).resolve().parent
shutil.copytree(root / 'public', root / 'dist', dirs_exist_ok=True)
print('Built website/dist')
