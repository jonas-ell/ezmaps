// GM-015: Karte für ganz Deutschland – Vektorkacheln von OpenFreeMap (OSM-Daten, OpenMapTiles-Schema, frei, ohne Schlüssel)
// nachladen und in unseren eigenen Stilen zeichnen. In der App übernimmt das MapLibre mit eigenen Kacheln (siehe docs/KARTENDATEN.md).
import { toLatLon, lon2x, lat2y, tileRegion, tileMeters } from './geo.js';
import { TEX } from './map.js';

const TILEJSON = 'https://tiles.openfreemap.org/planet';
const MAX_JOBS = 3, MAX_CACHE = 140, PER_VIEW = 36;
let app, url = null, workers = [], busy = 0, lastRun = 0;
const queue = [], pending = new Set(), cache = new Map(), poiTiles = new Map();
let mainThread = false; // GM-016: true, wenn der Worker kein OffscreenCanvas hat
const INNER = { x0: TEX.x0 + 300, y0: TEX.y0 + 300, x1: TEX.x0 + TEX.w - 300, y1: TEX.y0 + TEX.h - 300 }; // dort zeichnet die Idstein-Textur

export async function initTiles(a) {
  app = a;
  try { url = (await (await fetch(TILEJSON)).json()).tiles[0]; } catch { url = null; console.warn('Kacheln nicht erreichbar – nur Idstein'); return; }
  for (let i = 0; i < MAX_JOBS; i++) {
    const w = new Worker('js/tileworker.js', { type: 'module' });
    w.onmessage = e => done(e.data); workers.push(w);
  }
}

// Welche Kacheln braucht eine Ansicht? Feinheit S (px/m) in Zweierpotenzen, Zoomstufe so, dass eine Kachel ~1000 px groß wird.
function wanted(view, style) {
  const c = view.cam, [W, H] = view.size(); if (!W || !c.center) return [];
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  const S = Math.min(4, 2 ** Math.ceil(Math.log2(c.scale * dpr * 0.9)));
  const ahead = c.tilt ? 0.5 : 0, rr = Math.hypot(W, H) / 2 / c.scale * (c.tilt ? 1.5 : 1.05);
  const cx = c.center[0] + Math.sin(c.heading) * rr * ahead, cy = c.center[1] - Math.cos(c.heading) * rr * ahead;
  const [lat] = toLatLon([cx, cy]);
  let z = Math.round(Math.log2(40075016 * Math.cos(lat * Math.PI / 180) * S / 1024)), div = 1;
  if (z > 14) { div = 2 ** Math.min(2, z - 14); z = 14; }
  z = Math.max(3, z);
  const n = 2 ** z * div, [la0, lo0] = toLatLon([cx - rr, cy - rr]), [la1, lo1] = toLatLon([cx + rr, cy + rr]);
  const fx0 = Math.floor(lon2x(lo0, z) * div), fx1 = Math.floor(lon2x(lo1, z) * div), fy0 = Math.floor(lat2y(la0, z) * div), fy1 = Math.floor(lat2y(la1, z) * div);
  const out = [];
  for (let fx = Math.max(0, fx0); fx <= Math.min(n - 1, fx1); fx++) for (let fy = Math.max(0, fy0); fy <= Math.min(n - 1, fy1); fy++) {
    const x = Math.floor(fx / div), y = Math.floor(fy / div), sx = fx % div, sy = fy % div, g = tileRegion(z, x, y, div, sx, sy);
    if (g.x0 >= INNER.x0 && g.y0 >= INNER.y0 && g.x0 + g.w <= INNER.x1 && g.y0 + g.h <= INNER.y1) continue;
    const d = Math.hypot(g.x0 + g.w / 2 - cx, g.y0 + g.h / 2 - cy);
    out.push({ key: `${style}/${z}/${x}/${y}/${div}/${sx}/${sy}/${S}`, z, x, y, div, sx, sy, S, style, g, d });
  }
  return out.sort((a, b) => a.d - b.d).slice(0, PER_VIEW).map(t => ({ ...t, view: [cx, cy, rr] }));
}

export function updateTiles(now) {
  if (!url || now - lastRun < 200) return; lastRun = now;
  const style = app.state.style, need = [];
  for (const v of Object.values(app.views)) need.push(...wanted(v, style));
  for (const t of need) if (!cache.has(t.key) && !pending.has(t.key) && !queue.some(q => q.key === t.key)) queue.push(t);
  // Warteschlange: nur was noch gebraucht wird, nächstgelegene zuerst
  const needKeys = new Set(need.map(t => t.key));
  for (let i = queue.length - 1; i >= 0; i--) if (!needKeys.has(queue[i].key)) queue.splice(i, 1);
  queue.sort((a, b) => a.d - b.d);
  while (busy < MAX_JOBS && queue.length) {
    const t = queue.shift(); pending.add(t.key); busy++;
    const job = { type: 'vtile', url, key: t.key, z: t.z, x: t.x, y: t.y, div: t.div, sx: t.sx, sy: t.sy, S: t.S, style: t.style };
    if (mainThread) import('./tilejob.js').then(j => j.runVtile(job)).then(done); else workers[busy % MAX_JOBS].postMessage(job);
  }
  // Anzeige: alle fertigen Kacheln des Stils im Blickfeld, grobe unten (füllen Lücken, solange feine laden)
  for (const v of Object.values(app.views)) {
    const w = wanted(v, style)[0]; if (!w) { v.setTiles([]); continue; }
    const [cx, cy, rr] = w.view, list = [];
    for (const e of cache.values()) {
      if (e.style !== style) continue;
      const g = e.region; if (g.x0 > cx + rr || g.x0 + g.w < cx - rr || g.y0 > cy + rr || g.y0 + g.h < cy - rr) continue;
      if (e.S < w.S / 8) continue; // viel zu grob – nicht mehr zeigen
      list.push(e);
    }
    v.setTiles(list.sort((a, b) => a.S - b.S).slice(-60));
  }
}

function done(m) {
  busy = Math.max(0, busy - 1); pending.delete(m.key);
  if (m.nooffscreen) { mainThread = true; lastRun = 0; return; } // Haupt-Thread übernimmt, Kachel wird neu angefordert
  if (m.error || !m.blob) { if (m.error) console.warn('Kachel', m.key, m.error); return; }
  cache.set(m.key, { key: m.key, style: m.style, region: m.region, S: m.S, url: URL.createObjectURL(m.blob), pixelated: m.style === 'pixel' });
  if (m.pois && m.pois.length) {
    const k = m.key.split('/').slice(1, 4).join('/');
    if (!poiTiles.has(k)) {
      poiTiles.set(k, m.pois.filter(p => !(p.p[0] > TEX.x0 && p.p[0] < TEX.x0 + TEX.w && p.p[1] > TEX.y0 && p.p[1] < TEX.y0 + TEX.h)));
      app.scene.extraPois = [...poiTiles.values()].flat(); app.scene.extraV = (app.scene.extraV || 0) + 1;
    }
  }
  while (cache.size > MAX_CACHE) { const [k, e] = cache.entries().next().value; URL.revokeObjectURL(e.url); cache.delete(k); }
  lastRun = 0;
}
export const tilesReady = () => !!url;
