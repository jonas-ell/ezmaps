// GM-016: Kachel-Arbeit als gemeinsames Modul – läuft im Worker (OffscreenCanvas) oder, wenn der Browser
// dort kein OffscreenCanvas kennt (ältere WebKit-Builds), auf dem Haupt-Thread mit normalem Canvas.
import { renderRegion } from './map.js';
import { tileScene } from './vtscene.js';
import { tileRegion } from './geo.js';

const cache = new Map(); // z/x/y → Szene (zuletzt benutzte zuerst raus)
async function vscene(url, z, x, y) {
  const k = `${z}/${x}/${y}`;
  if (cache.has(k)) { const v = cache.get(k); cache.delete(k); cache.set(k, v); return v; }
  const res = await fetch(url.replace('{z}', z).replace('{x}', x).replace('{y}', y));
  const sc = res.ok ? tileScene(await res.arrayBuffer(), z, x, y) : { areas: [], lines: [], pois: [], places: [] };
  cache.set(k, sc); if (cache.size > 40) cache.delete(cache.keys().next().value);
  return sc;
}
const toBlob = (c, type, quality) => c.convertToBlob ? c.convertToBlob({ type, quality }) : new Promise(r => c.toBlob(r, type, quality));
const toBitmap = c => c.transferToImageBitmap ? c.transferToImageBitmap() : createImageBitmap(c);

export async function runTile(m, scene) {
  // GM-023: Pixel Quest im Kunstpixel-Raster zeichnen und dann ohne Glättung hochrechnen – sonst wird es
  // durch die geneigte Kamera (CSS-3D, immer bilinear) unscharf. 1 Kunstpixel = 1,6 m wie die Grobkarte.
  const pixel = m.style === 'pixel', S = pixel ? 0.625 : m.S;
  let c = renderRegion(scene, m.style, m.region, S), outS = S;
  if (pixel) {
    const k = 6, big = typeof OffscreenCanvas !== 'undefined' ? new OffscreenCanvas(c.width * k, c.height * k) : Object.assign(document.createElement('canvas'), { width: c.width * k, height: c.height * k });
    const g = big.getContext('2d'); g.imageSmoothingEnabled = false; g.drawImage(c, 0, 0, big.width, big.height);
    c = big; outS = S * k;
  }
  const bitmap = await toBitmap(c);
  return { msg: { id: m.id, style: m.style, region: m.region, S: outS, bitmap }, transfer: [bitmap] };
}
export async function runVtile(m) {
  try {
    const sc = await vscene(m.url, m.z, m.x, m.y), region = tileRegion(m.z, m.x, m.y, m.div, m.sx, m.sy);
    const c = renderRegion(sc, m.style, region, m.S);
    const blob = await toBlob(c, m.style === 'pixel' ? 'image/png' : 'image/jpeg', 0.88); // als Bild: wenig Speicher, beide Ansichten teilen es
    return { type: 'vtile', key: m.key, style: m.style, region, S: m.S, blob, pois: m.div === 1 && m.z >= 14 ? sc.pois : [] };
  } catch (err) { return { type: 'vtile', key: m.key, style: m.style, error: String(err) }; }
}
