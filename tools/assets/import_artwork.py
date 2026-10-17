"""Export generated artwork at the exact delivery dimensions, without cropping.

Usage: python tools/assets/import_artwork.py NAME SOURCE.png
Only technical size/mode normalization; the artwork comes from imagegen.
"""
import argparse
import json
from pathlib import Path
from PIL import Image
from generate import ROOT, previews

SIZES = {
    'appicon-1024': ('AppIcon', (1024, 1024)),
    'appicon-1024-dark': ('AppIcon', (1024, 1024)),
    'appicon-1024-tinted': ('AppIcon', (1024, 1024)),
    'store-neon': ('Store', (1290, 2796)),
    'store-western': ('Store', (1290, 2796)),
    'store-pixel': ('Store', (1290, 2796)),
}


def export(name, source):
    folder, size = SIZES[name]
    destination = ROOT / folder / (name + '.png')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as im:
        original_size = im.size
        im = im.convert('RGB')
        if name.endswith('-tinted'):
            im = im.convert('L').convert('RGB')
        im = im.resize(size, Image.Resampling.NEAREST if name == 'store-pixel' else Image.Resampling.LANCZOS)
        im.save(destination)
    record_path = ROOT / 'artwork-provenance.json'
    record = json.loads(record_path.read_text(encoding='utf-8')) if record_path.exists() else {}
    record[name] = {'tool': 'built-in image_gen', 'source_file': Path(source).name,
                    'source_size': original_size, 'export_size': size,
                    'resampling': 'nearest' if name == 'store-pixel' else 'lanczos',
                    'mode': 'RGB', 'grayscale': name.endswith('-tinted')}
    record_path.write_text(json.dumps(record, indent=2)+'\n', encoding='utf-8')
    print(destination)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name', choices=SIZES)
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    export(args.name, args.source)
    previews()
