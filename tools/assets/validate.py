"""Validate the actual asset delivery against docs/ASSETS_CODEX.md.

Checks independent file names, dimensions, alpha, palettes, exact nearest-neighbor
exports, SVG validity and all local preview links. Run after image imports.
"""
from pathlib import Path
import json
from html.parser import HTMLParser
import xml.etree.ElementTree as ET
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2] / 'Assets' / 'Generated'
ICONS = '''tab-map tab-explore tab-styles tab-profile search mic layers friends locate north
zoom-in zoom-out volume-on volume-off clip share more close back chevron reroute settings
end-route route-options favorite history contact calendar home work fuel parking charging
food fog district badge goal stats streak lock eye-off location-off'''.split()
MANEUVERS = '''straight slight-left left sharp-left slight-right right sharp-right uturn-left
uturn-right roundabout-exit-1 roundabout-exit-2 roundabout-exit-3 roundabout-exit-4 roundabout-exit-5
merge-left merge-right fork-left fork-right ramp-exit-right ramp-exit-left keep-left keep-right
destination destination-left destination-right'''.split()
BLIPS = 'fuel parking food shop charging hospital friend home work destination waypoint'.split()
BADGES = 'first-drive 10-km 100-km night-owl early-bird old-town explorer-25 explorer-50 explorer-100 weekly-goal streak-7 convoy'.split()
CP = 'search style friends zoom-in zoom-out locate home work fuel parking charging favorite history'.split()
errors=[]


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links=[]

    def handle_starttag(self, tag, attrs):
        self.links.extend(value for key,value in attrs if key in ('href','src') and value)


def check(condition,message):
    if not condition: errors.append(message)


def expect(folder,names,suffix):
    wanted={n+suffix for n in names}
    actual={p.name for p in (ROOT/folder).glob('*'+suffix) if '@4x' not in p.name}
    check(actual==wanted, f'{folder}: missing {wanted-actual}, unexpected {actual-wanted}')


for category,prefix,names in [('Icons','ic-',ICONS),('Maneuvers','maneuver-',MANEUVERS),('Blips','blip-',BLIPS)]:
    for style in ('Neon','Western','Pixel'):
        expect(f'{category}/{style}',[prefix+n for n in names],'.png' if style=='Pixel' else '.svg')
expect('Badges',[f'badge-{n}-{t}' for n in BADGES for t in ('gold','silver','bronze','locked')],'.svg')
expect('CarPlay',[f'cp-{n}{s}' for n in CP for s in ('','-list','-map')],'.svg')
expect('Blips/Toy',['blip-'+n for n in BLIPS],'.svg')
expect('Player',['player-neon','player-western','player-toy'],'.svg')
expect('Player',['player-pixel-'+d for d in ('n','ne','e','se','s','sw','w','nw')],'.png')
expect('AppIcon',['appicon-1024','appicon-1024-dark','appicon-1024-tinted'],'.png')
expect('Store',['store-neon','store-western','store-pixel'],'.png')

for p in ROOT.rglob('*.svg'):
    try:
        root=ET.parse(p).getroot()
        rel=p.relative_to(ROOT).as_posix()
        expected=24 if rel.startswith(('Icons/','CarPlay/')) else 96 if rel.startswith('Maneuvers/') else 32 if rel.startswith('Blips/') else 64 if rel.startswith('Player/') else 128
        check(root.get('viewBox')==f'0 0 {expected} {expected}',f'{rel}: viewBox')
        check(not any(e.tag.endswith(('text','image','script','foreignObject')) for e in root.iter()),f'{rel}: external/raster/text content')
        if rel.startswith(('Icons/Neon','Icons/Western','Maneuvers/Neon','Maneuvers/Western')):
            group=list(root)[0]
            check(group.get('stroke')=='currentColor' and group.get('fill')=='none',f'{rel}: template styling')
        if rel.startswith('CarPlay/'):
            check(root.get('width')==('44' if p.stem.endswith(('-list','-map')) else '30'),f'{rel}: point size')
            check(list(root)[0].get('stroke')=='#000000',f'{rel}: monochrome')
    except ET.ParseError as e:errors.append(f'{p}: {e}')

for p in ROOT.rglob('*.png'):
    rel=p.relative_to(ROOT).as_posix()
    with Image.open(p) as im:
        if rel.startswith(('AppIcon/','Store/')):
            expected=(1024,1024) if rel.startswith('AppIcon/') else (1290,2796)
            check(im.size==expected,f'{rel}: dimensions {im.size}')
            check(im.mode=='RGB',f'{rel}: opaque RGB required')
            if 'tinted' in p.name:
                r,g,b=im.split()
                check(ImageChops.difference(r,g).getbbox() is None and ImageChops.difference(r,b).getbbox() is None,f'{rel}: must be grayscale')
            continue
        check(im.mode=='RGBA',f'{rel}: RGBA required')
        alpha=set(im.getchannel('A').getdata())
        check(alpha=={0,255},f'{rel}: transparency/antialiasing {alpha}')
        if '@4x' in p.stem:
            original=p.with_name(p.name.replace('@4x',''))
            check(original.exists(),f'{rel}: missing original')
            if original.exists():
                with Image.open(original) as base:
                    expected=base.resize((base.width*4,base.height*4),Image.Resampling.NEAREST)
                    check(im.size==expected.size and im.tobytes()==expected.tobytes(),f'{rel}: not exact nearest neighbor')
            continue
        if rel.startswith('Icons/Pixel/'):
            check(im.size==(16,16),f'{rel}: expected 16×16')
            allowed={(0,0,0,255),(255,255,255,255),(255,204,51,255),(0,0,0,0)}
            check(set(im.getdata())<=allowed,f'{rel}: unexpected palette')
        elif rel.startswith('Maneuvers/Pixel/'):
            check(im.size==(24,24),f'{rel}: expected 24×24')
        elif rel.startswith('Blips/Pixel/'):
            check(im.size in ((8,8),(10,10)),f'{rel}: native blip size')
        elif p.stem.startswith('player-pixel-'):
            direction=p.stem.removeprefix('player-pixel-')
            expected=(7,10) if direction in ('n','s') else (10,7) if direction in ('e','w') else (13,14)
            check(im.size==expected,f'{rel}: marker dimensions {im.size}, expected {expected}')
            allowed={(0,0,0,0),(0,0,0,255),(255,255,255,255),(220,220,220,255),(164,164,164,255)}
            check(set(im.getdata())<=allowed,f'{rel}: marker palette')
            if direction=='n':
                check(sum(im.getpixel((x,0))[3]>0 for x in range(7))==1,f'{rel}: single-pixel tip')
                check(all(im.getpixel((x,9))==(0,0,0,255) for x in range(7)),f'{rel}: flat black back edge')
        if not rel.startswith('Maneuvers/'):
            check(p.with_name(p.stem+'@4x.png').exists(),f'{rel}: missing 4× export')

for folder in [ROOT]+[p for p in ROOT.rglob('*') if p.is_dir()]:
    check((folder/'index.html').exists(),f'{folder}: no preview')
for p in ROOT.rglob('index.html'):
    text=p.read_text(encoding='utf-8')
    parser=Links()
    parser.feed(text)
    for link in parser.links:
        check((p.parent/link).exists(),f'{p}: broken link {link}')
    for asset in p.parent.iterdir():
        if asset.suffix in ('.png','.svg'):
            check(asset.name in text,f'{p}: missing preview for {asset.name}')

manifest=json.loads((ROOT/'manifest.json').read_text(encoding='utf-8'))
actual={p.relative_to(ROOT).as_posix() for p in ROOT.rglob('*') if p.suffix in ('.svg','.png')}
check({item['path'] for item in manifest['files']}==actual,'Manifest is stale')
if errors:
    print('\n'.join(errors))
    raise SystemExit(f'FAILED: {len(errors)} errors')
print(f'PASS: {len(actual)} assets; filenames, SVGs, dimensions, alpha, palette, 4x exports and preview links')
