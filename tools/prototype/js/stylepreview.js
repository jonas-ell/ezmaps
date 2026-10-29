// GM-049: Stil-Vorschau „im Einsatz“ – echte App-Stile, Pfeil auf der Straße, Route voraus (Farben wie App/StyleTheme.swift)
'use strict';
(async () => {
  const BASE = location.href.replace(/tools\/prototype\/.*$/, '');
  const q = new URLSearchParams(location.search);
  const style = q.get('style') || 'neon-city', zoom = +(q.get('z') || 16.2), i0 = +(q.get('i') || 16); // Zoom: CarPlay-Kamera bei 50 km/h (440 m Höhe, 480 px)
  const THEME = { 'classic': ['#1a73e8', '#0b3d91'], 'neon-city': ['#a13df0', '#4b1a73'], 'wild-west': ['#c0261f', '#4a0d0a'],
    'pixel-quest': ['#e0362b', '#4a0d08'], 'toy-town': ['#ff7a00', '#ffffff'] }[style];
  const rad = Math.PI / 180;
  const bearing = (a, b) => { const y = Math.sin((b[1] - a[1]) * rad) * Math.cos(b[0] * rad); const x = Math.cos(a[0] * rad) * Math.sin(b[0] * rad) - Math.sin(a[0] * rad) * Math.cos(b[0] * rad) * Math.cos((b[1] - a[1]) * rad); return (Math.atan2(y, x) / rad + 360) % 360; };
  const pts = (await (await fetch(BASE + 'tools/drive_wallrabenstein.txt')).text()).trim().split(/\s+/).map(s => s.split(',').map(Number));
  const st = await (await fetch(`${BASE}App/MapStyles/style-${style}.json`)).json();
  st.glyphs = BASE + 'Resources/Glyphs/{fontstack}/{range}.pbf';
  await preloadAssetImages(BASE);
  const here = pts[i0], h = bearing(here, pts[i0 + 2]);
  document.getElementById('a').src = `${BASE}App/Assets.xcassets/PlayerNeon${style === 'neon-city' ? 'Glow' : ''}.imageset/player-neon-v2${style === 'neon-city' ? '-glow' : ''}@3x.png`;
  const H = innerHeight;
  const map = new maplibregl.Map({ container: 'm', style: st, center: [here[1], here[0]], zoom, bearing: h, attributionControl: false, interactive: false,
    preserveDrawingBuffer: true, padding: { top: Math.max(0, 2 * H * 0.58 - H), bottom: 0, left: 0, right: 0 } });
  window.previewMap = map; // zum Prüfen im Browser
  map.on('styleimagemissing', e => {
    const img = styleImage(e.id); if (img && !map.hasImage(e.id)) map.addImage(e.id, img.data, { pixelRatio: img.pixelRatio });
  });
  map.on('load', () => {
    const route = pts.slice(i0, i0 + 14).map(p => [p[1], p[0]]);
    map.addSource('r', { type: 'geojson', data: { type: 'Feature', geometry: { type: 'LineString', coordinates: route } } });
    map.addLayer({ id: 'e', type: 'line', source: 'r', paint: { 'line-color': THEME[1], 'line-width': 9 }, layout: { 'line-cap': 'round', 'line-join': 'round' } });
    map.addLayer({ id: 'l', type: 'line', source: 'r', paint: { 'line-color': THEME[0], 'line-width': 6 }, layout: { 'line-cap': 'round', 'line-join': 'round' } });
    // erst fertig, wenn alle Kacheln und Symbole da sind (idle kam sonst zu früh)
    const wait = () => (map.loaded() && map.areTilesLoaded() && map.queryRenderedFeatures().length > 10)
      ? setTimeout(() => { document.title = 'ready'; }, 1200) : setTimeout(wait, 300);
    setTimeout(wait, 1500);
  });
})();
