"""Read-only inventory of actual Maven artifacts resolved by probe.gradle."""
import argparse
from collections import defaultdict
from hashlib import sha256
from io import BytesIO
from pathlib import Path
from zipfile import ZipFile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('output', type=Path, help='Directory populated by resolve.gradle')
parser.add_argument('--aar', action='append', type=Path, default=[], help='Optional Core AAR to hash and inspect; repeat for multiple versions')
args = parser.parse_args()
root = args.output
for label in ['baseline-debug', 'baseline-release', 'candidate-debug', 'candidate-release']:
    entries = [line.split('\t') for line in (root / (label + '-artifacts.tsv')).read_text().splitlines()]
    # A requested @aar and its transitive module can identify the very same file twice.
    artifacts = {str(Path(path).resolve()): coordinate for coordinate, path in entries}
    owners = defaultdict(set)
    all_owners = defaultdict(set)
    for path, coordinate in artifacts.items():
        with ZipFile(path) as archive:
            jars = [(path, archive)] if path.endswith('.jar') else [
                (path + '!' + n, ZipFile(BytesIO(archive.read(n))))
                for n in archive.namelist() if n == 'classes.jar' or (n.startswith('libs/') and n.endswith('.jar'))]
            for origin, jar in jars:
                for name in jar.namelist():
                    if name.endswith('.class'):
                        all_owners[name].add(origin)
                        if name.startswith('org/infobip/mobile/messaging/'):
                            owners[name].add(origin)
    duplicates = {n: sorted(o) for n, o in owners.items() if len(o) > 1}
    coordinates = set(artifacts.values())
    print(label)
    print('  artifact records:', len(entries), 'unique artifact files:', len(artifacts))
    print('  org.infobip.mobile.messaging classes:', len(owners), 'duplicate classes:', len(duplicates))
    print('  all duplicate class names:', ', '.join(n for n,o in all_owners.items() if len(o)>1) or 'none')
    print('  modules:', ', '.join(sorted(c for c in coordinates if c.startswith(('com.infobip:', 'com.google.firebase:', 'com.google.android.gms:')))))
    assert not duplicates, duplicates
    assert not any(c.startswith('com.infobip:infobip-mobile-messaging-android-sdk:') for c in coordinates)
    assert not any(c.startswith('com.infobip:infobip-rtc-ui:') for c in coordinates)
    assert 'com.infobip:infobip-mobile-messaging-huawei-sdk:8.14.0' in coordinates
    if label.startswith('candidate'):
        assert 'com.infobip:infobip-rtc:2.5.28' in coordinates
        assert 'com.google.firebase:firebase-messaging:22.0.0' in coordinates
    else:
        assert not any(c.startswith(('com.google.firebase:', 'com.google.android.gms:', 'com.infobip:infobip-rtc:')) for c in coordinates)
    print('  dependency isolation assertions: PASS')
    (root / (label + '-coordinates.txt')).write_text('\n'.join(sorted(coordinates))+'\n')

print('Artifact SHA-256:')
for path in args.aar:
    print(path.name, sha256(path.read_bytes()).hexdigest())
    with ZipFile(path) as aar, ZipFile(BytesIO(aar.read('classes.jar'))) as jar:
        assert not any(n.startswith('org/infobip/mobile/messaging/') for n in jar.namelist())
if args.aar:
    print('PASS: inspected Core archives contain no Mobile Messaging class definitions')
