#!/usr/bin/env python3
"""Read a target's release version directly from the Xcode project."""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('target')
parser.add_argument('configuration')
parser.add_argument('field', choices=('MARKETING_VERSION', 'CURRENT_PROJECT_VERSION'))
arguments = parser.parse_args()
project = Path(__file__).resolve().parent.parent / 'LocalioBC.xcodeproj/project.pbxproj'
data = json.loads(subprocess.check_output(['/usr/bin/plutil', '-convert', 'json', '-o', '-', str(project)]))
objects = data['objects']
targets = [item for item in objects.values() if item.get('isa') == 'PBXNativeTarget' and item.get('name') == arguments.target]
assert len(targets) == 1, 'Expected exactly one matching app target'
configurations = objects[targets[0]['buildConfigurationList']]['buildConfigurations']
settings = [objects[key]['buildSettings'] for key in configurations if objects[key]['name'] == arguments.configuration]
assert len(settings) == 1, 'Expected exactly one matching configuration'
print(settings[0][arguments.field])
