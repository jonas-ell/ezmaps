// Zeichnet Kacheln im Hintergrund (blockiert die Oberfläche nicht).
// 'tile': scharfe Detail-Kachel aus der Idstein-Szene (GM-006). 'vtile': Vektorkachel aus dem Netz für ganz Deutschland (GM-015).
import { renderRegion } from './map.js';
import { tileScene } from './vtscene.js';
import { tileRegion } from './geo.js';
let scene = null;
const cache = new Map(); // z/x/y → Szene (zuletzt benutzte zuerst raus)
async function vscene(url, z, x, y) {
  const k = `${z}/${x}/${y}`;
  if (cache.has(k)) { const v = cache.get(k); cache.delete(k); cache.set(k, v); return v; }
  const res = await fetch(url.replace('{z}', z).replace('{x}', x).replace('{y}', y));
  const sc = res.ok ? tileScene(await res.arrayBuffer(), z, x, y) : { areas: [], lines: [], pois: [], places: [] };
  cache.set(k, sc); if (cache.size > 40) cache.delete(cache.keys().next().value);
  return sc;
}
self.onmessage = async e => {
  const m = e.data;
  if (m.type === 'scene') { scene = m.scene; return; }
  if (m.type === 'tile' && scene) {
    const c = renderRegion(scene, m.style, m.region, m.S);
    const bitmap = c.transferToImageBitmap();
    self.postMessage({ id: m.id, style: m.style, region: m.region, S: m.S, bitmap }, [bitmap]);
  }
  if (m.type === 'vtile') {
    try {
      const sc = await vscene(m.url, m.z, m.x, m.y), region = tileRegion(m.z, m.x, m.y, m.div, m.sx, m.sy);
      const c = renderRegion(sc, m.style, region, m.S);
      const blob = await c.convertToBlob(m.style === 'pixel' ? { type: 'image/png' } : { type: 'image/jpeg', quality: 0.88 }); // als Bild: wenig Speicher, beide Ansichten teilen es
      self.postMessage({ type: 'vtile', key: m.key, style: m.style, region, S: m.S, blob, pois: m.div === 1 && m.z >= 14 ? sc.pois : [] });
    } catch (err) { self.postMessage({ type: 'vtile', key: m.key, style: m.style, error: String(err) }); }
  }
};
