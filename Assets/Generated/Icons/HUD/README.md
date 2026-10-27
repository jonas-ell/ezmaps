# Original HUD & Style Tiles

## Folder layout
- Assets/Generated/Icons/HUD/: 14 standalone SVG glyphs, 14 matching Xcode .imageset folders, hud-button-bg.svg and index.html.
- Assets/Generated/StyleTiles/: five map styles, each with 1024px master (.png), 256px (@1x.png), 512px (@2x.png), 768px (@3x.png), plus index.html.

## Xcode
Drag the .imageset directories into your Assets.xcassets. Each Contents.json declares universal SVG, preserves-vector-representation=true and template-rendering-intent=original. Use renderingMode(.original) if your SwiftUI view overrides rendering mode. Xcode compilation was not available in this environment; JSON, SVG structure, referenced files and dimensions were checked.

## HUD
32x32 viewBox. White filled original glyphs, black 1.5px outline with round joins, hard shadow offset 1.5/1.5 at 60%. Geometry plus shadow fits 3px inset. Button background has a 56x56 canvas with inset circle to accommodate its soft shadow, #0B0B0C at 85%, and a 2px inner white border at 18%.

## Tiles
Original AI-generated raster illustrations using the built-in image generation tool. Export normalization only: edge-fringe crop, resize and 22% radius alpha mask. Revision 2 follows the four user reference screenshots: flat dark urban cartography, sparse parchment outlines, pixel grass and village roofs, and a flat printed children's road carpet. Classic and HUD glyphs are unchanged. Theme colors guided generation; subtle raster variation may remain. No labels, logos or copied map layouts. Source prompts are in GENERATION-PROMPTS.md.

## Preview
Open each folder's index.html locally. HUD: every icon at 24/32/48px on #3B3C3E, #F2EFE9 and a black 80% circular button. Tiles: all styles at 64/128/256px on #1C1C1E.
