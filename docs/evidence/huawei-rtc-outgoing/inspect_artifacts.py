"""Scan actual debug/release runtime AARs, embedded JARs, external JARs and the plugin JAR."""
import argparse
from collections import defaultdict
from hashlib import sha256
from io import BytesIO
from pathlib import Path
from zipfile import ZipFile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('output', type=Path)
args = parser.parse_args()

for variant in ['debug', 'release']:
    records = [line.split('\t') for line in (args.output / f'{variant}-artifacts.tsv').read_text().splitlines()]
    artifacts = {str(Path(path).resolve()): coordinate for coordinate, path in records}
    classes = defaultdict(set)
    for path, coordinate in artifacts.items():
        with ZipFile(path) as archive:
            jars = [(path, archive)] if path.endswith('.jar') else [
                (path + '!' + n, ZipFile(BytesIO(archive.read(n))))
                for n in archive.namelist()
                if n == 'classes.jar' or (n.startswith('libs/') and n.endswith('.jar'))
            ]
            for origin, jar in jars:
                for name in jar.namelist():
                    if name.endswith('.class'):
                        classes[name].add(origin)
    modules = set(artifacts.values())
    mm = {name: owners for name, owners in classes.items() if name.startswith('org/infobip/mobile/messaging/')}
    duplicates = [name for name, owners in mm.items() if len(owners) > 1]
    print(variant)
    print(f'  records: {len(records)}; unique artifacts including plugin: {len(artifacts)}')
    print(f'  Mobile Messaging classes: {len(mm)}; duplicates: {len(duplicates)}')
    print('  all duplicate class entries:', ', '.join(name for name, owners in classes.items() if len(owners) > 1) or 'none')
    assert not duplicates, duplicates
    for required in ['infobip-mobile-messaging-huawei-sdk:8.14.0', 'infobip-rtc:2.5.28']:
        assert 'com.infobip:' + required in modules
    for forbidden in ['infobip-mobile-messaging-android-sdk:', 'infobip-rtc-ui:']:
        assert not any(c.startswith('com.infobip:' + forbidden) for c in modules)
    assert not any(n.startswith('com/infobip/webrtc/ui/') for n in classes)
    assert 'com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcManager.class' in classes
    print('  standard MM core: ABSENT; RTC UI classes/runtime: ABSENT')
    print('  dependency assertions: PASS')
    print('  Infobip / Firebase / GMS modules:')
    for coordinate in sorted(modules):
        if coordinate.startswith(('com.infobip:', 'com.google.firebase:', 'com.google.android.gms:')):
            print('   ', coordinate)
    for path, coordinate in artifacts.items():
        if coordinate == 'com.infobip:infobip-rtc:2.5.28':
            print('  Core AAR SHA-256:', sha256(Path(path).read_bytes()).hexdigest())
    (args.output / f'{variant}-coordinates.txt').write_text('\n'.join(sorted(modules)) + '\n')
