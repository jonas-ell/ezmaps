// Karten-Textur je Stil (einmal zeichnen) + MapView (Kamera per CSS-3D, Overlay pro Frame).
// Später in der App: MapLibre-Style-JSON je Stil. Farben hier = Quelle für diese Styles.
import { A } from './assets.js';
const blipSet = style => A.ok ? ({ neon: A.blips.Neon, western: A.blips.Western, pixel: A.blips.Pixel })[style] : null; // Toy Town: eigene Zeichnung
function drawAsset(u, im, x, y, size, pixel) {
  if (pixel) { const k = Math.max(1, Math.round(size / im.width)); u.imageSmoothingEnabled = false; u.drawImage(im, Math.round(x - im.width * k / 2), Math.round(y - im.height * k / 2), im.width * k, im.height * k); u.imageSmoothingEnabled = true; }
  else u.drawImage(im, x - size / 2, y - size / 2, size, size);
}

export const TEX = { x0: -1800, y0: -1500, w: 3600, h: 3000 };
const WIDTH = { 0: 16, 1: 13, 2: 12, 3: 10, 4: 9, 5: 7, 6: 6, 7: 3.5 };
const MIN_PX = { 0: 4.4, 1: 3.6, 2: 3, 3: 2.4, 4: 2, 5: 1.4, 6: 1.2, 7: 1 };

// GM-025: „Klassik“ ist der Gratis-Stil (heller Stadtplan); Neon City und die übrigen Stile sind Kauf-Stile (free: false)
export const STYLES = {
  classic: { name: 'Klassik', free: true, route: '#1a73e8', routeEdge: '#0b3d91', alt: 'rgba(90,110,140,0.5)', bg: '#f2efe9', haze: [222, 230, 240] },
  neon:    { name: 'Neon City', route: '#a13df0', routeEdge: '#4b1a73', alt: 'rgba(200,200,205,0.55)', bg: '#3b3c3e', haze: [59, 60, 62] },
  western: { name: 'Wild West', route: '#c0261f', routeEdge: '#4a0d0a', alt: 'rgba(90,60,30,0.45)', bg: '#c4ac80', haze: [196, 172, 128] },
  pixel:   { name: 'Pixel Quest', route: '#ffcc33', routeEdge: '#7a4a00', alt: 'rgba(255,255,255,0.6)', bg: '#1b2a5a', haze: [27, 42, 90], pixelated: true },
  toy:     { name: 'Toy Town', route: '#ff7a00', routeEdge: '#ffffff', alt: 'rgba(255,255,255,0.75)', bg: '#8dc63f', haze: [196, 230, 255] },
};

// ------------------------------------------------------------------ Hilfen
let seed = 7;
const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
export const hash = (x, y) => { let h = (x * 374761393 + y * 668265263) | 0; h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };
function poly(ctx, pts, close) { ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1]); for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]); if (close) ctx.closePath(); }
function inPoly(pts, x, y) {
  let c = false;
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    const [xi, yi] = pts[i], [xj, yj] = pts[j];
    if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) c = !c;
  }
  return c;
}
const bbox = pts => { let a = Infinity, b = Infinity, c = -Infinity, d = -Infinity; for (const [x, y] of pts) { a = Math.min(a, x); b = Math.min(b, y); c = Math.max(c, x); d = Math.max(d, y); } return [a, b, c, d]; };
const areaOf = pts => { let s = 0; for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) s += (pts[j][0] + pts[i][0]) * (pts[j][1] - pts[i][1]); return s / 2; };

// GM-006: Canvas auch im Worker (OffscreenCanvas) erzeugen können
const mk = (w, h) => typeof document !== 'undefined' ? Object.assign(document.createElement('canvas'), { width: w, height: h }) : new OffscreenCanvas(w, h);
let R = TEX; // gerade gezeichneter Bereich (Meter)
function noiseCanvas(size, fn) { const c = mk(size, size); fn(c.getContext('2d'), size); return c; }
const terrainTexture = () => noiseCanvas(1024, (g, size) => {
  for (let i = 0; i < 260; i++) {
    const x = rnd() * size, y = rnd() * size, r = 20 + rnd() * 140, light = rnd() > 0.5, grad = g.createRadialGradient(x, y, 0, x, y, r);
    grad.addColorStop(0, light ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.08)'); grad.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = grad; g.fillRect(x - r, y - r, r * 2, r * 2);
  }
  const n = g.getImageData(0, 0, size, size);
  for (let i = 0; i < n.data.length; i += 4) { const v = (rnd() - 0.5) * 10; n.data[i] += v; n.data[i + 1] += v; n.data[i + 2] += v; n.data[i + 3] = Math.max(n.data[i + 3], 10); }
  g.putImageData(n, 0, 0);
});
const paperTexture = () => noiseCanvas(1024, (g, size) => {
  g.fillStyle = '#808080'; g.fillRect(0, 0, size, size);
  for (let i = 0; i < 120; i++) {
    const x = rnd() * size, y = rnd() * size, r = 30 + rnd() * 160, grad = g.createRadialGradient(x, y, 0, x, y, r);
    grad.addColorStop(0, `rgba(90,60,30,${0.05 + rnd() * 0.08})`); grad.addColorStop(1, 'rgba(90,60,30,0)');
    g.fillStyle = grad; g.fillRect(x - r, y - r, 2 * r, 2 * r);
  }
  const n = g.getImageData(0, 0, size, size);
  for (let i = 0; i < n.data.length; i += 4) { const v = (rnd() - 0.5) * 26; n.data[i] += v; n.data[i + 1] += v; n.data[i + 2] += v; }
  g.putImageData(n, 0, 0);
  g.strokeStyle = 'rgba(80,55,30,0.10)'; g.lineWidth = 1;
  for (let i = 0; i < 400; i++) { const x = rnd() * size, y = rnd() * size, a = rnd() * 6.28, l = 6 + rnd() * 18; g.beginPath(); g.moveTo(x, y); g.lineTo(x + Math.cos(a) * l, y + Math.sin(a) * l); g.stroke(); }
});
const treePattern = ink => noiseCanvas(64, g => {
  g.strokeStyle = ink; g.lineWidth = 1.6; g.lineCap = 'round';
  for (const [x, y] of [[12, 14], [44, 10], [28, 34], [54, 42], [10, 52], [38, 58]]) {
    g.beginPath(); g.arc(x, y, 5, Math.PI, 0); g.lineTo(x + 5, y + 2); g.moveTo(x - 5, y); g.lineTo(x - 5, y + 2); g.moveTo(x, y + 2); g.lineTo(x, y + 7); g.stroke();
  }
});

// ------------------------------------------------------------------ Textur zeichnen
export function renderRegion(scene, style, region, S) {
  seed = 7; R = region;
  const pixel = style === 'pixel';
  const c = mk(Math.round(region.w * S), Math.round(region.h * S));
  const ctx = c.getContext('2d', { willReadFrequently: pixel });
  const world = new DOMMatrix().scale(S).translate(-region.x0, -region.y0);
  if (pixel) drawPixel(ctx, scene, c.width, c.height, world, S);
  else {
    ctx.setTransform(world);
    if (style === 'neon') drawClassic(ctx, scene, S, NEON);
    if (style === 'classic') drawClassic(ctx, scene, S, CLASSIC);
    if (style === 'western') drawClassic(ctx, scene, S, WESTERN);
    if (style === 'toy') drawToy(ctx, scene, S);
  }
  R = TEX;
  return c;
}
export async function renderTexture(scene, style) {
  const pixel = style === 'pixel';
  const S = pixel ? 0.625 : 1.8;                      // Bildpunkte pro Meter
  const c = renderRegion(scene, style, TEX, S);
  const blob = await new Promise(r => c.toBlob(r, pixel ? 'image/png' : 'image/jpeg', 0.9));
  c.width = c.height = 1; // Speicher freigeben
  return { url: URL.createObjectURL(blob), S, pixelated: pixel };
}

export const NEON_ROADS = { // für drawRoads (Vektorstraßen), derzeit nicht aktiv – Straßen bleiben breit in der Textur (Entscheidung Cloud-Claude GM-010)
  color: ['#ececec', '#dcdcdc', '#d2d2d2', '#c2c2c2', '#b4b4b4', '#929292', '#7d7d7d', '#616161'],
  width: [3, 2.5, 2.2, 2, 1.8, 1.3, 1.1, 0.9],
};
// GM-010: Look nach Vorlage (dunkle Open-World-Übersicht): fast schwarzes Land, Stadt als dunkelgraue Blöcke,
// breite hellgraue Straßen ohne Rand, Gebäude nur knapp heller als der Block, Wasser grau und hell
const NEON = { // GM-024: nach Foto des Nutzers – Mirror in tools/maplibre/build_style.py, change both
  land: '#3b3c3e', residential: '#3b3c3e', industrial: '#3e3f41', farm: '#38393b', park: '#36383a', forest: '#333537',
  water: '#5d6870', waterLine: '#5d6870', building: '#5b5c5f', buildingEdge: '#4a4b4e', casing: '#151617', widen: 1.5,
  road: r => r <= 4 ? '#ececec' : r <= 6 ? '#dcdcdc' : '#c4c4c4', rail: '#2b2c2e', texture: terrainTexture,
  hill: true,
};
const WESTERN = {
  land: '#dcc59a', residential: '#d4bb8a', industrial: '#ccb07f', farm: '#e3cfa2', park: '#d6c18c', forest: '#cdb782',
  water: '#a3b7ae', waterLine: '#6d8d88', building: '#9b7a50', buildingEdge: '#5e4127', casing: '#4a3220',
  road: r => r <= 4 ? '#f2e4bf' : '#7a5a38', thinMinor: true, rail: '#4a3220', ties: true, texture: paperTexture, trees: '#6b4f2e', vignette: true,
};

// GM-025: Gratis-Stil „Klassik“ – ruhiger, heller Stadtplan (bewusst schlicht, damit sich die Spiel-Stile lohnen)
const flatTexture = () => noiseCanvas(8, g => { g.fillStyle = '#808080'; g.fillRect(0, 0, 8, 8); }); // „overlay“ mit 50 % Grau = keine Änderung
const CLASSIC = {
  land: '#f2efe9', residential: '#ece7e0', industrial: '#ebe3e8', farm: '#eef0d6', park: '#d4ebc8', forest: '#c3dfb4',
  water: '#aad3df', waterLine: '#9cc9d9', building: '#ddd5cc', buildingEdge: '#cbc0b5', casing: '#c9c1b6', widen: 1.15,
  road: r => r <= 1 ? '#f7c56b' : r <= 3 ? '#fde7a6' : '#ffffff', rail: '#a3a3a3', texture: flatTexture,
};

function drawClassic(ctx, scene, S, T) {
  const px = 1 / S;
  ctx.fillStyle = T.land; ctx.fillRect(R.x0 - 50, R.y0 - 50, R.w + 100, R.h + 100);
  for (const k of ['farm', 'park', 'forest']) {
    ctx.fillStyle = T[k]; for (const a of scene.areas) if (a.k === k) { poly(ctx, a.pts, true); ctx.fill(); }
  }
  if (T.urban) urbanBlocks(ctx, scene, T);
  for (const k of ['residential', 'industrial', 'water']) {
    ctx.fillStyle = T[k]; for (const a of scene.areas) if (a.k === k) { poly(ctx, a.pts, true); ctx.fill(); }
  }
  if (T.trees) {
    const pat = ctx.createPattern(treePattern(T.trees), 'repeat'); pat.setTransform(new DOMMatrix().scale(0.7));
    ctx.fillStyle = pat; for (const a of scene.areas) if (a.k === 'forest') { poly(ctx, a.pts, true); ctx.fill(); }
  }
  ctx.strokeStyle = T.waterLine; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  for (const l of scene.lines) if (l.k === 'water') { ctx.lineWidth = Math.max(l.c === 'river' ? 9 : 3, (l.c === 'river' ? 1.2 : 0.6) * px); poly(ctx, l.pts); ctx.stroke(); }
  if (T.hill && scene.hill) { // Hügel-Schattierung (Terrain Tiles: SRTM / EU-DEM)
    ctx.save(); ctx.globalCompositeOperation = 'overlay'; ctx.globalAlpha = 0.95; ctx.drawImage(scene.hill, TEX.x0, TEX.y0, TEX.w, TEX.h); ctx.restore();
  }
  ctx.fillStyle = T.building; if (T.buildingEdge) { ctx.strokeStyle = T.buildingEdge; ctx.lineWidth = 0.7; }
  for (const a of scene.areas) if (a.k === 'building') { poly(ctx, a.pts, true); ctx.fill(); if (T.buildingEdge) ctx.stroke(); }
  // Struktur (Relief bzw. Papier) als Overlay
  ctx.save(); ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.globalCompositeOperation = 'overlay';
  ctx.fillStyle = ctx.createPattern(T.texture(), 'repeat'); ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height); ctx.restore();
  ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  for (const l of scene.lines) if (l.k === 'rail' && !l.tunnel) {
    ctx.strokeStyle = T.rail; ctx.lineWidth = 1.5; ctx.setLineDash(T.ties ? [] : [6, 4]); poly(ctx, l.pts); ctx.stroke();
    if (T.ties) { ctx.lineWidth = 4; ctx.setLineDash([0.9, 4]); ctx.lineCap = 'butt'; poly(ctx, l.pts); ctx.stroke(); ctx.lineCap = 'round'; }
    ctx.setLineDash([]);
  }
  const roads = scene.lines.filter(l => l.k === 'road' && l.r <= 7).sort((a, b) => b.r - a.r);
  for (const pass of T.casing ? ['casing', 'fill'] : ['fill']) for (const l of roads) {
    const w = Math.max(WIDTH[l.r] * 0.75 * (T.widen || 1), MIN_PX[l.r] * px * (T.thinMinor && l.r >= 5 ? 2.4 : 1)); // GM-015: aus der Ferne (Deutschland-Kacheln) sichtbar bleiben
    if (T.thinMinor && l.r >= 5) { if (pass === 'fill') { ctx.strokeStyle = T.road(l.r); ctx.lineWidth = w * 0.42; poly(ctx, l.pts); ctx.stroke(); } continue; }
    ctx.strokeStyle = pass === 'casing' ? T.casing : T.road(l.r); ctx.lineWidth = pass === 'casing' ? w + (T.thinMinor ? 2.2 : 1.2) : w;
    poly(ctx, l.pts); ctx.stroke();
  }
  if (T.hill && R === TEX) { // GM-010: Rand der Textur weich in die Landfarbe auslaufen lassen (keine sichtbare Kante)
    const f = 260;
    for (const [x0, y0, x1, y1, rx, ry, rw, rh] of [[R.x0, 0, R.x0 + f, 0, R.x0, R.y0, f, R.h], [R.x0 + R.w, 0, R.x0 + R.w - f, 0, R.x0 + R.w - f, R.y0, f, R.h], [0, R.y0, 0, R.y0 + f, R.x0, R.y0, R.w, f], [0, R.y0 + R.h, 0, R.y0 + R.h - f, R.x0, R.y0 + R.h - f, R.w, f]]) {
      const g = ctx.createLinearGradient(x0, y0, x1, y1); g.addColorStop(0, T.land); g.addColorStop(1, 'rgba(30,31,32,0)');
      ctx.fillStyle = g; ctx.fillRect(rx, ry, rw, rh);
    }
  }
  if (T.vignette) {
    ctx.save(); ctx.setTransform(1, 0, 0, 1, 0, 0);
    const W = ctx.canvas.width, H = ctx.canvas.height, vg = ctx.createRadialGradient(W / 2, H / 2, W * 0.25, W / 2, H / 2, W * 0.7);
    vg.addColorStop(0, 'rgba(90,55,25,0)'); vg.addColorStop(1, 'rgba(90,55,25,0.3)'); ctx.fillStyle = vg; ctx.fillRect(0, 0, W, H); ctx.restore();
  }
}

// Bebaute Fläche als Blöcke: rund um Gebäude und Wohnstraßen dunkelgrau, freies Gelände bleibt fast schwarz
function urbanBlocks(ctx, scene, T) {
  ctx.save(); ctx.fillStyle = ctx.strokeStyle = T.urban; ctx.lineCap = ctx.lineJoin = 'round';
  ctx.lineWidth = T.urbanReach;
  for (const a of scene.areas) if (a.k === 'building') { poly(ctx, a.pts, true); ctx.fill(); ctx.stroke(); }
  for (const l of scene.lines) if (l.k === 'road' && l.r >= 5 && l.r <= 7) { poly(ctx, l.pts); ctx.stroke(); }
  ctx.restore();
}

// ---- Toy Town (Spielteppich): Asphalt mit Mittellinie, Zebrastreifen, Comic-Häuser schräg von vorn, Tupfen-Bäume
const TOY = {
  grass: '#8dc63f', grass2: '#a3d65a', park: '#7cc142', forest: '#62b235', farm: '#b9d86a', industrial: '#cfd0d2', water: '#4ab0ea',
  waterEdge: '#f2d48b', asphalt: '#66686c', sidewalk: '#c9cbce', dash: '#ffffff',
  walls: ['#f6d743', '#fdfdfd', '#ee5a4a', '#7cc3ee', '#f5b041', '#f4e2c4'], roofs: ['#e3412f', '#c8372a', '#ef7d2d', '#e3412f', '#8b8f96', '#3d78c9'],
  window: '#3c8fe0', frame: '#ffffff', ink: '#2f3640',
};
function drawToy(ctx, scene, S) {
  ctx.fillStyle = TOY.grass; ctx.fillRect(R.x0 - 50, R.y0 - 50, R.w + 100, R.h + 100);
  ctx.fillStyle = TOY.grass2; // helle Rasenflecken
  for (let i = 0; i < 1400 * R.w * R.h / (TEX.w * TEX.h); i++) { const x = R.x0 + rnd() * R.w, y = R.y0 + rnd() * R.h, r = 6 + rnd() * 22; ctx.beginPath(); ctx.ellipse(x, y, r * 1.6, r, rnd() * 3, 0, 7); ctx.fill(); }
  const fill = (k, col) => { ctx.fillStyle = col; for (const a of scene.areas) if (a.k === k) { poly(ctx, a.pts, true); ctx.fill(); } };
  fill('farm', TOY.farm); fill('park', TOY.park); fill('forest', TOY.forest); fill('industrial', TOY.industrial);
  // Wasser mit Steinrand
  ctx.lineJoin = 'round'; ctx.lineCap = 'round';
  for (const a of scene.areas) if (a.k === 'water') { poly(ctx, a.pts, true); ctx.strokeStyle = TOY.waterEdge; ctx.lineWidth = 5; ctx.stroke(); ctx.fillStyle = TOY.water; ctx.fill(); ctx.strokeStyle = '#2b86c9'; ctx.lineWidth = 0.8; ctx.stroke(); }
  for (const l of scene.lines) if (l.k === 'water') {
    const w = l.c === 'river' ? 9 : 3.5;
    ctx.strokeStyle = TOY.waterEdge; ctx.lineWidth = w + 3; poly(ctx, l.pts); ctx.stroke();
    ctx.strokeStyle = TOY.water; ctx.lineWidth = w; poly(ctx, l.pts); ctx.stroke();
  }
  // Bahn: Schotter, Schwellen, Schienen
  for (const l of scene.lines) if (l.k === 'rail' && !l.tunnel) {
    ctx.strokeStyle = '#a7a39b'; ctx.lineWidth = 5; poly(ctx, l.pts); ctx.stroke();
    ctx.strokeStyle = '#7a5a3a'; ctx.lineWidth = 4; ctx.setLineDash([0.7, 1.4]); ctx.lineCap = 'butt'; poly(ctx, l.pts); ctx.stroke(); ctx.setLineDash([]);
    ctx.strokeStyle = '#555'; ctx.lineWidth = 0.35;
    for (const off of [-1.1, 1.1]) { ctx.save(); poly(ctx, offsetLine(l.pts, off)); ctx.stroke(); ctx.restore(); }
    ctx.lineCap = 'round';
  }
  // Straßen
  const roads = scene.lines.filter(l => l.k === 'road' && l.r <= 7).sort((a, b) => b.r - a.r);
  const tw = r => ({ 0: 15, 1: 12, 2: 11, 3: 10, 4: 9.5, 5: 8, 6: 6.5, 7: 4.5 })[r];
  for (const l of roads) { ctx.strokeStyle = TOY.sidewalk; ctx.lineWidth = tw(l.r) + 3.5; poly(ctx, l.pts); ctx.stroke(); }
  for (const l of roads) { ctx.strokeStyle = TOY.asphalt; ctx.lineWidth = tw(l.r); poly(ctx, l.pts); ctx.stroke(); }
  ctx.strokeStyle = TOY.dash; ctx.lineCap = 'butt';
  for (const l of roads) if (l.r <= 5) { ctx.lineWidth = 0.55; ctx.setLineDash([3, 3]); poly(ctx, l.pts); ctx.stroke(); }
  ctx.setLineDash([]);
  // Zebrastreifen an Kreuzungen
  const deg = new Map();
  for (const l of roads) if (l.ids && l.r <= 6) l.ids.forEach((id, i) => deg.set(id, (deg.get(id) || 0) + (i === 0 || i === l.ids.length - 1 ? 1 : 2)));
  ctx.fillStyle = '#ffffff';
  for (const l of roads) {
    if (!l.ids || l.r < 3 || l.r > 6) continue;
    l.ids.forEach((id, i) => {
      if ((deg.get(id) || 0) < 3) return;
      for (const j of [i - 1, i + 1]) {
        if (j < 0 || j >= l.pts.length) continue;
        const a = l.pts[i], b = l.pts[j], L = Math.hypot(b[0] - a[0], b[1] - a[1]); if (L < 16) continue;
        const u = [(b[0] - a[0]) / L, (b[1] - a[1]) / L], n = [-u[1], u[0]], d = tw(l.r) / 2 + 4.5, c = [a[0] + u[0] * d, a[1] + u[1] * d];
        const half = tw(l.r) / 2 - 0.6;
        for (let k = -half; k <= half; k += 1.15) {
          const cx = c[0] + n[0] * k, cy = c[1] + n[1] * k;
          ctx.beginPath(); ctx.moveTo(cx - u[0] * 1.4 - n[0] * 0.3, cy - u[1] * 1.4 - n[1] * 0.3); ctx.lineTo(cx + u[0] * 1.4 - n[0] * 0.3, cy + u[1] * 1.4 - n[1] * 0.3);
          ctx.lineTo(cx + u[0] * 1.4 + n[0] * 0.3, cy + u[1] * 1.4 + n[1] * 0.3); ctx.lineTo(cx - u[0] * 1.4 + n[0] * 0.3, cy - u[1] * 1.4 + n[1] * 0.3); ctx.fill();
        }
      }
    });
  }
  // Bäume (in Wald und Parks), danach Häuser – alles von Nord nach Süd sortiert, damit Vorderes vorne liegt
  const items = [];
  for (const a of scene.areas) {
    if (a.k !== 'forest' && a.k !== 'park') continue;
    const [x0, y0, x1, y1] = bbox(a.pts); if (x1 < R.x0 || x0 > R.x0 + R.w || y1 < R.y0 || y0 > R.y0 + R.h) continue;
    const step = a.k === 'forest' ? 7.5 : 14;
    for (let y = y0; y < y1; y += step) for (let x = x0; x < x1; x += step) {
      const jx = x + (hash(Math.round(x), Math.round(y)) - 0.5) * step, jy = y + (hash(Math.round(y), Math.round(x)) - 0.5) * step;
      if (a.k === 'park' && hash(Math.round(x * 3), Math.round(y * 7)) < 0.45) continue;
      if (inPoly(a.pts, jx, jy)) items.push({ y: jy, tree: [jx, jy, 2.6 + hash(Math.round(jx), 5) * 1.6] });
    }
  }
  scene.areas.forEach((a, i) => { if (a.k !== 'building') return; const bb = bbox(a.pts); if (bb[2] < R.x0 || bb[0] > R.x0 + R.w || bb[3] < R.y0 || bb[1] > R.y0 + R.h + 20) return; items.push({ y: bb[3], b: a, i }); });
  items.sort((p, q) => p.y - q.y);
  for (const it of items) it.tree ? toyTree(ctx, ...it.tree) : toyHouse(ctx, it.b.pts, it.i);
}
function offsetLine(pts, off) {
  return pts.map((p, i) => {
    const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)], L = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1;
    return [p[0] - (b[1] - a[1]) / L * off, p[1] + (b[0] - a[0]) / L * off];
  });
}
function toyTree(ctx, x, y, r) {
  ctx.fillStyle = 'rgba(30,70,20,0.35)'; ctx.beginPath(); ctx.ellipse(x + r * 0.35, y + r * 0.45, r, r * 0.75, 0, 0, 7); ctx.fill();
  ctx.fillStyle = '#3f9b2d'; ctx.strokeStyle = '#2a6b1f'; ctx.lineWidth = 0.4; ctx.beginPath(); ctx.arc(x, y - r * 0.4, r, 0, 7); ctx.fill(); ctx.stroke();
  ctx.fillStyle = '#6cc04a'; ctx.beginPath(); ctx.arc(x - r * 0.3, y - r * 0.75, r * 0.42, 0, 7); ctx.fill();
}
function toyHouse(ctx, pts, i) {
  const A = Math.abs(areaOf(pts)); if (A < 6) return;
  const h = Math.min(16, Math.max(3.5, Math.sqrt(A) * 0.42)) * (0.8 + hash(i, 3) * 0.4) * 0.6; // schräge Ansicht: Höhe zeigt nach oben (Norden)
  const wall = TOY.walls[Math.floor(hash(i, 1) * TOY.walls.length)], roof = A > 900 ? '#8b8f96' : TOY.roofs[Math.floor(hash(i, 2) * TOY.roofs.length)];
  const ccw = areaOf(pts) > 0;
  ctx.lineJoin = 'round'; ctx.strokeStyle = TOY.ink; ctx.lineWidth = 0.35;
  for (let k = 0; k < pts.length - 1; k++) {
    const a = pts[k], b = pts[k + 1];
    const nx = ccw ? (b[1] - a[1]) : -(b[1] - a[1]), ny = ccw ? -(b[0] - a[0]) : (b[0] - a[0]);
    if (ny <= 0) continue; // nur Wände, die nach Süden (zum Betrachter) zeigen
    ctx.fillStyle = wall; ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.lineTo(b[0], b[1] - h); ctx.lineTo(a[0], a[1] - h); ctx.closePath(); ctx.fill(); ctx.stroke();
    // Fenster
    const L = Math.hypot(b[0] - a[0], b[1] - a[1]), floors = Math.max(1, Math.floor(h / 2.4)), cols = Math.floor(L / 2.6);
    for (let f = 0; f < floors; f++) for (let cIdx = 0; cIdx < cols; cIdx++) {
      const u0 = (cIdx + 0.3) / cols * 1, u1 = (cIdx + 0.75) / cols, v0 = (f + 0.25) / floors * h, v1 = (f + 0.75) / floors * h;
      const P = (u, v) => [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u - v];
      const q = [P(u0, v0), P(u1, v0), P(u1, v1), P(u0, v1)];
      ctx.fillStyle = TOY.window; ctx.beginPath(); ctx.moveTo(...q[0]); q.slice(1).forEach(p => ctx.lineTo(...p)); ctx.closePath(); ctx.fill();
      ctx.strokeStyle = TOY.frame; ctx.lineWidth = 0.18; ctx.stroke(); ctx.strokeStyle = TOY.ink; ctx.lineWidth = 0.35;
    }
  }
  ctx.fillStyle = roof; ctx.beginPath(); pts.forEach((p, k) => k ? ctx.lineTo(p[0], p[1] - h) : ctx.moveTo(p[0], p[1] - h)); ctx.closePath(); ctx.fill(); ctx.stroke();
  if (A < 900) { // Firstlinie für Satteldach-Optik
    const [x0, y0, x1, y1] = bbox(pts); ctx.strokeStyle = 'rgba(0,0,0,0.25)'; ctx.lineWidth = 0.3;
    ctx.beginPath(); if (x1 - x0 > y1 - y0) { ctx.moveTo(x0 + 1, (y0 + y1) / 2 - h); ctx.lineTo(x1 - 1, (y0 + y1) / 2 - h); } else { ctx.moveTo((x0 + x1) / 2, y0 + 1 - h); ctx.lineTo((x0 + x1) / 2, y1 - 1 - h); } ctx.stroke();
  }
}

// ---- Pixel Quest (Retro-RPG-Oberwelt), 1 Kunstpixel = 1,6 m
const PX = {
  grass: [[96, 168, 58], [82, 148, 50], [124, 190, 76]], res: [110, 178, 66], farmA: [201, 180, 88], farmB: [179, 157, 69],
  forestFloor: [36, 95, 39], canopy: [47, 125, 50], canopyHi: [79, 166, 63], water: [59, 125, 216], wave: [143, 195, 255], sand: [232, 212, 138],
  dirt: [216, 184, 120], dirtEdge: [168, 134, 79], stone: [167, 167, 167], stoneHi: [189, 189, 189], stoneEdge: [96, 96, 96],
  rail: [90, 70, 50], ind: [156, 156, 136], indLine: [130, 130, 112],
  roofs: [[190, 70, 50], [176, 86, 58], [200, 100, 62], [190, 70, 50], [72, 108, 172], [150, 92, 62]],
};
function drawPixel(ctx, scene, lw, lh, world, S) {
  const g = ctx, cls = new Uint8Array(lw * lh), bid = new Uint32Array(lw * lh), s = 1 / S;
  const pass = (id, draw, ids) => {
    g.setTransform(1, 0, 0, 1, 0, 0); g.clearRect(0, 0, lw, lh); g.setTransform(world); g.fillStyle = g.strokeStyle = '#fff'; g.lineCap = 'round'; g.lineJoin = 'round';
    draw(g);
    const d = g.getImageData(0, 0, lw, lh).data;
    for (let i = 0; i < cls.length; i++) if (d[i * 4 + 3] > 110) { cls[i] = id; if (ids) bid[i] = d[i * 4] | (d[i * 4 + 1] << 8) | (d[i * 4 + 2] << 16); }
  };
  const areas = k => g => { for (const a of scene.areas) if (a.k === k) { poly(g, a.pts, true); g.fill(); } };
  pass(1, areas('residential')); pass(2, areas('farm')); pass(3, areas('park')); pass(4, areas('industrial')); pass(5, areas('forest'));
  pass(6, g => { areas('water')(g); for (const l of scene.lines) if (l.k === 'water') { g.lineWidth = Math.max(l.c === 'river' ? 9 : 4, 1.2 * s); poly(g, l.pts); g.stroke(); } });
  pass(7, g => { let n = 0; for (const a of scene.areas) if (a.k === 'building') { n++; g.fillStyle = `rgb(${n & 255},${(n >> 8) & 255},${(n >> 16) & 255})`; poly(g, a.pts, true); g.fill(); } }, true);
  pass(8, g => { for (const l of scene.lines) if (l.k === 'road' && l.r >= 5 && l.r <= 7) { g.lineWidth = Math.max(WIDTH[l.r] * 0.9, 2.2 * s); poly(g, l.pts); g.stroke(); } });
  pass(9, g => { for (const l of scene.lines) if (l.k === 'road' && l.r <= 4) { g.lineWidth = Math.max(WIDTH[l.r] * 1.1, 3.2 * s); poly(g, l.pts); g.stroke(); } });
  pass(10, g => { for (const l of scene.lines) if (l.k === 'rail' && !l.tunnel) { g.lineWidth = 1.6 * s; poly(g, l.pts); g.stroke(); } });
  const img = g.createImageData(lw, lh), o = img.data, at = (x, y) => (x < 0 || y < 0 || x >= lw || y >= lh) ? 0 : cls[y * lw + x];
  for (let y = 0; y < lh; y++) for (let x = 0; x < lw; x++) {
    const c = cls[y * lw + x], h = hash(x, y), nb = k => at(x - 1, y) === k || at(x + 1, y) === k || at(x, y - 1) === k || at(x, y + 1) === k;
    let col;
    switch (c) {
      case 0: case 1: case 3:
        col = c === 1 ? PX.res : h < 0.07 ? PX.grass[1] : h > 0.965 ? PX.grass[2] : PX.grass[0];
        if (c === 3 && h > 0.985) col = h > 0.993 ? [255, 111, 168] : [255, 240, 122];
        if (nb(6)) col = PX.sand;
        if (at(x, y - 1) === 7) col = col.map(v => v * 0.68);
        break;
      case 2: col = (y % 4 < 2) ? PX.farmA : PX.farmB; break;
      case 4: col = (x % 6 === 0 || y % 6 === 0) ? PX.indLine : PX.ind; if (at(x, y - 1) === 7) col = col.map(v => v * 0.7); break;
      case 5: { const row = Math.floor(y / 6), lx = (x + (row % 2) * 3) % 6, ly = y % 6, dx = lx - 2.5, dy = ly - 2.5; col = Math.hypot(dx, dy) < 2.6 ? ((dx + dy < -1.5) ? PX.canopyHi : PX.canopy) : PX.forestFloor; break; }
      case 6: col = ((x + Math.floor(y / 3) * 3) % 9 === 0 && y % 3 === 0) ? PX.wave : PX.water; break;
      case 7: {
        const roof = PX.roofs[Math.floor(hash(bid[y * lw + x], 17) * PX.roofs.length)];
        col = at(x, y - 1) !== 7 ? roof.map(v => Math.min(255, v * 1.3 + 20)) : at(x, y + 1) !== 7 ? roof.map(v => v * 0.55) : y % 3 === 0 ? roof.map(v => v * 0.85) : roof; break;
      }
      case 8: col = (nb(0) || nb(1) || nb(3) || nb(5) || nb(7)) ? PX.dirtEdge : PX.dirt; break;
      case 9: col = (nb(0) || nb(1) || nb(3) || nb(5) || nb(7) || nb(8)) ? PX.stoneEdge : ((x + y) % 4 === 0 ? PX.stoneHi : PX.stone); break;
      case 10: col = (x + y) % 3 === 0 ? [60, 45, 30] : PX.rail; break;
    }
    const i = (y * lw + x) * 4; o[i] = col[0]; o[i + 1] = col[1]; o[i + 2] = col[2]; o[i + 3] = 255;
  }
  g.setTransform(1, 0, 0, 1, 0, 0); g.putImageData(img, 0, 0);
}

// ------------------------------------------------------------------ Sprites (eigene Entwürfe)
export const SPR = {
  // Spieler-Pfeil nach Vorlage des Nutzers (GM-005): weiße Pixel-Spitze, schwarzer Rand, nach oben zeigend
  arrow: { pal: { k: '#000000', W: '#ffffff', w: '#dcdcdc', g: '#a4a4a4' },
    rows: ['...k...', '..kWk..', '.kwWwk.', 'kwWWWgk', 'kwWWWgk', 'kwWWWgk', 'kwWWWgk', 'kwwwwgk', 'kgggggk', 'kkkkkkk'] },
  car: { pal: { k: '#1a1a1a', r: '#e8372c', R: '#ff7b5c', d: '#9c1f17', w: '#bfe6ff', y: '#ffe066' },
    rows: ['..kkkkk..', '.krrRrrk.', 'kryrRryrk', 'krrrRrrrk', 'kwwwwwwwk', 'kwwwwwwwk', 'krrrrrrrk', 'krrrrrrrk', 'krrrrrrrk', 'kwwwwwwwk', 'kdrrrrrdk', 'kdddddddk', '.kkkkkkk.'] },
  P: { pal: { k: '#10204a', b: '#3b6fe0', w: '#ffffff' }, rows: ['kkkkkkkk', 'kbbbbbbk', 'kbwwwbbk', 'kbwbbwbk', 'kbwwwbbk', 'kbwbbbbk', 'kbbbbbbk', 'kkkkkkkk'] },
  fuel: { pal: { k: '#3a0d08', r: '#e8372c', w: '#ffffff' }, rows: ['.kkkkk..', '.kwwwk..', '.kwwwkk.', '.krrrk.k', '.krrrk.k', '.krrrkk.', '.krrrk..', 'kkkkkkk.'] },
  food: { pal: { k: '#3a1a08', b: '#c8742e', B: '#e8a050', w: '#fff3d6' }, rows: ['...kk...', '..kBBk..', '.kBBbbk.', '.kBbbbk.', '..kbbk..', '...kwk..', '...kwwk.', '....kk..'] },
  cart: { pal: { k: '#3a2a00', y: '#ffcc33', g: '#555' }, rows: ['k.......', 'kkkkkkkk', '.kyyyyyk', '.kyyyyk.', '..kkkkk.', '..k...k.', '.kgk.kgk', '..k...k.'] },
  chest: { pal: { k: '#2a1500', b: '#8a4a1c', B: '#b8692c', y: '#ffcc33' }, rows: ['.kkkkkkkk.', 'kBBBBBBBBk', 'kbbbbbbbbk', 'kkkkyykkkk', 'kbbbyybbbk', 'kbbbbbbbbk', 'kbbbbbbbbk', '.kkkkkkkk.'] },
  friend: { pal: { k: '#000', p: '#ff4fd8', w: '#fff' }, rows: ['..kkkk..', '.kppppk.', 'kpwppwpk', 'kppppppk', 'kpwwwwpk', '.kppppk.', '..kkkk..'] },
};
export function sprite(u, spr, cx, cy, size) {
  const rows = spr.rows, h = rows.length, w = Math.max(...rows.map(r => r.length)), x0 = Math.round(cx - w * size / 2), y0 = Math.round(cy - h * size / 2);
  for (let y = 0; y < h; y++) for (let x = 0; x < rows[y].length; x++) { const c = rows[y][x]; if (c === '.') continue; u.fillStyle = spr.pal[c]; u.fillRect(x0 + x * size, y0 + y * size, size, size); }
}

// ------------------------------------------------------------------ MapView
export class MapView {
  constructor(el) {
    this.el = el; el.classList.add('mv');
    this.ground = document.createElement('div'); this.ground.className = 'mv-ground';
    this.img = document.createElement('img'); this.img.className = 'mv-tex mv-home'; this.img.draggable = false;
    this.detail = document.createElement('canvas'); this.detail.className = 'mv-tex mv-detail'; this.detail.style.display = 'none';
    this.vt = document.createElement('div'); this.vt.className = 'mv-vt'; this.vtiles = new Map(); // GM-015: Deutschland-Kacheln unter der Idstein-Textur
    this.ground.append(this.vt, this.img, this.detail); this.det = null;
    this.canvas = document.createElement('canvas'); this.canvas.className = 'mv-over';
    this.haze = document.createElement('div'); this.haze.className = 'mv-haze';
    el.append(this.ground, this.haze, this.canvas);
    this.cam = { center: [0, 0], heading: 0, scale: 0.5, tilt: 0, anchor: [0.5, 0.5] };
    this.tex = null;
  }
  setDetail(bitmap, region, S, style) {
    if (!bitmap) { this.det = null; this.detail.style.display = 'none'; return; }
    this.detail.width = bitmap.width; this.detail.height = bitmap.height;
    this.detail.getContext('2d').drawImage(bitmap, 0, 0);
    this.det = { region, S, style }; this.detail.style.display = 'block';
    this.detail.style.imageRendering = style === 'pixel' ? 'pixelated' : 'auto';
  }
  // GM-015: Kacheln anzeigen – list: [{ key, url, region, S, pixelated }] (grob zuerst, fein oben)
  setTiles(list) {
    const keep = new Set(list.map(t => t.key));
    for (const [k, el] of this.vtiles) if (!keep.has(k)) { el.remove(); this.vtiles.delete(k); }
    list.forEach((t, i) => {
      let el = this.vtiles.get(t.key);
      if (!el) {
        el = document.createElement('img'); el.className = 'mv-tex'; el.draggable = false; el.src = t.url; el._t = t; this.vtiles.set(t.key, el);
        if (t.pixelated) el.style.imageRendering = 'pixelated';
      }
      el.style.zIndex = i; if (el.parentNode !== this.vt) this.vt.append(el);
    });
  }
  setTexture(t, style) {
    if (this.det && this.det.style !== style) this.setDetail(null);
    this.tex = t; this.style = style;
    this.img.src = t.url; this.img.style.imageRendering = t.pixelated ? 'pixelated' : 'auto';
    this.el.style.background = STYLES[style].bg;
    const [r, g, b] = STYLES[style].haze;
    this.haze.style.background = `linear-gradient(rgb(${r},${g},${b}) 0%, rgba(${r},${g},${b},0) 100%)`;
  }
  size() { return [this.el.clientWidth, this.el.clientHeight]; }
  apply(cam) {
    Object.assign(this.cam, cam);
    const [W, H] = this.size(), c = this.cam, ax = c.anchor[0] * W, ay = c.anchor[1] * H;
    this.P = H * 1.25; this.W = W; this.H = H;
    this.el.style.perspective = this.P + 'px'; this.el.style.perspectiveOrigin = `${ax}px ${ay}px`;
    this.ground.style.transformOrigin = `${ax}px ${ay}px`; this.ground.style.transform = `rotateX(${c.tilt}deg)`;
    this.haze.style.height = c.tilt > 5 ? (H * 0.32) + 'px' : '0px';
    if (this.tex) {
      const S = this.tex.S, k = c.scale / S;
      this.img.style.width = (TEX.w * S) + 'px'; this.img.style.height = (TEX.h * S) + 'px';
      this.img.style.transform = `translate(${ax}px,${ay}px) rotate(${-c.heading}rad) scale(${k}) translate(${S * (TEX.x0 - c.center[0])}px,${S * (TEX.y0 - c.center[1])}px)`;
    }
    for (const el of this.vtiles.values()) {
      const { region: g, S: D } = el._t;
      el.style.width = (g.w * D) + 'px'; el.style.height = (g.h * D) + 'px';
      el.style.transform = `translate(${ax}px,${ay}px) rotate(${-c.heading}rad) scale(${c.scale / D}) translate(${D * (g.x0 - c.center[0])}px,${D * (g.y0 - c.center[1])}px)`;
    }
    if (this.det) {
      const { region: g, S: D } = this.det;
      this.detail.style.width = (g.w * D) + 'px'; this.detail.style.height = (g.h * D) + 'px';
      this.detail.style.transform = `translate(${ax}px,${ay}px) rotate(${-c.heading}rad) scale(${c.scale / D}) translate(${D * (g.x0 - c.center[0])}px,${D * (g.y0 - c.center[1])}px)`;
    }
    const dpr = window.devicePixelRatio || 1;
    if (this.canvas.width !== Math.round(W * dpr) || this.canvas.height !== Math.round(H * dpr)) { this.canvas.width = Math.round(W * dpr); this.canvas.height = Math.round(H * dpr); }
    const u = this.canvas.getContext('2d'); u.setTransform(dpr, 0, 0, dpr, 0, 0); u.clearRect(0, 0, W, H);
    return u;
  }
  // Welt (Meter) -> Bildschirm (CSS-px). Spiegelt CSS rotateX + perspective. k = Tiefenfaktor.
  project(p) {
    const c = this.cam, [W, H] = [this.W, this.H], ax = c.anchor[0] * W, ay = c.anchor[1] * H;
    const x = p[0] - c.center[0], y = p[1] - c.center[1], co = Math.cos(-c.heading), si = Math.sin(-c.heading);
    const rx = (x * co - y * si) * c.scale, ry = (x * si + y * co) * c.scale;
    if (!c.tilt) return [ax + rx, ay + ry, 1];
    const t = c.tilt * Math.PI / 180, den = this.P - ry * Math.sin(t);
    if (den < this.P * 0.15) return [0, 0, -1];
    const k = this.P / den;
    return [ax + rx * k, ay + ry * Math.cos(t) * k, k];
  }
  unproject(sx, sy) { // nur für flache Ansicht (Ziehen/Tippen)
    const c = this.cam, ax = c.anchor[0] * this.W, ay = c.anchor[1] * this.H, rx = (sx - ax) / c.scale, ry = (sy - ay) / c.scale;
    const co = Math.cos(c.heading), si = Math.sin(c.heading);
    return [c.center[0] + rx * co - ry * si, c.center[1] + rx * si + ry * co];
  }
  visible(q, m = 30) { return q[2] > 0 && q[0] > -m && q[0] < this.W + m && q[1] > (this.cam.tilt ? this.H * 0.14 : -m) && q[1] < this.H + m; }
}

// ------------------------------------------------------------------ Overlay-Zeichnen
export function drawRoute(u, mv, route, fromD, style, opts = {}) {
  if (!route) return;
  const S = STYLES[style], pts = [];
  const startI = fromD > 0 ? route.cum.findIndex(c => c >= fromD) : 0;
  if (fromD > 0) { const pa = interp(route, fromD); pts.push(mv.project(pa)); }
  for (let i = Math.max(0, startI); i < route.pts.length; i++) pts.push(mv.project(route.pts[i]));
  const base = opts.width ?? Math.max(6, Math.min(26, mv.cam.scale * 4.2));
  u.lineCap = 'round'; u.lineJoin = 'round';
  if (opts.alt) { strokeDepth(u, pts, base * 0.7, S.alt); return; }
  if (style === 'pixel') { // goldene Fußspuren
    let acc = 0;
    for (let i = 1; i < pts.length; i++) {
      const a = pts[i - 1], b = pts[i]; if (a[2] <= 0 || b[2] <= 0) continue;
      const L = Math.hypot(b[0] - a[0], b[1] - a[1]);
      for (let t = (6 - acc % 6) / Math.max(L, 0.001); t <= 1; t += 6 / Math.max(L, 0.001) * ((a[2] + b[2]) / 2)) {
        const x = a[0] + (b[0] - a[0]) * t, y = a[1] + (b[1] - a[1]) * t, s = Math.max(2, Math.round(3.4 * (a[2] + b[2]) / 2 * base / 9));
        u.fillStyle = S.routeEdge; u.fillRect(Math.round(x - s), Math.round(y - s), s * 2, s * 2);
        u.fillStyle = S.route; u.fillRect(Math.round(x - s) + 1, Math.round(y - s) + 1, s * 2 - 2, s * 2 - 2);
      }
      acc += L;
    }
    return;
  }
  strokeDepth(u, pts, base + (style === 'toy' ? 5 : 3), S.routeEdge);
  strokeDepth(u, pts, base, S.route);
  if (style === 'toy') { u.setLineDash([6, 8]); strokeDepth(u, pts, base * 0.18, '#fff'); u.setLineDash([]); }
}
function interp(route, d) {
  let i = route.cum.findIndex(c => c >= d); if (i <= 0) return route.pts[0];
  const a = route.pts[i - 1], b = route.pts[i], t = (d - route.cum[i - 1]) / ((route.cum[i] - route.cum[i - 1]) || 1);
  return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
}
function strokeDepth(u, pts, w, color) {
  u.strokeStyle = color;
  for (let i = 1; i < pts.length; i++) {
    const a = pts[i - 1], b = pts[i]; if (a[2] <= 0 || b[2] <= 0) continue;
    u.lineWidth = w * (a[2] + b[2]) / 2; u.beginPath(); u.moveTo(a[0], a[1]); u.lineTo(b[0], b[1]); u.stroke();
  }
}

const BLIP = { hospital: ['#ff5a5a', '+', 'hospital'], police: ['#6d8cff', 'star', 'police'], fuel: ['#f08a2c', 'fuel', 'fuel'], parking: ['#5fb6ff', 'P', 'parking'], fast_food: ['#7ee06a', 'food', 'food'], restaurant: ['#7ee06a', 'food', 'food'], cafe: ['#7ee06a', 'food', 'food'], supermarket: ['#f5d742', 'cart', 'shop'] };

// GM-012: Kartensymbole nach Vorlage – kleine Glyphen (24er-Raster), weiß oder farbig mit dunkler Kontur, eigene Zeichnung.
// Op-Listen: f = Fläche, l = Linie [Pfad, Breite], c = Aussparung in Konturfarbe, t = Text
const G = {
  car:   [['f', 'M2.5 16 L2.5 12.5 L6 11.3 L8.6 7.5 L15.6 7.5 L18.6 11.3 L21.5 12.5 L21.5 16 Z'], ['f', 'M4.6 16.5a2.4 2.4 0 1 0 4.8 0a2.4 2.4 0 1 0 -4.8 0 M14.6 16.5a2.4 2.4 0 1 0 4.8 0a2.4 2.4 0 1 0 -4.8 0'], ['c', 'M9.6 9 L14.6 9 L16.4 11.2 L7.9 11.2 Z']],
  wash:  [['f', 'M2.5 19 L2.5 16 L6 15 L8.2 12 L15.8 12 L18 15 L21.5 16 L21.5 19 Z'], ['f', 'M5 19.6a2 2 0 1 0 4 0a2 2 0 1 0 -4 0 M15 19.6a2 2 0 1 0 4 0a2 2 0 1 0 -4 0'], ['f', 'M6.5 2.5 Q4.6 5.6 6.5 7 Q8.4 5.6 6.5 2.5Z M12 1.5 Q10.1 4.6 12 6 Q13.9 4.6 12 1.5Z M17.5 2.5 Q15.6 5.6 17.5 7 Q19.4 5.6 17.5 2.5Z']],
  wrench:[['l', 'M5 19.5 L13.5 11', 3.8], ['f', 'M11.4 8.6a4.8 4.8 0 1 0 9.6 0a4.8 4.8 0 1 0 -9.6 0'], ['c', 'M15.2 7.4 L19.4 3.2 L21.8 5.6 L17.6 9.8 Z']],
  moto:  [['l', 'M2.6 16a3.4 3.4 0 1 0 6.8 0a3.4 3.4 0 1 0 -6.8 0 M14.6 16a3.4 3.4 0 1 0 6.8 0a3.4 3.4 0 1 0 -6.8 0', 2.1], ['l', 'M6 16 L9.5 11 L15.5 11 L18 16 M8.5 9.3 L13.5 9.3 M15.5 11 L16.8 7.6 L19.3 7.6', 2.4]],
  bike:  [['l', 'M2.2 16a3.8 3.8 0 1 0 7.6 0a3.8 3.8 0 1 0 -7.6 0 M14.2 16a3.8 3.8 0 1 0 7.6 0a3.8 3.8 0 1 0 -7.6 0', 1.8], ['l', 'M6 16 L9.6 10 L16 10 L18 16 M9.6 10 L12.4 16 L16 10 M8.4 8 L11 8 M16 10 L15.4 7.4 L17.6 7.4', 1.9]],
  fuel:  [['f', 'M4.5 3.5 h9.5 v17.5 h-9.5 Z'], ['c', 'M6.6 5.8 h5.3 v4.4 h-5.3 Z'], ['l', 'M14 8 L18.2 10.4 L18.2 18.2', 2.1]],
  basket:[['f', 'M2.5 10 h19 l-2.6 10.5 h-13.8 Z'], ['l', 'M7 9.5 L10 3.8 M17 9.5 L14 3.8', 2.1], ['c', 'M7.6 12.6h1.7v5.2h-1.7Z M11.15 12.6h1.7v5.2h-1.7Z M14.7 12.6h1.7v5.2h-1.7Z']],
  food:  [['l', 'M7.8 3 L7.8 21', 2.3], ['l', 'M5.2 3 L5.2 8 Q7.8 10.6 10.4 8 L10.4 3', 1.7], ['f', 'M14.8 21 L14.8 2.8 Q19.8 6 18.4 13.2 L16.9 13.2 L16.9 21 Z']],
  cup:   [['f', 'M3.5 7.5 h12.5 v6 a5.2 5.2 0 0 1 -5.2 5.2 h-2.1 a5.2 5.2 0 0 1 -5.2 -5.2 Z'], ['l', 'M16 9.6 h2.1 a2.5 2.5 0 0 1 0 5 h-2.1 M2.5 21.2 h16', 1.8]],
  cross: [['f', 'M9.4 2.8 h5.2 v6.6 h6.6 v5.2 h-6.6 v6.6 h-5.2 v-6.6 h-6.6 v-5.2 h6.6 Z']],
  shirt: [['f', 'M8 3 L4 5 L1.5 10 L5.2 11.6 L6.2 9.6 L6.2 21 L17.8 21 L17.8 9.6 L18.8 11.6 L22.5 10 L20 5 L16 3 Q12 6.2 8 3 Z']],
  scissors: [['l', 'M3.6 17.5a2.9 2.9 0 1 0 5.8 0a2.9 2.9 0 1 0 -5.8 0 M14.6 17.5a2.9 2.9 0 1 0 5.8 0a2.9 2.9 0 1 0 -5.8 0', 2], ['l', 'M8.4 15.3 L17.2 2.8 M15.6 15.3 L6.8 2.8', 2.3]],
  bed:   [['f', 'M1.8 18.5 V6.5 h2.6 v6.3 h17.8 v5.7 h-2.6 v-2.2 h-15.2 v2.2 Z'], ['f', 'M5.4 8.8 h5 v3.5 h-5Z M11.4 9.2 h8.4 a2.3 2.3 0 0 1 2.3 2.3 v1.3 h-10.7Z']],
  glass: [['f', 'M3.5 3.5 h17 l-7.2 8.4 v6.3 h4.2 v2.6 h-11 v-2.6 h4.2 v-6.3 Z']],
  star:  [['f', 'M12 2 L14.6 8.6 L21.6 8.9 L16.2 13.4 L18 20.3 L12 16.4 L6 20.3 L7.8 13.4 L2.4 8.9 L9.4 8.6 Z']],
  euro:  [['t', '€']],
  P:     [['t', 'P']],
};
// OSM-Art → [Glyphe, Füllung, Kontur]; Reihenfolge = Vorrang beim Platzieren (Auto-Themen zuerst)
const KINDS = {
  car: ['car', '#45d9e8', '#000'], car_repair: ['wrench', '#fff', '#000'], car_wash: ['wash', '#fff', '#000'], motorcycle: ['moto', '#fff', '#000'],
  fuel: ['fuel', '#fff', '#000'], parking: ['P', '#5fb6ff', '#000'], bicycle: ['bike', '#fff', '#000'], supermarket: ['basket', '#fff', '#000'],
  pharmacy: ['cross', '#52d273', '#000'], restaurant: ['food', '#fff', '#000'], fast_food: ['food', '#fff', '#000'], cafe: ['cup', '#fff', '#000'],
  bar: ['glass', '#7ee06a', '#000'], pub: ['glass', '#7ee06a', '#000'], clothes: ['shirt', '#000', '#fff'], hairdresser: ['scissors', '#fff', '#000'],
  hotel: ['bed', '#fff', '#000'], bank: ['euro', '#fff', '#000'], hospital: ['cross', '#ff5a5a', '#000'], police: ['star', '#6d8cff', '#000'],
};
const P2 = {}; const path = d => P2[d] || (P2[d] = new Path2D(d));
function drawGlyph(u, x, y, size, name, fill, edge) {
  const ops = G[name], k = size / 24, ew = 3.2;
  u.save(); u.translate(x - size / 2, y - size / 2); u.scale(k, k); u.lineCap = u.lineJoin = 'round';
  for (const pass of [0, 1]) for (const [t, d, w] of ops) {
    if (t === 't') { u.font = `800 21px Inter, sans-serif`; u.textAlign = 'center'; u.textBaseline = 'middle'; if (!pass) { u.lineWidth = ew * 1.3; u.strokeStyle = edge; u.strokeText(d, 12, 13); } else { u.fillStyle = fill; u.fillText(d, 12, 13); } continue; }
    const pp = path(d);
    if (!pass) { u.strokeStyle = edge; u.lineWidth = (t === 'l' ? w : 0) + ew; if (t !== 'c') { u.stroke(pp); if (t === 'f') { u.fillStyle = edge; u.fill(pp); } } continue; }
    if (t === 'f') { u.fillStyle = fill; u.fill(pp); } else if (t === 'l') { u.strokeStyle = fill; u.lineWidth = w; u.stroke(pp); } else { u.fillStyle = edge; u.fill(pp); }
  }
  u.restore();
}
// Symbole aus Kartenpunkten und Suchorten zusammenführen (Suchorte haben Autohäuser, Werkstätten, Apotheken …)
let blipCache = null;
function blipList(scene) {
  if (blipCache && blipCache.scene === scene && blipCache.v === scene.extraV) return blipCache.list;
  const order = Object.keys(KINDS), all = [...scene.pois, ...scene.search, ...(scene.extraPois || [])].filter(p => KINDS[p.kind]), list = []; // GM-015: + Orte aus Deutschland-Kacheln
  all.sort((a, b) => order.indexOf(a.kind) - order.indexOf(b.kind));
  for (const p of all) if (!list.some(o => o.kind === p.kind && Math.hypot(o.p[0] - p.p[0], o.p[1] - p.p[1]) < 30)) list.push(p);
  blipCache = { scene, list, v: scene.extraV }; return list;
}
export const LEGEND = [['car', 'Autohaus'], ['car_repair', 'Werkstatt'], ['car_wash', 'Waschanlage'], ['fuel', 'Tankstelle'], ['parking', 'Parken'], ['bicycle', 'Fahrradladen'], ['supermarket', 'Supermarkt'], ['pharmacy', 'Apotheke'], ['restaurant', 'Essen'], ['cafe', 'Café'], ['bar', 'Bar'], ['clothes', 'Kleidung'], ['hairdresser', 'Friseur'], ['hotel', 'Hotel'], ['bank', 'Bank'], ['hospital', 'Krankenhaus'], ['police', 'Polizei']];
export const LEGEND_KINDS = { restaurant: ['restaurant', 'fast_food'], bar: ['bar', 'pub'] };
const legendCache = {};
export function legendSrc(kind, size = 20) {
  if (legendCache[kind]) return legendCache[kind];
  const c = document.createElement('canvas'), dpr = 3; c.width = c.height = size * dpr;
  const u = c.getContext('2d'); u.scale(dpr, dpr); const [g, f, e] = KINDS[kind]; drawGlyph(u, size / 2, size / 2, size * 0.86, g, f, e);
  return (legendCache[kind] = c.toDataURL());
}

export function drawBlips(u, mv, scene, style, opts = {}) {
  const placed = [], near = mv.cam.scale > 0.45, glyphs = style === 'neon';
  const base = opts.size ?? (near ? Math.min(14, 7 + mv.cam.scale * 1.4) : 6.5);
  const hk = opts.highlight ? LEGEND_KINDS[opts.highlight] || [opts.highlight] : null; // GM-012: Legende hebt hervor
  for (const p of glyphs ? blipList(scene) : scene.pois) {
    const b = glyphs ? KINDS[p.kind] : BLIP[p.kind]; if (!b) continue;
    const hl = hk && (hk.includes(p.kind) || hk.includes(b[2]));
    if (near && (p.kind === 'restaurant' || p.kind === 'cafe' || p.kind === 'fast_food') && mv.cam.tilt && !hl) continue;
    if (mv.cam.scale < 0.04 && !hl) break; // GM-015: aus großer Höhe keine Ortssymbole
    if (glyphs && mv.cam.scale < 0.6 && !hl && (p.kind === 'restaurant' || p.kind === 'cafe' || p.kind === 'fast_food')) continue; // GM-010 (0.5): Übersicht ruhiger
    const q = mv.project(p.p); if (!mv.visible(q)) continue;
    const r = base * Math.max(0.7, Math.min(1.2, q[2]));
    if (opts.avoid && opts.avoid.some(a => q[0] + r > a[0] && q[0] - r < a[2] && q[1] + r > a[1] && q[1] - r < a[3])) continue; // GM-009 (1.2)
    if (placed.some(o => Math.hypot(o[0] - q[0], o[1] - q[1]) < r * 3.2)) continue;
    placed.push(q);
    if (hk && !hl) u.globalAlpha = 0.25;
    if (hl) { u.fillStyle = 'rgba(161,61,240,.45)'; u.beginPath(); u.arc(q[0], q[1], r * 2, 0, 7); u.fill(); }
    const rr = hl ? r * 1.35 : r;
    if (glyphs) drawGlyph(u, q[0], q[1], rr * 2.9, b[0], b[1], b[2]); else blip(u, q[0], q[1], rr, b, style);
    u.globalAlpha = 1;
  }
}
function blip(u, x, y, r, [color, g, file], style) {
  if (style === 'neon') { u.save(); u.translate(x, y); u.lineCap = 'round'; u.lineJoin = 'round'; u.fillStyle = '#f2f2f2'; u.strokeStyle = '#0c0c0d'; glyph(u, r, g, '#0c0c0d'); u.restore(); return; } // GM-010: weiß, dunkle Kontur
  const set = blipSet(style); if (set && set[file]) return drawAsset(u, set[file], x, y, r * 2.6, style === 'pixel');
  if (style === 'pixel') return sprite(u, SPR[g === 'P' ? 'P' : g], x, y, Math.max(2, Math.round(r / 3.4)));
  u.save(); u.translate(x, y); u.lineCap = 'round'; u.lineJoin = 'round';
  if (style === 'toy') { // runde Schilder wie auf dem Teppich
    u.fillStyle = '#fff'; u.beginPath(); u.arc(0, 0, r * 1.25, 0, 7); u.fill();
    u.fillStyle = g === 'P' ? '#1f6fe0' : color; u.beginPath(); u.arc(0, 0, r * 1.05, 0, 7); u.fill();
    u.fillStyle = u.strokeStyle = '#fff'; glyph(u, r * 0.8, g, null); u.restore(); return;
  }
  const edge = style === 'western' ? '#f2e4bf' : '#000';
  u.fillStyle = style === 'western' ? '#3a2414' : color; u.strokeStyle = edge; glyph(u, r, g, edge); u.restore();
}
function glyph(u, r, g, edge) {
  if (g === '+') { const a = r * 0.75, b = r * 0.26; u.beginPath(); u.rect(-b, -a, 2 * b, 2 * a); u.rect(-a, -b, 2 * a, 2 * b); if (edge) { u.lineWidth = r * 0.4; u.stroke(); } u.fill(); return; }
  if (g === 'star') { u.beginPath(); for (let i = 0; i < 10; i++) { const an = i * Math.PI / 5 - Math.PI / 2, rr = i % 2 ? r * 0.38 : r * 0.85; u.lineTo(Math.cos(an) * rr, Math.sin(an) * rr); } u.closePath(); if (edge) { u.lineWidth = r * 0.4; u.stroke(); } u.fill(); return; }
  if (g === 'P') { u.font = `800 ${r * 1.7}px Inter`; u.textAlign = 'center'; u.textBaseline = 'middle'; if (edge) { u.lineWidth = r * 0.3; u.strokeText(g, 0, r * 0.08); } u.fillText(g, 0, r * 0.08); return; }
  u.beginPath();
  if (g === 'fuel') { u.rect(-r * 0.6, -r * 0.75, r * 0.8, r * 1.5); u.moveTo(r * 0.2, -r * 0.35); u.lineTo(r * 0.65, -r * 0.1); u.lineTo(r * 0.65, r * 0.55); }
  else if (g === 'food') { u.moveTo(-r * 0.35, -r * 0.75); u.lineTo(-r * 0.35, r * 0.75); u.moveTo(-r * 0.65, -r * 0.75); u.lineTo(-r * 0.65, -r * 0.15); u.lineTo(-r * 0.05, -r * 0.15); u.lineTo(-r * 0.05, -r * 0.75); u.moveTo(r * 0.5, r * 0.75); u.lineTo(r * 0.5, -r * 0.75); u.quadraticCurveTo(r * 0.05, -r * 0.3, r * 0.5, 0); }
  else if (g === 'cart') { u.moveTo(-r * 0.8, -r * 0.55); u.lineTo(-r * 0.5, -r * 0.55); u.lineTo(-r * 0.25, r * 0.3); u.lineTo(r * 0.6, r * 0.3); u.lineTo(r * 0.8, -r * 0.3); u.lineTo(-r * 0.4, -r * 0.3); }
  const color = u.fillStyle;
  if (edge) { u.lineWidth = r * 0.55; u.strokeStyle = edge; u.stroke(); }
  if (g === 'fuel') u.fill(); else { u.lineWidth = r * 0.24; u.strokeStyle = color; u.stroke(); }
  if (g === 'cart') { u.beginPath(); u.arc(-r * 0.15, r * 0.65, r * 0.16, 0, 7); u.arc(r * 0.5, r * 0.65, r * 0.16, 0, 7); u.fill(); }
}

export function drawPlayer(u, mv, p, heading, style, size = 13) {
  const q = mv.project(p); if (q[2] <= 0) return;
  u.save(); u.translate(q[0], q[1]); u.rotate(heading - mv.cam.heading);
  if (mv.cam.tilt) u.scale(1, 0.85);
  const pl = A.ok && A.player[style]; // Codex: player-neon.svg / player-western.svg (Pixel: Pfeil nach Nutzervorlage, Toy: eigenes Auto)
  if (pl) { u.drawImage(pl, -size * 1.15, -size * 1.15, size * 2.3, size * 2.3); u.restore(); return; }
  if (style === 'pixel') { if (mv.cam.tilt) u.scale(1, 1 / 0.85); sprite(u, SPR.arrow, 0, 0, Math.max(2, Math.round(size / 4.5))); u.restore(); return; }
  if (style === 'toy') { // Spielzeugauto von oben
    const s = size / 13;
    u.scale(s, s); u.fillStyle = 'rgba(0,0,0,0.25)'; rr(u, -8, -12, 18, 26, 6); u.fill();
    u.fillStyle = '#e8372c'; u.strokeStyle = '#2f3640'; u.lineWidth = 1.4; rr(u, -9, -14, 18, 28, 6); u.fill(); u.stroke();
    u.fillStyle = '#bfe6ff'; rr(u, -6.5, -8, 13, 6, 2); u.fill(); u.stroke(); rr(u, -6.5, 5, 13, 5, 2); u.fill(); u.stroke();
    u.fillStyle = '#ffe066'; u.fillRect(-7, -14, 3, 2); u.fillRect(4, -14, 3, 2);
    u.restore(); return;
  }
  const fill = style === 'western' ? '#f6ead0' : '#e9e9e9', edge = style === 'western' ? '#3a2414' : '#000', pr = size;
  u.beginPath(); u.moveTo(0, -pr); u.lineTo(pr * 0.68, pr * 0.75); u.lineTo(0, pr * 0.38); u.lineTo(-pr * 0.68, pr * 0.75); u.closePath();
  u.lineWidth = pr * 0.22; u.strokeStyle = edge; u.lineJoin = 'round'; u.stroke(); u.fillStyle = fill; u.fill();
  u.restore();
}
function rr(u, x, y, w, h, r) { u.beginPath(); u.roundRect(x, y, w, h, r); }

export function drawDestination(u, mv, p, style, size = 8) {
  const q = mv.project(p); if (!mv.visible(q, 60)) return;
  const r = size * Math.max(0.8, Math.min(1.3, q[2]));
  const set = blipSet(style); if (set && set.destination) return drawAsset(u, set.destination, q[0], q[1] - (style === 'pixel' ? r : 0), r * 3.2, style === 'pixel');
  if (style === 'pixel') return sprite(u, SPR.chest, q[0], q[1] - r, Math.max(2, Math.round(r / 3)));
  if (style === 'western') {
    u.save(); u.translate(q[0], q[1]); u.lineCap = 'round';
    u.strokeStyle = '#f2e4bf'; u.lineWidth = r * 0.75; u.beginPath(); u.moveTo(-r, -r); u.lineTo(r, r); u.moveTo(r, -r); u.lineTo(-r, r); u.stroke();
    u.strokeStyle = '#c0261f'; u.lineWidth = r * 0.42; u.stroke(); u.restore(); return;
  }
  if (style === 'toy') { // Zielfahne
    u.save(); u.translate(q[0], q[1]); u.strokeStyle = '#2f3640'; u.lineWidth = 2; u.beginPath(); u.moveTo(0, 0); u.lineTo(0, -r * 3); u.stroke();
    for (let i = 0; i < 3; i++) for (let j = 0; j < 2; j++) { u.fillStyle = (i + j) % 2 ? '#fff' : '#2f3640'; u.fillRect(i * r * 0.6, -r * 3 + j * r * 0.6, r * 0.6, r * 0.6); }
    u.restore(); return;
  }
  u.fillStyle = '#000'; u.beginPath(); u.arc(q[0], q[1], r + 2.5, 0, 7); u.fill();
  u.fillStyle = '#f5d742'; u.beginPath(); u.arc(q[0], q[1], r, 0, 7); u.fill();
}

export function drawFriend(u, mv, p, name, style) {
  const q = mv.project(p); if (!mv.visible(q)) return;
  const set = blipSet(style);
  if (set && set.friend) drawAsset(u, set.friend, q[0], q[1], 22, style === 'pixel');
  else if (style === 'pixel') sprite(u, SPR.friend, q[0], q[1], 3);
  else { u.fillStyle = '#000'; u.beginPath(); u.arc(q[0], q[1], 8, 0, 7); u.fill(); u.fillStyle = '#ff4fd8'; u.beginPath(); u.arc(q[0], q[1], 6, 0, 7); u.fill(); }
  u.font = '700 11px Inter'; u.textAlign = 'center'; u.lineWidth = 3; u.strokeStyle = '#000'; u.strokeText(name, q[0], q[1] - 13); u.fillStyle = '#fff'; u.fillText(name, q[0], q[1] - 13);
}

export function drawFog(u, mv, scene, exploredLines) {
  u.save();
  u.fillStyle = 'rgba(12,12,14,0.84)'; u.fillRect(0, 0, mv.W, mv.H);
  u.globalCompositeOperation = 'destination-out'; u.lineCap = 'round'; u.lineJoin = 'round';
  for (const [w, a] of [[150, 0.3], [100, 0.6], [65, 1]]) {
    u.strokeStyle = `rgba(0,0,0,${a})`; u.lineWidth = w * mv.cam.scale;
    for (const pts of exploredLines) { u.beginPath(); pts.forEach((p, i) => { const q = mv.project(p); i ? u.lineTo(q[0], q[1]) : u.moveTo(q[0], q[1]); }); u.stroke(); }
  }
  u.restore();
}

// GM-010 (0.2): Straßen als Vektor in Bildschirm-Pixeln (bleiben beim Zoomen fein, Kreisel ohne dicken Ring)
const bbOf = l => l.bb ??= (() => { let a = Infinity, b = Infinity, c = -Infinity, d = -Infinity; for (const [x, y] of l.pts) { a = Math.min(a, x); b = Math.min(b, y); c = Math.max(c, x); d = Math.max(d, y); } return [a, b, c, d]; })();
let roadCache = null;
export function drawRoads(u, mv, scene) {
  roadCache ??= scene.lines.filter(l => l.k === 'road' && l.r <= 7).sort((a, b) => b.r - a.r);
  const c = mv.cam, R = Math.max(mv.W, mv.H) / c.scale * (c.tilt ? 2.2 : 0.8), zf = Math.max(1, Math.min(2.4, Math.sqrt(c.scale / 0.5)));
  u.lineCap = 'round'; u.lineJoin = 'round';
  for (const l of roadCache) {
    const [x0, y0, x1, y1] = bbOf(l);
    if (x1 < c.center[0] - R || x0 > c.center[0] + R || y1 < c.center[1] - R || y0 > c.center[1] + R) continue;
    if (c.scale < 0.25 && l.r >= 7) continue;
    u.strokeStyle = NEON_ROADS.color[l.r];
    let kSum = 0, n = 0; u.beginPath(); let started = false;
    for (const p of l.pts) { const q = mv.project(p); if (q[2] <= 0) { started = false; continue; } kSum += q[2]; n++; started ? u.lineTo(q[0], q[1]) : u.moveTo(q[0], q[1]); started = true; }
    if (!n) continue;
    u.lineWidth = NEON_ROADS.width[l.r] * zf * Math.min(2.5, kSum / n); u.stroke();
  }
}
