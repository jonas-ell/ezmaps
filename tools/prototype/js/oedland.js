// GM-091: Demo „Ödland-Terminal“ – grüner Röhrenbildschirm, Fahrt durch Wallrabenstein. Nur Prototyp.
'use strict';
(async () => {
  const BASE = location.href.replace(/tools\/prototype\/.*$/, '');
  const q = new URLSearchParams(location.search);
  const G = '#49ff7a', G2 = '#2bd65a', G3 = '#138a36', G4 = '#0a4a1e', BG = '#031007';
  const rad = Math.PI / 180;
  const dist = (a, b) => { const dl = (b[0] - a[0]) * rad, dn = (b[1] - a[1]) * rad, x = Math.sin(dl / 2) ** 2 + Math.cos(a[0] * rad) * Math.cos(b[0] * rad) * Math.sin(dn / 2) ** 2; return 12742000 * Math.asin(Math.sqrt(x)); };
  const bearing = (a, b) => { const y = Math.sin((b[1] - a[1]) * rad) * Math.cos(b[0] * rad); const x = Math.cos(a[0] * rad) * Math.sin(b[0] * rad) - Math.sin(a[0] * rad) * Math.cos(b[0] * rad) * Math.cos((b[1] - a[1]) * rad); return (Math.atan2(y, x) / rad + 360) % 360; };
  const turnOf = (a, b) => ((b - a + 540) % 360) - 180;

  // Startbildschirm: Zeilen tippen
  const boot = document.getElementById('boot');
  const lines = ['ÖDLAND-TERMINAL  v1.0', '(C) EZMAPS FELDGERÄTE', '', '> SPEICHER ........ OK', '> FUNKSIGNAL ...... OK', '> KARTE LADEN ..... OK',
    '> ROUTE BERECHNEN . OK', '', 'GUTE FAHRT, WANDERER.'];
  if (q.get('boot') === '0') boot.remove();
  else {
    (async () => {
      for (const l of lines) { for (let k = 0; k < l.length; k += 4) { boot.textContent += l.slice(k, k + 4); await new Promise(r => setTimeout(r, 16)); } boot.textContent += '\n'; await new Promise(r => setTimeout(r, 70)); }
      await new Promise(r => setTimeout(r, 500)); boot.style.opacity = 0; setTimeout(() => boot.remove(), 600);
    })();
  }

  // Kompass-Band: 4 px pro Grad, zweimal herum (läuft weich über Norden)
  const ticks = document.getElementById('ticks'), PX = 4, NAMES = ['N', 'NO', 'O', 'SO', 'S', 'SW', 'W', 'NW'];
  for (let d = -360; d <= 720; d += 15) {
    const x = (d + 360) * PX;
    if (d % 45 === 0) { const s = document.createElement('span'); s.textContent = NAMES[((d % 360) + 360) % 360 / 45]; s.style.left = x + 'px'; ticks.appendChild(s); }
    else { const i = document.createElement('i'); i.style.left = x + 'px'; ticks.appendChild(i); }
  }
  const compassW = document.getElementById('compass').clientWidth;

  // Muster: Schraffur fürs Wasser, Punkte für Wald/Park
  const pattern = (draw) => { const c = document.createElement('canvas'); c.width = c.height = 16; const g = c.getContext('2d'); draw(g); return g.getImageData(0, 0, 16, 16); };
  const hatch = pattern(g => { g.strokeStyle = 'rgba(43,214,90,.55)'; g.lineWidth = 1; for (let k = -16; k < 32; k += 6) { g.beginPath(); g.moveTo(k, 16); g.lineTo(k + 16, 0); g.stroke(); } });
  const dots = pattern(g => { g.fillStyle = 'rgba(43,214,90,.45)'; g.fillRect(3, 3, 2, 2); g.fillRect(11, 11, 2, 2); });

  const font = ['Barlow Condensed SemiBold'];
  const road = (id, classes, color, w0, w1, blur) => ({ id, type: 'line', source: 'omt', 'source-layer': 'transportation',
    filter: ['in', ['get', 'class'], ['literal', classes]], layout: { 'line-cap': 'round', 'line-join': 'round' },
    paint: { 'line-color': color, 'line-width': ['interpolate', ['exponential', 1.6], ['zoom'], 12, w0, 18, w1], ...(blur ? { 'line-blur': blur, 'line-opacity': 0.45 } : {}) } });
  const style = {
    version: 8, glyphs: BASE + 'Resources/Glyphs/{fontstack}/{range}.pbf',
    sources: { omt: { type: 'vector', url: 'https://tiles.openfreemap.org/planet' } },
    layers: [
      { id: 'bg', type: 'background', paint: { 'background-color': BG } },
      { id: 'res', type: 'fill', source: 'omt', 'source-layer': 'landuse', filter: ['in', ['get', 'class'], ['literal', ['residential', 'suburb', 'neighbourhood']]], paint: { 'fill-color': '#05190b' } },
      { id: 'ind', type: 'fill', source: 'omt', 'source-layer': 'landuse', filter: ['in', ['get', 'class'], ['literal', ['industrial', 'commercial', 'retail', 'railway']]], paint: { 'fill-color': '#071f0e' } },
      { id: 'wood', type: 'fill', source: 'omt', 'source-layer': 'landcover', filter: ['in', ['get', 'class'], ['literal', ['wood', 'forest', 'grass', 'farmland']]], paint: { 'fill-pattern': 'oed-dots', 'fill-opacity': 0.8 } },
      { id: 'park', type: 'fill', source: 'omt', 'source-layer': 'park', paint: { 'fill-pattern': 'oed-dots' } },
      { id: 'water', type: 'fill', source: 'omt', 'source-layer': 'water', paint: { 'fill-color': '#052a12' } },
      { id: 'water-hatch', type: 'fill', source: 'omt', 'source-layer': 'water', paint: { 'fill-pattern': 'oed-hatch' } },
      { id: 'water-edge', type: 'line', source: 'omt', 'source-layer': 'water', paint: { 'line-color': G2, 'line-width': 1.2 } },
      { id: 'river', type: 'line', source: 'omt', 'source-layer': 'waterway', paint: { 'line-color': G2, 'line-width': ['interpolate', ['linear'], ['zoom'], 12, 1, 18, 4], 'line-dasharray': [3, 2] } },
      { id: 'bld', type: 'fill', source: 'omt', 'source-layer': 'building', minzoom: 14, paint: { 'fill-color': '#08260f', 'fill-outline-color': G3 } },
      { id: 'bld-edge', type: 'line', source: 'omt', 'source-layer': 'building', minzoom: 15, paint: { 'line-color': G3, 'line-width': 1 } },
      { id: 'rail', type: 'line', source: 'omt', 'source-layer': 'transportation', filter: ['==', ['get', 'class'], 'rail'], paint: { 'line-color': G3, 'line-width': 2, 'line-dasharray': [1, 2] } },
      { id: 'path', type: 'line', source: 'omt', 'source-layer': 'transportation', minzoom: 15, filter: ['in', ['get', 'class'], ['literal', ['path', 'track']]], paint: { 'line-color': G4, 'line-width': 1.2, 'line-dasharray': [2, 2] } },
      road('minor-glow', ['minor', 'service'], G3, 2, 16, 4),
      road('minor', ['minor', 'service'], G3, 0.8, 7),
      road('main-glow', ['primary', 'secondary', 'tertiary', 'trunk'], G2, 4, 22, 6),
      road('main', ['primary', 'secondary', 'tertiary', 'trunk'], G2, 1.4, 10),
      road('mw-glow', ['motorway'], G, 6, 26, 8),
      road('mw', ['motorway'], G, 2, 12),
      { id: 'route-glow', type: 'line', source: 'route', layout: { 'line-cap': 'round', 'line-join': 'round' }, paint: { 'line-color': '#b6ffcb', 'line-width': 20, 'line-blur': 10, 'line-opacity': 0.55 } },
      { id: 'route', type: 'line', source: 'route', layout: { 'line-cap': 'butt', 'line-join': 'round' }, paint: { 'line-color': '#d8ffe2', 'line-width': 6, 'line-dasharray': [2, 1] } },
      { id: 'road-name', type: 'symbol', source: 'omt', 'source-layer': 'transportation_name', minzoom: 15,
        layout: { 'symbol-placement': 'line', 'text-field': ['upcase', ['get', 'name']], 'text-font': font, 'text-size': 13, 'text-letter-spacing': 0.15 },
        paint: { 'text-color': G, 'text-halo-color': BG, 'text-halo-width': 2.5 } },
      { id: 'poi-dot', type: 'circle', source: 'omt', 'source-layer': 'poi', minzoom: 15, filter: ['<=', ['get', 'rank'], 20],
        paint: { 'circle-radius': 4, 'circle-color': BG, 'circle-stroke-color': G, 'circle-stroke-width': 1.5 } },
      { id: 'poi-name', type: 'symbol', source: 'omt', 'source-layer': 'poi', minzoom: 16, filter: ['<=', ['get', 'rank'], 20],
        layout: { 'text-field': ['concat', '[', ['upcase', ['get', 'name']], ']'], 'text-font': font, 'text-size': 12, 'text-offset': [0, 1.1], 'text-anchor': 'top', 'text-optional': true },
        paint: { 'text-color': G2, 'text-halo-color': BG, 'text-halo-width': 2 } },
      { id: 'place', type: 'symbol', source: 'omt', 'source-layer': 'place', filter: ['in', ['get', 'class'], ['literal', ['city', 'town', 'village', 'suburb', 'hamlet']]],
        layout: { 'text-field': ['upcase', ['get', 'name']], 'text-font': font, 'text-size': ['match', ['get', 'class'], 'city', 22, 'town', 19, 16], 'text-letter-spacing': 0.3 },
        paint: { 'text-color': '#b6ffcb', 'text-halo-color': BG, 'text-halo-width': 3 } },
    ],
  };

  const pts = (await (await fetch(BASE + 'tools/drive_wallrabenstein.txt')).text()).trim().split(/\s+/).map(s => s.split(',').map(Number));
  const cum = [0]; for (let i = 1; i < pts.length; i++) cum.push(cum[i - 1] + dist(pts[i - 1], pts[i]));
  const total = cum[cum.length - 1];
  const at = (s) => { // Punkt und Index bei Strecke s
    let i = 1; while (i < pts.length - 1 && cum[i] < s) i++;
    const f = Math.max(0, Math.min(1, (s - cum[i - 1]) / (cum[i] - cum[i - 1] || 1)));
    return { p: [pts[i - 1][0] + (pts[i][0] - pts[i - 1][0]) * f, pts[i - 1][1] + (pts[i][1] - pts[i - 1][1]) * f], i };
  };
  style.sources.route = { type: 'geojson', data: { type: 'Feature', geometry: { type: 'LineString', coordinates: pts.map(p => [p[1], p[0]]) } } };

  const H = document.getElementById('phone').clientHeight;
  const map = new maplibregl.Map({ container: 'm', style, center: [pts[0][1], pts[0][0]], zoom: 16.4, pitch: 42, bearing: bearing(pts[0], pts[2]),
    interactive: false, attributionControl: false, preserveDrawingBuffer: true, padding: { top: Math.max(0, 2 * H * 0.64 - H), bottom: 0, left: 0, right: 0 } });
  window.oedMap = map;
  map.on('styleimagemissing', e => {
    if (e.id === 'oed-hatch') map.addImage(e.id, hatch); else if (e.id === 'oed-dots') map.addImage(e.id, dots);
  });

  // nächstes Abbiegen: Richtungswechsel > 35° innerhalb von ~40 m
  function nextTurn(s) {
    for (let i = at(s).i; i < pts.length - 2; i++) {
      if (cum[i] - s < 15) continue;
      const t = turnOf(bearing(pts[i - 1], pts[i]), bearing(pts[i], pts[Math.min(pts.length - 1, i + 2)]));
      if (Math.abs(t) > 35) return { d: cum[i] - s, right: t > 0, i };
    }
    return null;
  }
  function streetNear(p) {
    let best = null, bd = 60;
    for (const f of map.querySourceFeatures('omt', { sourceLayer: 'transportation_name' })) {
      const g = f.geometry, lines = g.type === 'LineString' ? [g.coordinates] : g.type === 'MultiLineString' ? g.coordinates : [];
      for (const l of lines) for (const c of l) { const d = dist(p, [c[1], c[0]]); if (d < bd && f.properties.name) { bd = d; best = f.properties.name; } }
    }
    return best;
  }

  const KMH = 48, SPEEDUP = 2; // Demo schneller als echt
  let s = 0, last = performance.now(), heading = bearing(pts[0], pts[2]), tick = 0;
  const still = q.get('static') === '1';
  const el = id => document.getElementById(id);
  const fmtD = d => d >= 1000 ? (d / 1000).toFixed(1).replace('.', ',') + ' KM' : Math.round(d / 10) * 10 + ' M';
  map.on('load', () => {
    (function frame(now) {
      const dt = Math.min(0.1, (now - last) / 1000); last = now;
      if (!still) s = (s + KMH / 3.6 * SPEEDUP * dt) % total;
      const a = at(s), ahead = at(Math.min(total, s + 25)).p;
      const target = bearing(a.p, ahead);
      heading = (heading + turnOf(heading, target) * Math.min(1, dt * 3) + 360) % 360;
      map.jumpTo({ center: [a.p[1], a.p[0]], bearing: heading });
      el('ticks').style.left = (compassW / 2 - (heading + 360) * PX) + 'px';
      if (++tick % 12 === 0) { // Anzeigen ~5× pro Sekunde
        map.getSource('route').setData({ type: 'Feature', geometry: { type: 'LineString', coordinates: [[a.p[1], a.p[0]], ...pts.slice(a.i).map(p => [p[1], p[0]])] } });
        const left = total - s, t = nextTurn(s);
        if (t) {
          el('dist').textContent = fmtD(t.d);
          const name = streetNear(pts[Math.min(pts.length - 1, t.i + 2)]);
          el('street').textContent = (t.right ? 'RECHTS' : 'LINKS') + (name ? ' · ' + name.toUpperCase() : '');
          el('turn').querySelector('.arrow').style.transform = t.right ? '' : 'scaleX(-1)';
          const t2 = nextTurn(s + t.d + 20);
          el('next').textContent = t2 ? `DANACH ${t2.right ? '▶ RECHTS' : '◀ LINKS'} IN ${fmtD(t2.d + 20)}` : 'DANACH: ZIEL';
        } else { el('dist').textContent = fmtD(left); el('street').textContent = 'ZIEL VORAUS'; el('next').textContent = 'DANACH: ZIEL'; }
        const min = Math.max(1, Math.round(left / (KMH / 3.6) / 60)), arr = new Date(Date.now() + min * 60000);
        el('etaBig').textContent = 'ANK ' + arr.toTimeString().slice(0, 5);
        el('etaSmall').textContent = `${fmtD(left)} · ${min} MIN`;
        el('prog').style.width = (s / total * 100).toFixed(1) + '%';
        el('kmh').textContent = still ? KMH : KMH + Math.round(Math.sin(now / 900) * 2);
        el('clock').textContent = new Date().toTimeString().slice(0, 5);
      }
      requestAnimationFrame(frame);
    })(last);
    const wait = () => (map.loaded() && map.areTilesLoaded()) ? setTimeout(() => { document.title = 'ready'; }, 800) : setTimeout(wait, 300);
    setTimeout(wait, 1000);
  });
})();
