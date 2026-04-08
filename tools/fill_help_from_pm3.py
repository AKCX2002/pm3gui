#!/usr/bin/env python3
import re
import subprocess
import sys
from pathlib import Path
import yaml

PM3_PATH = sys.argv[1] if len(sys.argv) > 1 else '/root/dev/proxmark3/pm3'

root = Path(__file__).resolve().parents[1]
pm3_commands = root / 'lib' / 'services' / 'pm3_commands.dart'
help_yaml_path = root / 'docs' / 'pm3_commands_help.yaml'
backup = help_yaml_path.with_suffix('.yaml.bak')

if not pm3_commands.exists():
    print('pm3_commands.dart not found:', pm3_commands)
    sys.exit(2)
if not help_yaml_path.exists():
    print('help yaml not found:', help_yaml_path)
    sys.exit(2)

# Parse pm3_commands.dart for simple static returns: pattern => '...'
text = pm3_commands.read_text()
pattern = re.compile(r'static\s+String\s+(\w+)\s*\([^)]*\)\s*=>\s*\'([^\']+)\'\s*;')
# Also match return '...' inside function body
pattern2 = re.compile(r'static\s+String\s+(\w+)\s*\([^)]*\)\s*\{[^}]*return\s*\'([^\']+)\'\s*;[^}]*\}')

mapping = {}
for m in pattern.finditer(text):
    mapping[m.group(1)] = m.group(2)
for m in pattern2.finditer(text):
    mapping[m.group(1)] = m.group(2)

print(f'Found {len(mapping)} direct method->cmd mappings')

# Load YAML
with help_yaml_path.open() as f:
    data = yaml.safe_load(f)

# Backup
backup.write_text(help_yaml_path.read_text())

# Helper to run pm3 help
def run_help(cmd_str):
    full = [PM3_PATH] + cmd_str.split() + ['--help']
    try:
        r = subprocess.run(full, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
        return r.stdout.decode('utf-8', errors='ignore')
    except Exception as e:
        return None

# For each class/method in YAML, try to fill description and params
changed = 0
for cls in data.get('classes', []):
    methods = cls.get('methods', [])
    for m in methods:
        name = m.get('name')
        if not name:
            continue
        if m.get('description'):
            # skip if already filled
            if m['description'].strip():
                continue
        cmd = mapping.get(name)
        if not cmd:
            # try guess: prefix from class name + method
            class_name = cls.get('class')
            if class_name and class_name.endswith('Cmd'):
                base = class_name[:-3]
                # insert spaces between letters and digits and before caps
                s = re.sub(r'(?<=[a-zA-Z])(?=[0-9])', ' ', base)
                s = re.sub(r'(?<=[0-9])(?=[A-Z])', ' ', s)
                s = re.sub(r'(?<=[a-z])(?=[A-Z])', ' ', s)
                prefix = s.lower()
                cmd = (prefix + ' ' + name).strip()
        if not cmd:
            print('no cmd for', name)
            continue
        out = run_help(cmd)
        if not out:
            print('help empty for', cmd)
            continue
        # Parse first paragraph as description
        first = out.strip().split('\n\n')[0].strip()
        # strip lines of usage/Options etc
        # Find params: lines starting with spaces then '-' or '--'
        params = []
        for line in out.splitlines():
            line = line.strip()
            if line.startswith('-') or line.startswith('--'):
                parts = line.split()[:1]
                params.append({'name': parts[0], 'desc': line})
        m['description'] = first
        m['params'] = params
        changed += 1
        print('filled', name, '->', cmd)

# write back
if changed > 0:
    help_yaml_path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
    print('Updated', help_yaml_path, 'with', changed, 'entries')
else:
    print('No changes')

print('done')
