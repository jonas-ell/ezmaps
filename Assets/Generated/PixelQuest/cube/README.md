# Pixel Quest cube

Three opaque RGB 1024 x 1024 PNGs. Top: exact 128 x 128 pixel blocks (8 px each),
eight flat biome colors including exactly two blues. Side and bottom: exact
64 x 64 pixel blocks (16 px each). Use nearest min/mag sampling in the app.
`vorschau.png` is a Blender render of these actual textures on a cube.

The world map is an original AI illustration requested with a Europe-centered
Web-Mercator view, 70 N to 60 S. It is not derived from georeferenced data;
the exact projection and latitude boundary positions are NOT verified.
Do not use its coastlines to align live geographic overlays.

Generated with the built-in image tool. Prompts and selected source paths are
in `tools/ezmaps_asset_prompts.json`. Export: `tools/export_ezmaps_graphics.ps1`.
Render: Blender with `tools/render_pixel_cube.py`.
