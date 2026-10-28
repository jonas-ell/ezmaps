# Wild West map artwork

Generated with the built-in image_gen tool. Exact prompts are in manifest.json and ../map-asset-prompts.json. Every asset has a transparent RGBA PNG at its base size, @2x, @3x and a square 1024 px master. Rectangular sprites are normalized to the declared final aspect ratio during export.

Open index.html locally. It shows all exports at 1x, 2x and 4x, tiled texture previews, and a sample map assembled from the actual PNGs. The requested reference images were not present. The gallery uses the existing docs/store/tests app screenshot as a labeled fallback, and accepts app-jetzt-1.png through its local file picker. No comparison with the missing target style references has been claimed.

Textures are transparent overlays. Put #E4C9A8 beneath the map background texture. Use muted blue-grey below water-edge. Tile exports use mirrored averaging of generated texture samples to match opposite edges and reduce contrast; paper opacity is reduced to preserve road readability.

MapLibre integration: load each PNG as a non-SDF image. Set pixelRatio to 2 for @2x or 3 for @3x; icon-size 1 yields the logical base size. Use pattern images at pixelRatio 1. Place terrain patterns below roads, decoration below road labels, and navigation markers above both. Allow normal symbol collision for badges and avoid placing decoration over streets. The finish flag anchor is [0.5, 0.94] within its canvas; offset accordingly if using icon-anchor bottom.

The preview includes synthetic road labels only; sprite artwork has no words apart from explicitly requested parking P symbols. Native iPhone/CarPlay rendering has not been tested.
