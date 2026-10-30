// GM-047: 1:1-Abbild der App im Browser. Jede Zahl hier stammt aus dem Swift-Code (Quelle steht dabei) – change both.
'use strict';
const BASE = location.href.replace(/tools\/prototype\/.*$/, '');      // Server läuft im Repo-Hauptordner
const VALHALLA = 'https://valhalla1.openstreetmap.de';                 // App/AppConfig.swift
const PHOTON = 'https://photon.komoot.io';
const IDSTEIN = [50.21712, 8.25734];
const HUD = n => `${BASE}App/Assets.xcassets/HUD/${n}.imageset/${n}@3x.png`;
const ARROW = `${BASE}App/Assets.xcassets/PlayerNeon.imageset/player-neon-v2@3x.png`;
const ARROW_GLOW = `${BASE}App/Assets.xcassets/PlayerNeonGlow.imageset/player-neon-v2-glow@3x.png`;

// App/StyleTheme.swift
const THEME = {
  'classic': { route: '#1a73e8', edge: '#0b3d91', alt: 'rgba(90,110,140,.5)', bg: '#f2efe9' },
  'neon-city': { route: '#a13df0', edge: '#4b1a73', alt: 'rgba(200,200,205,.55)', bg: '#181818' },
  'wild-west': { route: '#c0261f', edge: '#4a0d0a', alt: 'rgba(90,60,30,.45)', bg: '#c4ac80' },
  'pixel-quest': { route: '#e0362b', edge: '#4a0d08', alt: 'rgba(255,255,255,.6)', bg: '#60a83a' },
  'toy-town': { route: '#ff7a00', edge: '#ffffff', alt: 'rgba(255,255,255,.75)', bg: '#8dc63f' },
};
const DEST = '#f5d742';

// Core/Formatting.swift
function fmtDist(m) {
  const m50 = Math.round(m / 50) * 50;
  if (m >= 100 && m50 < 1000) return m50 + ' m';
  if (m < 100) return Math.max(0, Math.round(m / 10) * 10) + ' m';
  const t = Math.round(m / 100) / 10;
  return t >= 10 ? Math.round(m / 1000) + ' km' : t.toFixed(1).replace('.', ',') + ' km';
}
function carDist(m) { // Formatting.carPlayDistance
  if (fmtDist(m).endsWith('km')) return (Math.round(m / 100) / 10).toFixed(1).replace('.', ',') + ' km';
  const step = m >= 100 ? 50 : 10; return Math.max(0, Math.round(m / step) * step) + ' m';
}
function fmtMin(s) { const t = Math.max(1, Math.round(s / 60)); if (t < 60) return t + ' Min'; const h = Math.floor(t / 60), mm = t % 60; return mm ? `${h} Std ${mm} Min` : `${h} Std`; }
const clock = d => `${d.getHours()}:${String(d.getMinutes()).padStart(2, '0')}`;

// Geo
const R = 6371008.8, rad = Math.PI / 180;
function dist(a, b) { const dl = (b[0] - a[0]) * rad, dn = (b[1] - a[1]) * rad; const x = Math.sin(dl / 2) ** 2 + Math.cos(a[0] * rad) * Math.cos(b[0] * rad) * Math.sin(dn / 2) ** 2; return 2 * R * Math.asin(Math.sqrt(x)); }
function bearing(a, b) { const y = Math.sin((b[1] - a[1]) * rad) * Math.cos(b[0] * rad); const x = Math.cos(a[0] * rad) * Math.sin(b[0] * rad) - Math.sin(a[0] * rad) * Math.cos(b[0] * rad) * Math.cos((b[1] - a[1]) * rad); return (Math.atan2(y, x) / rad + 360) % 360; }
function cumul(pts) { const c = [0]; for (let i = 1; i < pts.length; i++) c.push(c[i - 1] + dist(pts[i - 1], pts[i])); return c; }
function at(pts, cum, d) {
  d = Math.max(0, Math.min(cum[cum.length - 1], d));
  let i = 1; while (i < cum.length - 1 && cum[i] < d) i++;
  const f = cum[i] === cum[i - 1] ? 0 : (d - cum[i - 1]) / (cum[i] - cum[i - 1]);
  return { p: [pts[i - 1][0] + (pts[i][0] - pts[i - 1][0]) * f, pts[i - 1][1] + (pts[i][1] - pts[i - 1][1]) * f], h: bearing(pts[i - 1], pts[i]), i };
}
function decode6(str) {
  const out = []; let i = 0, lat = 0, lon = 0;
  while (i < str.length) for (const k of [0, 1]) {
    let s = 0, v = 0, b; do { b = str.charCodeAt(i++) - 63; v |= (b & 0x1f) << s; s += 5; } while (b >= 0x20);
    const d = v & 1 ? ~(v >> 1) : v >> 1; if (k === 0) lat += d; else { lon += d; out.push([lat / 1e6, lon / 1e6]); }
  }
  return out;
}

// Core/ValhallaClient.swift – kind(for:) und makeRoute
const KIND = t => [9, 18, 20, 23].includes(t) ? 'slight-right' : [10, 26, 27].includes(t) ? 'right' : t === 11 ? 'sharp-right' : t === 12 ? 'uturn-right'
  : t === 13 ? 'uturn-left' : t === 14 ? 'sharp-left' : t === 15 ? 'left' : [16, 19, 21, 24].includes(t) ? 'slight-left' : [4, 5, 6].includes(t) ? 'destination' : null;
const KTEXT = { 'slight-right': 'Leicht rechts halten', right: 'Rechts abbiegen', 'sharp-right': 'Scharf rechts abbiegen', 'uturn-right': 'Wenden', 'uturn-left': 'Wenden',
  'sharp-left': 'Scharf links abbiegen', left: 'Links abbiegen', 'slight-left': 'Leicht links halten', destination: 'Ziel erreicht' };
function makeRoute(trip) {
  const leg = trip.legs[0]; const shape = decode6(leg.shape); const cum = cumul(shape); const n = shape.length - 1;
  const speeds = new Array(n).fill(50), names = new Array(n).fill(''); const man = [];
  leg.maneuvers.forEach((m, mi) => {
    const next = leg.maneuvers[mi + 1]; let street = (m.street_names || [])[0] || '';
    if (!street && m.type === 26) street = ((next && next.street_names) || [])[0] || '';
    const kmh = m.time > 0 ? Math.min(130, Math.max(8, m.length * 3600 / m.time)) : 30;
    for (let i = m.begin_shape_index; i < Math.min(n, m.end_shape_index); i++) { speeds[i] = kmh; names[i] = street; }
    const k = KIND(m.type); if (!k || m.type === 27) return;
    let text = KTEXT[k];
    if (m.type === 26) text = `Im Kreisverkehr ${m.roundabout_exit_count || 1}. Ausfahrt`;
    if (m.type === 20 || m.type === 21) text = ('Ausfahrt ' + (((m.sign || {}).exit_number_elements || [])[0] || {}).text || '').trim() + ' nehmen';
    if (m.type === 18 || m.type === 19) text = 'Auffahrt nehmen';
    man.push({ distance: k === 'destination' ? cum[n] : cum[Math.min(m.begin_shape_index, n)], kind: k, text, street: k === 'destination' ? '' : street });
  });
  if (!man.length || man[man.length - 1].kind !== 'destination') man.push({ distance: cum[n], kind: 'destination', text: KTEXT.destination, street: '' });
  return { shape, cum, length: cum[n], duration: trip.summary.time, maneuvers: man, speeds, names, limits: null };
}
async function valhallaRoutes(from, to, o = {}) {
  const start = { lat: from[0], lon: from[1] };
  if (o.heading != null) { start.heading = Math.round(((o.heading % 360) + 360) % 360); start.heading_tolerance = 45; }
  const body = { locations: [start, { lat: to[0], lon: to[1] }], costing: 'auto',
    costing_options: { auto: { use_highways: S.avoidHighway ? 0 : 1, use_tolls: S.avoidToll ? 0 : 1 } }, directions_options: { language: 'de-DE', units: 'kilometers' },
    alternates: o.alternates == null ? 2 : o.alternates };
  if (o.exclude && o.exclude.length) body.exclude_locations = o.exclude.map(c => ({ lat: c[0], lon: c[1] }));
  const r = await fetch(VALHALLA + '/route', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
  const j = await r.json(); if (!r.ok) throw new Error(j.error || r.status);
  return [j.trip, ...(j.alternates || []).map(a => a.trip)].map(makeRoute);
}
async function photon(q, near) { // Core/PhotonClient.swift (vereinfacht: Untertitel Art · Adresse · Ort)
  const u = `${PHOTON}/api/?q=${encodeURIComponent(q)}&lat=${near[0]}&lon=${near[1]}&limit=8&lang=de`;
  const j = await (await fetch(u)).json(); const out = [];
  for (const f of j.features) {
    const p = f.properties; const name = p.name || [p.street, p.housenumber].filter(Boolean).join(' ') || p.city; if (!name) continue;
    const addr = [p.street, p.housenumber].filter(Boolean).join(' ');
    const sub = [p.osm_value && p.name ? p.osm_value[0].toUpperCase() + p.osm_value.slice(1) : '', p.name ? addr : '', p.city || p.county || ''].filter(Boolean).join(' · ');
    const c = [f.geometry.coordinates[1], f.geometry.coordinates[0]];
    if (out.some(o => o.name === name && dist(o.c, c) < 400)) continue;
    out.push({ name, sub, c });
  }
  return out;
}

// ---------- Zustand (Mirror AppModel) ----------
const S = { voice: true, avoidHighway: false, avoidToll: false, message: null, nav: null, navCoord: null, navHeading: 0, navKmh: 50, screen: 'map', style: 'neon-city', pos: null, routes: [], sel: 0, dest: null, prog: 0, trail: [], speed: 2, recents: [], query: '', results: [],
  carList: null, carQuery: '', carResults: [] };

// ---------- Karten ----------
function styleURL(name) { return `${BASE}App/MapStyles/style-${name}.json`; }
async function loadStyle(name) {
  const st = await (await fetch(styleURL(name))).json();
  st.glyphs = BASE + 'Resources/Glyphs/{fontstack}/{range}.pbf';   // App: asset://Glyphs/… (Resources/Glyphs im Bundle)
  return st;
}
function addOverlay(map) { // RouteOverlay.styleLoaded
  const t = THEME[S.style]; const empty = { type: 'FeatureCollection', features: [] };
  for (const id of ['ez-trail', 'ez-alt', 'ez-route', 'ez-dest']) if (!map.getSource(id)) map.addSource(id, { type: 'geojson', data: empty });
  const L = (id, src, paint, layout = { 'line-cap': 'round', 'line-join': 'round' }) => { if (!map.getLayer(id)) map.addLayer({ id, type: 'line', source: src, paint, layout }); };
  L('ez-trail-glow', 'ez-trail', { 'line-color': 'rgba(196,120,255,.35)', 'line-width': 12, 'line-blur': 6 });
  L('ez-trail-line', 'ez-trail', { 'line-color': 'rgba(217,166,255,.9)', 'line-width': 3 });
  L('ez-alt-line', 'ez-alt', { 'line-color': t.alt, 'line-width': 5 });
  L('ez-route-edge', 'ez-route', { 'line-color': t.edge, 'line-width': 9 });
  L('ez-route-line', 'ez-route', { 'line-color': t.route, 'line-width': 6 });
  // GM-050: Ziel-Symbol je Stil (RouteOverlay.destinationImage)
  if (map.hasImage('ez-dest-icon')) map.removeImage('ez-dest-icon');
  map.addImage('ez-dest-icon', drawDest(S.style), { pixelRatio: 2 });
  if (!map.getLayer('ez-dest-dot')) map.addLayer({ id: 'ez-dest-dot', type: 'symbol', source: 'ez-dest',
    layout: { 'icon-image': 'ez-dest-icon', 'icon-anchor': DEST_STANDS[S.style] ? 'bottom' : 'center', 'icon-allow-overlap': true, 'icon-ignore-placement': true } });
  pushOverlay(map);
}
const line = pts => ({ type: 'Feature', geometry: { type: 'LineString', coordinates: pts.map(p => [p[1], p[0]]) } });
function pushOverlay(map) {
  if (!map.getSource('ez-route')) return;
  const alts = S.routes.filter((_, i) => i !== S.sel).map(r => line(r.shape));
  const main = S.routes[S.sel] ? [line(S.routes[S.sel].shape)] : [];
  map.getSource('ez-alt').setData({ type: 'FeatureCollection', features: S.screen === 'navigating' ? [] : alts });
  map.getSource('ez-route').setData({ type: 'FeatureCollection', features: main });
  map.getSource('ez-dest').setData({ type: 'FeatureCollection', features: S.dest ? [{ type: 'Feature', geometry: { type: 'Point', coordinates: [S.dest.c[1], S.dest.c[0]] } }] : [] });
  map.getSource('ez-trail').setData({ type: 'FeatureCollection', features: S.trail.length > 1 ? [line(S.trail)] : [] });
}
function makeMap(el, pixelRatio = devicePixelRatio) {
  const map = new maplibregl.Map({ container: el, pixelRatio, interactive: true, center: [IDSTEIN[1], IDSTEIN[0]], zoom: 15, attributionControl: false, pitchWithRotate: false, dragRotate: false });
  map.on('styleimagemissing', e => {
    const img = styleImage(e.id); if (img && !map.hasImage(e.id)) map.addImage(e.id, img.data, { pixelRatio: img.pixelRatio }); // App: ~40 pt Bild × icon-size
  });
  map.on('style.load', () => { addAssetImages(map); addOverlay(map); });
  return map;
}

// ---------- FollowCamera (App/FollowCamera.swift) ----------
const altitudeForKmh = k => 400 + (Math.min(130, Math.max(30, k)) - 30) * 6;     // RouteOverlay.altitude(forKmh:)
// GM-049: wie MLNAltitudeForZoomLevel in MapLibre Native – Blickwinkel 30°, Kachel 512 (vorher 36,87° angenommen → zu weit weg)
function altitudeToZoom(alt, h, lat) { const mpp = alt * 2 * Math.tan(15 * rad) / h; return Math.log2(40075016.686 * Math.cos(lat * rad) / (512 * mpp)); }
class FollowCamera {
  constructor(map, arrowEl, { pitch = 0, arrowY = 0.5, insets = () => ({ top: 0, left: 0, bottom: 0, right: 0 }), glow = () => false } = {}) {
    Object.assign(this, { map, arrowEl, pitch, arrowY, insets, glow, factor: 1, running: false, detached: false, has: false });
    arrowEl.src = ARROW;
    map.on('dragstart', e => { if (this.running && e.originalEvent) this.detached = true; });
    map.on('zoomstart', e => { if (this.running && e.originalEvent) this.detached = true; });
  }
  start() { if (!this.running) { this.running = true; this.has = false; this.detached = false; } }
  stop() { this.running = false; this.detached = false; this.arrowEl.style.display = 'none'; }
  attach() { this.detached = false; this.factor = 1; }
  zoom(step) { this.factor = Math.min(4, Math.max(0.35, this.factor * (step > 0 ? 0.7 : 1.4))); }
  tick(dt, t) {
    if (!this.running) return;
    if (!t) { this.arrowEl.style.display = 'none'; return; }
    const goal = altitudeForKmh(t.kmh) * this.factor;
    if (!this.has) { Object.assign(this, { lat: t.p[0], lon: t.p[1], heading: t.h, alt: goal, has: true }); }
    else {
      const kPos = 1 - Math.exp(-dt * 12), kRot = 1 - Math.exp(-dt * 7)  /* GM-050 */, kAlt = 1 - Math.exp(-dt * 1.5);
      this.lat += (t.p[0] - this.lat) * kPos; this.lon += (t.p[1] - this.lon) * kPos;
      let dh = (t.h - this.heading) % 360; if (dh > 180) dh -= 360; else if (dh < -180) dh += 360;
      this.heading = (this.heading + dh * kRot + 360) % 360; this.alt += (goal - this.alt) * kAlt;
    }
    const a = this.arrowEl, img = this.glow() ? ARROW_GLOW : ARROW; if (a.getAttribute('src') !== img) a.src = img;
    if (this.detached) { // Umschauen: Karte bleibt, Pfeil auf der Fahrposition
      const p = this.map.project([this.lon, this.lat]);
      a.style.left = p.x + 'px'; a.style.top = p.y + 'px'; a.style.transform = `rotate(${this.heading - this.map.getBearing()}deg)`; a.style.display = 'block'; return;
    }
    const c = this.map.getContainer(); const W = c.clientWidth, H = c.clientHeight, s = this.insets();
    const ay = s.top + (H - s.top - s.bottom) * this.arrowY, ax = s.left + (W - s.left - s.right) / 2;
    const padding = { top: Math.max(0, 2 * ay - H), left: Math.max(0, 2 * ax - W), bottom: Math.max(0, H - 2 * ay), right: Math.max(0, W - 2 * ax) };
    this.map.jumpTo({ center: [this.lon, this.lat], zoom: altitudeToZoom(this.alt, H, this.lat), bearing: this.heading, pitch: this.pitch, padding });
    a.style.left = ax + 'px'; a.style.top = ay + 'px'; a.style.transform = ''; a.style.display = 'block';
  }
}

// Fahrt-Simulation und Navigation: js/navcore.js (Abbild von Core und AppModel)

// ---------- Bedienung ----------
const $ = id => document.getElementById(id);
preloadAssetImages(BASE); // GM-067: Haus-Bilder aus dem Asset-Katalog (Stile laden ohnehin später)
const pmap = makeMap($('pmap')), cmap = makeMap($('cmap'), 2 * devicePixelRatio); // CarPlay: 2× wie der Simulator
const maps = () => [pmap, cmap];
const pcam = new FollowCamera(pmap, $('parrow'), { pitch: 0, arrowY: 0.62, glow: () => true,     // GM-045: iPhone flach wie CarPlay
  insets: () => ({ top: 59, left: 0, bottom: 34, right: 0 }) });
const ccam = new FollowCamera(cmap, $('carrow'), { pitch: 0, arrowY: 0.64, glow: () => S.screen === 'navigating',
  insets: () => ({ top: 50, left: S.screen === 'navigating' ? 180 : 0, bottom: 0, right: 45 }) }); // Punkte: Leiste oben, Knopfspalte, Abbiegekarte
let tracking = true;                                       // iPhone ohne Navi: MapLibre userTrackingMode .follow
pmap.on('dragstart', e => { if (e.originalEvent && S.screen !== 'navigating') tracking = false; });

async function applyStyle(name) {
  S.style = name; const st = await loadStyle(name);
  for (const m of maps()) { m.setStyle(st); m.getContainer().style.background = THEME[name].bg; }
}
function fit(map, padding) {
  const r = S.routes[S.sel]; if (!r) return; const b = new maplibregl.LngLatBounds();
  S.routes.forEach(x => x.shape.forEach(p => b.extend([p[1], p[0]])));
  map.fitBounds(b, { padding, duration: 0, bearing: 0, pitch: 0 });
}
async function choose(place) {
  S.dest = place; S.recents = [place, ...S.recents.filter(p => p.name !== place.name)].slice(0, 8);
  S.screen = 'preview'; S.carList = null; S.routes = []; render();
  try { S.routes = await valhallaRoutes(S.pos ? S.pos.p : IDSTEIN, place.c); S.sel = 0; } catch (e) { alert('Route fehlgeschlagen: ' + e.message); S.screen = 'map'; }
  for (const m of maps()) pushOverlay(m);
  pcam.stop(); ccam.stop();
  fit(pmap, { top: 130, left: 60, bottom: 380, right: 60 });
  const w = $('cwin').clientWidth; fit(cmap, { top: 24, left: w * 0.56 + 10, bottom: 14, right: 58 });   // CarMapViewController.show
  render();
}
// ---------- Oberfläche iPhone (ContentView.swift) ----------
const SYM = { left: 'M30 46V26a6 6 0 0 0-6-6H14m6-8-8 8 8 8', 'sharp-left': 'M30 46V26a6 6 0 0 0-6-6H14m6-8-8 8 8 8', right: 'M22 46V26a6 6 0 0 1 6-6h10m-6-8 8 8-8 8', 'sharp-right': 'M22 46V26a6 6 0 0 1 6-6h10m-6-8 8 8-8 8',
  'slight-left': 'M32 46V30L18 16m0 10V16h10', 'slight-right': 'M20 46V30l14-14m0 10V16H24', 'uturn-left': 'M18 46V22a8 8 0 0 1 16 0v14m-6-6 6 6 6-6', 'uturn-right': 'M18 46V22a8 8 0 0 1 16 0v14m-6-6 6 6 6-6',
  destination: 'M16 46V10m0 2h22l-5 8 5 8H16', straight: 'M26 46V12m-9 9 9-9 9 9' };
const sym = (k, cls = 'sym') => `<svg class="${cls}" viewBox="0 0 52 52" fill="none" stroke="#fff" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round"><path d="${SYM[k] || SYM.straight}"/></svg>`;
const hudbtn = (icon, act, title) => `<button class="hudbtn" data-act="${act}" title="${title}"><img src="${HUD(icon)}" alt=""></button>`;
function renderPhone() {
  const ui = $('pui'); const n = navState(); let h = '';
  if (S.screen === 'map' || S.screen === 'search') {
    h += `<div class="hudcol">${hudbtn('hud-recenter', 'center', 'Auf meinen Standort')}${hudbtn('hud-styles', 'styles', 'Stile')}${hudbtn('hud-explore', 'none', 'Entdecken')}${hudbtn('hud-settings', 'none', 'Einstellungen')}</div>`;
    h += `<div class="osm" style="bottom:${S.screen === 'search' ? 470 : 214}px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`;
    h += `<div class="sheet"><div class="handle"></div>`;
    if (S.screen === 'map') h += `<div class="mission"><div class="ic">⌖</div><div><b>Diese Woche</b><small>Fahre 5 Mal mit EzMaps</small></div><div class="n">0 / 5</div></div>`;
    h += `<div class="search" data-act="search">⌕ <input id="q" placeholder="Wohin?" value="${S.query.replace(/"/g, '&quot;')}"></div>`;
    if (S.screen === 'search') h += `<div class="results">${(S.results.length ? S.results : S.recents).map((r, i) => `<div class="res" data-pick="${i}"><div class="pin">⚲</div><div><b>${r.name}</b><small>${r.sub}</small></div></div>`).join('')}</div>`;
    else h += `<div class="tip">Tipp: Ziele mit dem Stern merken</div>`;
    h += `</div>`;
  } else if (S.screen === 'preview') {
    h += `<div class="hudcol" style="left:12px;right:auto;top:62px">${hudbtn('hud-back', 'back', 'Zurück')}</div>`;
    h += `<div class="osm" style="bottom:${S.routes.length ? 120 + S.routes.length * 66 : 200}px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`;
    h += `<div class="sheet"><div class="handle"></div><div class="title">${S.dest.name}</div><div class="sub">${S.dest.sub}</div>`;
    if (!S.routes.length) h += `<div class="sub" style="margin-top:12px">Route wird berechnet …</div>`;
    S.routes.forEach((r, i) => { const eta = new Date(Date.now() + r.duration * 1000);
      h += `<div class="route ${i === S.sel ? 'sel' : ''}" data-route="${i}"><b>${fmtMin(r.duration)}</b><small>${i ? 'Alternative ' + i : 'Schnellste'} · ${fmtDist(r.length)} · an ${clock(eta)}</small></div>`; });
    if (S.routes.length) h += `<button class="go" data-act="go">Los</button>`;
    h += `</div>`;
  } else if (S.screen === 'navigating') {
    const m = n && n.maneuver;
    if (!m) h += `<div class="navcard"><div><div class="s">Route wird gestartet …</div></div></div>`;
    else h += `<div class="navcard">${sym(m.kind)}<div><div class="d">${fmtDist(n.distanceToManeuver)}</div><div class="s">${m.street || m.text}</div></div></div>`;
    if (n && n.thenManeuver) h += `<div class="nextchip">danach ${lowerFirst(n.thenManeuver.text)}${n.thenManeuver.street ? ' · ' + n.thenManeuver.street : ''}</div>`;
    if (n && n.speedLimit) h += n.speedLimit < 0 ? `<div class="limit nolimit"></div>` : `<div class="limit">${n.speedLimit}</div>`;
    h += `<div class="hudcol" style="top:auto;bottom:150px">${hudbtn('hud-recenter', 'center', 'Mitte')}</div>`;
    h += `<div class="osm" style="bottom:118px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`;
    const time = n ? n.remainingTime : session.route.duration, remain = n ? n.remainingDistance : session.route.length;
    h += `<div class="navbar"><div style="width:54px"></div><div class="eta"><b>${clock(new Date(Date.now() + time * 1000))}</b><small>${fmtMin(time)} · ${fmtDist(remain)}</small></div><button class="xbtn" data-act="end">✕</button></div>`;
  } else if (S.screen === 'arrived') {
    h += `<div class="arrive"><div class="title">Angekommen</div><div class="sub">${S.dest ? S.dest.name : ''}</div><button class="go" data-act="end">Fertig</button></div>`;
  }
  if (S.message) h += `<div class="toast" style="top:${S.screen === 'navigating' ? 200 : 60}px">${S.message}</div>`;   // AppModel.show
  const focused = document.activeElement && document.activeElement.id === 'q';
  ui.innerHTML = h;
  const q = $('q'); if (q) { if (focused || S.screen === 'search') { q.focus(); q.setSelectionRange(q.value.length, q.value.length); } }
}

// ---------- Oberfläche CarPlay (CarPlaySceneDelegate.swift + iOS-Vorlagen) ----------
function renderCar() {
  const ui = $('cui'); const n = navState(); let h = '';
  if (S.carList) {
    if (S.carList === 'ziele') h += `<div class="clist"><div class="hd"><button class="back" data-car="back">‹</button>Ziele</div><div class="it first" data-car="search">⌕ Suchen</div>${S.recents.map((r, i) => `<div class="it" data-recent="${i}">↺ ${r.name}<small>${r.sub}</small></div>`).join('')}</div>`;
    else h += `<div class="clist"><div class="hd"><button class="back" data-car="back">‹</button>Suchen</div><input id="cq" placeholder="Ziel" value="${S.carQuery.replace(/"/g, '&quot;')}">${S.carResults.map((r, i) => `<div class="it" data-cres="${i}">${r.name}<small>${r.sub}</small></div>`).join('')}</div>`;
    const f = document.activeElement && document.activeElement.id === 'cq'; ui.innerHTML = h; const cq = $('cq'); if (cq && (f || !S.carResults.length)) cq.focus(); return;
  }
  h += `<button class="cbar" data-car="ziele">Ziele</button>`;
  h += `<div class="cosm">© OpenMapTiles<br>© OpenStreetMap-Mitwirkende</div>`;
  h += `<div class="cbtns">${[['hud-zoom-in', 'zin'], ['hud-zoom-out', 'zout'], ['hud-recenter', 'center'], ['hud-pan', 'pan']].map(([i, a]) => `<button class="cbtn" data-car="${a}"><img src="${HUD(i)}" alt=""></button>`).join('')}</div>`;
  if (S.screen === 'preview' && S.dest) {
    h += `<div class="cpanel"><div class="t">${S.dest.name}</div><div class="st">${S.routes[S.sel] ? carDist(S.routes[S.sel].length) : 'Route wird berechnet …'}</div><div style="flex:1"></div>`;
    if (S.routes.length > 1) h += `<button class="gray" data-car="routes">Routen</button>`;
    if (S.routes.length) h += `<button class="green" data-car="go">Los</button>`;
    h += `</div>`;
  }
  if (S.screen === 'navigating' && n && n.maneuver) {
    const m = n.maneuver;
    // CPNavigationSession: während der Neuberechnung pauseTrip(for: .rerouting) – GM-045
    if (rerouting) h += `<div class="cman"><div class="tx">Route wird neu berechnet</div></div>`;
    else h += `<div class="cman"><div class="row">${sym(m.kind)}<div class="d">${carDist(n.distanceToManeuver)}</div></div><div class="tx">${m.street ? m.text + ' · ' + m.street : m.text}</div></div>`;
    const cd = carDist(n.remainingDistance);
    h += `<div class="cest"><div><b>${clock(new Date(Date.now() + n.remainingTime * 1000))}</b><small>Ankunft</small></div><div><b>${Math.max(1, Math.round(n.remainingTime / 60))}</b><small>Min.</small></div><div><b>${cd.replace(/ k?m$/, '')}</b><small>${cd.endsWith('km') ? 'km' : 'm'}</small></div></div>`;
    if (n.speedLimit > 0) h += `<div class="climit">${n.speedLimit}</div>`;   // GM-022: kein Schild bei „unbegrenzt“ im Auto
  }
  ui.innerHTML = h;
}
function render() { renderPhone(); renderCar(); }

// Klicks
document.addEventListener('click', e => {
  const t = e.target.closest('[data-act],[data-pick],[data-route],[data-car],[data-recent],[data-cres],[data-speed]'); if (!t) return;
  const d = t.dataset;
  if (d.speed) { S.speed = +d.speed; document.querySelectorAll('[data-speed]').forEach(b => b.classList.toggle('on', b === t)); return; }
  if (d.act === 'search') { if (S.screen === 'map') { S.screen = 'search'; render(); } return; }
  if (d.act === 'center') { tracking = true; pcam.attach(); if (S.pos && S.screen !== 'navigating') pmap.easeTo({ center: [S.pos.p[1], S.pos.p[0]], duration: 400 }); return; }
  if (d.act === 'styles') { const sel = $('style'); sel.selectedIndex = (sel.selectedIndex + 1) % sel.options.length; applyStyle(sel.value); return; }
  if (d.act === 'back') { S.screen = 'map'; S.routes = []; S.dest = null; for (const m of maps()) pushOverlay(m); ccam.start(); render(); return; }
  if (d.act === 'go' || d.car === 'go') return startNav();
  if (d.act === 'end') return endNav();
  if (d.pick) return choose((S.results.length ? S.results : S.recents)[+d.pick]);
  if (d.route) { S.sel = +d.route; for (const m of maps()) pushOverlay(m); render(); return; }
  if (d.car === 'ziele') { S.carList = 'ziele'; return render(); }
  if (d.car === 'search') { S.carList = 'search'; return render(); }
  if (d.car === 'back') { S.carList = S.carList === 'search' ? 'ziele' : null; return render(); }
  if (d.recent) return choose(S.recents[+d.recent]);
  if (d.cres) return choose(S.carResults[+d.cres]);
  if (d.car === 'zin') return ccam.running ? ccam.zoom(1) : cmap.zoomIn();
  if (d.car === 'zout') return ccam.running ? ccam.zoom(-1) : cmap.zoomOut();
  if (d.car === 'center') { ccam.attach(); return ccam.start(); }
  if (d.car === 'pan') { ccam.detached = true; return; }
  if (d.car === 'routes') { S.sel = (S.sel + 1) % S.routes.length; for (const m of maps()) pushOverlay(m); return render(); }
});
let qTimer = 0;
document.addEventListener('input', e => {
  if (e.target.id === 'q') { S.query = e.target.value; if (S.screen !== 'search') S.screen = 'search';
    clearTimeout(qTimer); qTimer = setTimeout(async () => { S.results = S.query.length > 1 ? await photon(S.query, S.pos ? S.pos.p : IDSTEIN) : []; render(); }, 350); }
  if (e.target.id === 'cq') { S.carQuery = e.target.value; clearTimeout(qTimer); qTimer = setTimeout(async () => { S.carResults = S.carQuery.length > 1 ? await photon(S.carQuery, S.pos ? S.pos.p : IDSTEIN) : []; render(); }, 350); }
});
document.addEventListener('keydown', e => { if (!/INPUT|SELECT/.test(e.target.tagName)) { keys[e.key.toLowerCase()] = true; if (e.key.startsWith('Arrow')) e.preventDefault(); } });
document.addEventListener('keyup', e => { keys[e.key.toLowerCase()] = false; });
for (const m of [pmap, cmap]) m.on('click', e => driveTo(e.lngLat));
document.addEventListener('keydown', e => { if (e.key === 'Escape' && S.screen === 'search') { S.screen = 'map'; S.query = ''; S.results = []; render(); } });
$('style').addEventListener('change', e => applyStyle(e.target.value));
$('stop').addEventListener('click', () => { sim = null; manual = null; });
$('wrong').addEventListener('click', () => wrongTurn());
$('voice').addEventListener('change', e => { S.voice = e.target.checked; });
$('free').addEventListener('click', async () => {
  const txt = await (await fetch(BASE + 'tools/drive_wallrabenstein.txt')).text();
  const pts = txt.trim().split(/\s+/).map(s => s.split(',').map(Number));
  if (S.screen === 'navigating') endNav();
  startPathSim(pts, () => 50);                             // tools/mac_drive.sh: 14 m/s ≈ 50 km/h
  S.pos = { p: pts[0], h: bearing(pts[0], pts[1]), kmh: 50 }; tracking = true; ccam.start(); render();
});

// GM-050: Fadenkreuz wie CrosshairView – vier Arme (Lücke 9, Länge 110), nach außen ausgeblendet
let xhairColor = null;
function crosshairSVG(c) {
  const g = (id, x1, y1, x2, y2) => `<linearGradient id="${id}" gradientUnits="userSpaceOnUse" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}"><stop offset="0" stop-color="${c}"/><stop offset="1" stop-color="${c}" stop-opacity="0"/></linearGradient>`;
  return `<svg viewBox="-120 -120 240 240"><defs>${g('xr', 9, 0, 119, 0)}${g('xl', -9, 0, -119, 0)}${g('xd', 0, 9, 0, 119)}${g('xu', 0, -9, 0, -119)}</defs>
    <g stroke-width="1.6"><line x1="9" y1="0" x2="119" y2="0" stroke="url(#xr)"/><line x1="-9" y1="0" x2="-119" y2="0" stroke="url(#xl)"/>
    <line x1="0" y1="9" x2="0" y2="119" stroke="url(#xd)"/><line x1="0" y1="-9" x2="0" y2="-119" stroke="url(#xu)"/></g></svg>`;
}

// Haupttakt: Simulation, Kameras, Punkt
let last = performance.now();
function frame(now) {
  const dt = Math.min(0.1, (now - last) / 1000); last = now;
  stepSim(dt); stepManual(dt);
  const target = cameraTarget();   // AppModel.cameraTarget (js/navcore.js)
  ccam.tick(dt, target);
  if (S.screen === 'navigating') pcam.tick(dt, target);
  const dot = $('pdot');
  if (S.pos && S.screen !== 'navigating') {
    const p = pmap.project([S.pos.p[1], S.pos.p[0]]); dot.style.left = p.x + 'px'; dot.style.top = p.y + 'px'; dot.style.transform = `rotate(${S.pos.h - pmap.getBearing()}deg)`; dot.style.display = 'block';
  } else dot.style.display = 'none';
  const xc = { 'neon-city': 'rgba(255,255,255,.9)', 'wild-west': 'rgba(155,22,18,.9)' }[S.style];   // CrosshairView.color(for:)
  if (xc && xhairColor !== xc) { xhairColor = xc; for (const id of ['pxh', 'cxh']) $(id).innerHTML = crosshairSVG(xc); }
  $('pxh').style.display = xc && (S.screen === 'navigating' ? pcam.detached : !tracking) ? 'block' : 'none';
  $('cxh').style.display = xc && ccam.detached ? 'block' : 'none';
  requestAnimationFrame(frame);
}
setInterval(() => { if (tracking && S.pos && (S.screen === 'map' || S.screen === 'search')) pmap.easeTo({ center: [S.pos.p[1], S.pos.p[0]], duration: 900, easing: x => x }); }, 1000);
setInterval(() => { $('clock').textContent = $('clock2').textContent = clock(new Date()); if (S.screen === 'navigating') render(); }, 1000);

S.pos = { p: IDSTEIN, h: 0, kmh: 0 };
applyStyle('neon-city').then(() => { ccam.start(); render(); requestAnimationFrame(frame); });
