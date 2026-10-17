// GM-015: OpenMapTiles-Kachel → dieselbe Szene wie data/idstein.json (areas / lines / pois in Metern),
// damit alle vier Stile unverändert zeichnen können. Zuordnung wie in prep.py (area_kind, RANK).
import { decodeTile } from './mvt.js';
import { toLocal, x2lon, y2lat } from './geo.js';

const LAYERS = new Set(['water', 'waterway', 'landcover', 'landuse', 'park', 'building', 'transportation', 'poi']);
const ROAD = { motorway: 0, trunk: 1, primary: 2, secondary: 3, tertiary: 4, minor: 5, service: 7, track: 8, path: 9 };

function areaKind(layer, t) {
  if (layer === 'building') return 'building';
  if (layer === 'water') return t.class === 'swimming_pool' ? null : 'water';
  const c = t.class, s = t.subclass;
  if (layer === 'landcover') return c === 'wood' ? 'forest' : c === 'grass' ? 'park' : c === 'farmland' ? 'farm' : null;
  if (layer === 'park') return c === 'park' || s === 'park' ? 'park' : null;
  if (layer === 'landuse') {
    if (c === 'residential' || c === 'suburb' || c === 'neighbourhood') return 'residential';
    if (c === 'industrial' || c === 'commercial' || c === 'retail' || c === 'railway' || c === 'garages') return 'industrial';
    if (c === 'cemetery' || c === 'pitch' || c === 'playground' || c === 'park' || c === 'zoo') return 'park';
  }
  return null;
}
const signedArea = r => { let s = 0; for (let i = 0, j = r.length - 1; i < r.length; j = i++) s += (r[j][0] - r[i][0]) * (r[j][1] + r[i][1]); return s; };

export function tileScene(buf, z, x, y) {
  const layers = decodeTile(buf, LAYERS), areas = [], lines = [], pois = [];
  for (const [name, layer] of Object.entries(layers)) {
    const ext = layer.extent, toM = ([px, py]) => toLocal(y2lat(y + py / ext, z), x2lon(x + px / ext, z));
    for (const f of layer.features) {
      const t = f.tags;
      if (f.type === 3) {
        const k = areaKind(name, t); if (!k) continue;
        let outer = null;
        for (const r of f.rings) { // nur Außenringe (gleiche Drehrichtung wie der erste), Löcher fallen weg
          if (r.length < 4) continue;
          const a = signedArea(r); if (outer === null) outer = Math.sign(a);
          if (Math.sign(a) === outer) areas.push({ k, pts: r.map(toM) });
        }
      } else if (f.type === 2) {
        if (name === 'waterway') { for (const r of f.rings) lines.push({ k: 'water', c: t.class === 'river' || t.class === 'canal' ? 'river' : 'stream', pts: r.map(toM) }); continue; }
        if (name !== 'transportation') continue;
        if (t.class === 'rail' || t.class === 'transit') { for (const r of f.rings) lines.push({ k: 'rail', tunnel: t.brunnel === 'tunnel', pts: r.map(toM) }); continue; }
        let rk = ROAD[t.class]; if (rk === undefined) continue;
        if (t.ramp === 1 && rk <= 3) rk += 1;
        if (t.brunnel === 'tunnel') continue;
        for (const r of f.rings) lines.push({ k: 'road', c: t.class, r: rk, name: '', pts: r.map(toM) });
      } else if (f.type === 1 && name === 'poi') {
        const kind = t.subclass || t.class; if (!kind) continue;
        for (const r of f.rings) for (const p of r) if (p[0] >= 0 && p[0] < ext && p[1] >= 0 && p[1] < ext) pois.push({ p: toM(p), kind, name: t.name || '' });
      }
    }
  }
  return { areas, lines, pois, places: [] };
}
