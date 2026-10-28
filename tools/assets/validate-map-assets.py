"""Read-only checks for delivered PNG dimensions, alpha, repetition and inventory."""
import json
from pathlib import Path
from PIL import Image, ImageChops

root = Path(__file__).resolve().parents[2] / 'Assets' / 'Generated'
specs = json.loads((root / 'map-asset-prompts.json').read_text())
errors = []
count = 0
for a in specs:
    folder = root / a['style'] / a['group']
    for suffix, size in [('', (a['w'], a['h'])), ('@2x', (a['w']*2, a['h']*2)), ('@3x', (a['w']*3, a['h']*3)), ('-master', (1024,1024))]:
        file = folder / (a['name'] + suffix + '.png')
        if not file.exists():
            errors.append(f'Missing {file.relative_to(root)}')
            continue
        with Image.open(file) as im:
            count += 1
            if im.size != size:
                errors.append(f'{file.name}: size {im.size}, expected {size}')
            if im.mode != 'RGBA':
                errors.append(f'{file.name}: {im.mode}, expected RGBA')
                continue
            alpha = im.getchannel('A')
            lo, hi = alpha.getextrema()
            if lo == 255:
                errors.append(f'{file.name}: no transparency')
            if hi == 0:
                errors.append(f'{file.name}: empty image')
            if a['tile']:
                w,h=im.size
                lr=ImageChops.difference(im.crop((0,0,1,h)), im.crop((w-1,0,w,h)))
                tb=ImageChops.difference(im.crop((0,0,w,1)), im.crop((0,h-1,w,h)))
                maximum=max(v[1] for v in lr.getextrema()+tb.getextrema())
                if maximum > 2:
                    errors.append(f'{file.name}: opposite edge delta {maximum}')
for style in ('WildWest','ToyTown'):
    for name in ('index.html','manifest.json','README.md'):
        if not (root/style/name).exists():
            errors.append(f'Missing {style}/{name}')
print(f'Checked {count}/{len(specs)*4} PNGs across {len(specs)} asset families.')
for e in errors:
    print(e)
raise SystemExit(bool(errors))
