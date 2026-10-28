# Wild West map artwork

Generated with the built-in image_gen tool. Exact prompts are in manifest.json and ../map-asset-prompts.json. Every asset has a transparent RGBA PNG at its base size, @2x, @3x and a square 1024 px master. Rectangular sprites are normalized to the declared final aspect ratio during export.

Open index.html locally. It shows all exports at 1x, 2x and 4x, tiled texture previews, and a sample map assembled from the actual PNGs. The requested reference images were not present. The gallery uses the existing docs/store/tests app screenshot as a labeled fallback, and accepts app-jetzt-1.png through its local file picker. No comparison with the missing target style references has been claimed.

Textures are transparent overlays. Put #E4C9A8 beneath the map background texture. Use muted blue-grey below water-edge. The refreshed tiles use reflected generated ink samples without stroke averaging. Export opacity is 0.48 for paper, 0.52 for hill hatching and 0.41 for water; the previous settings were 0.16, 0.45 and 0.32.

MapLibre integration: load each PNG as a non-SDF image. Set pixelRatio to 2 for @2x or 3 for @3x; icon-size 1 yields the logical base size. Use pattern images at pixelRatio 1. Place terrain patterns below roads, decoration below road labels, and navigation markers above both. Allow normal symbol collision for badges and avoid placing decoration over streets. The finish flag anchor is [0.5, 0.94] within its canvas; offset accordingly if using icon-anchor bottom.

Sprite artwork contains no text; parking uses a car pictogram. Sample road labels are optional and off by default. Native iPhone/CarPlay rendering has not been tested.

Refresh delivery: 21 regenerated or added asset families (84 PNGs), plus six unchanged badge families (24 PNGs). Exact built-in imagegen prompts and source paths are recorded in refresh-sources.json. Use tools/assets/export-wild-west-refresh.ps1 to reproduce these exports from the recorded source images; it preserves alpha, normalizes forest ink to #3A2D20 and waypoint ink to #A8261F, and strengthens forest alpha for small-size readability. The older generic export script uses the previous texture treatment.

Validation: python tools/assets/validate-map-assets.py --style WildWest checks all 108 PNGs. The 2026-10-28 refresh measured texture luminance variation on #E4C9A8 at 3.22x (paper), 2.98x (hill) and 2.99x (water) versus the previous exports. All 24 protected badge files were verified byte-identical. refresh-check.png shows native-size and 2x sprites with repeated textures.
