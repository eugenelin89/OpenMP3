#!/usr/bin/env python3
"""Serial bounded live trials. Output is aggregate; root links stay in input files."""
import argparse
import json
import statistics
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--root-file', required=True, type=Path)
parser.add_argument('--output-dir', required=True, type=Path)
parser.add_argument('--runs', type=int, default=3)
args = parser.parse_args()
if not 1 <= args.runs <= 10:
    parser.error('runs must be between 1 and 10 (experimental safety bound)')
root = Path(__file__).resolve().parents[1]
args.output_dir.mkdir(parents=True, exist_ok=True)
reports = []
for index in range(args.runs):
    output = args.output_dir / f'run-{index+1}.json'
    if output.exists():
        parser.error(f'refusing to overwrite an existing measurement: {output}')
    command = [str(root / '.build/debug/drive-probe'), '--root-file', str(args.root_file.resolve()), '--output', str(output)]
    if index == 0:
        command.append('--ranges')
    subprocess.run(command, check=True, timeout=180)
    reports.append(json.loads(output.read_text()))
summary = {
    'procedure': 'Serial live anonymous runs; first run includes separate media-range probes; no cache/cookies',
    'runs': len(reports),
    'scan_seconds': [r['scan']['elapsedSeconds'] for r in reports],
    'median_scan_seconds': statistics.median(r['scan']['elapsedSeconds'] for r in reports),
    'maximum_scan_seconds': max(r['scan']['elapsedSeconds'] for r in reports),
    'listing_requests': [r['scan']['listingRequests'] for r in reports],
    'root_validation_requests': [r['scan']['metadataRequests'] for r in reports],
    'retries': [r['scan']['retries'] for r in reports],
    'discovered_tracks': [r['discoveredTracks'] for r in reports],
    'states': [r['scan']['state'] for r in reports],
    'budget_claim': 'Measurements only; not a representative-workload budget validation',
}
(args.output_dir / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
