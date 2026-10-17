// GM-015: Routing für ganz Deutschland über Valhalla (öffentlicher FOSSGIS-Server, OSM-Daten, nur für den Prototyp)
// und echte Tempolimits (OSM maxspeed) über trace_attributes. In der App: eigener Valhalla-Server oder Routing auf dem Gerät.
import { toLatLon, toLocal } from './geo.js';
import { pointAt } from './route.js';

const BASE = 'https://valhalla1.openstreetmap.de';
const post = async (path, body) => {
  const r = await fetch(BASE + path, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
  const j = await r.json(); if (!r.ok) throw new Error(j.error || r.status); return j;
};
function decode6(str) {
  const out = []; let i = 0, lat = 0, lon = 0;
  while (i < str.length) {
    for (const k of [0, 1]) {
      let s = 0, v = 0, b;
      do { b = str.charCodeAt(i++) - 63; v |= (b & 0x1f) << s; s += 5; } while (b >= 0x20);
      const d = v & 1 ? ~(v >> 1) : v >> 1; if (k === 0) lat += d; else lon += d;
    }
    out.push([lat / 1e6, lon / 1e6]);
  }
  return out;
}

// Valhalla-Manövertyp → unsere Pfeile und kurze Texte
const KIND = { 9: 'slight-right', 10: 'right', 11: 'sharp-right', 12: 'uturn-right', 13: 'uturn-left', 14: 'sharp-left', 15: 'left', 16: 'slight-left',
  18: 'slight-right', 19: 'slight-left', 20: 'slight-right', 21: 'slight-left', 23: 'slight-right', 24: 'slight-left', 26: 'right', 27: 'right' };
const TEXT = { 'slight-right': 'Leicht rechts halten', right: 'Rechts abbiegen', 'sharp-right': 'Scharf rechts abbiegen', 'uturn-right': 'Wenden', 'uturn-left': 'Wenden',
  'sharp-left': 'Scharf links abbiegen', left: 'Links abbiegen', 'slight-left': 'Leicht links halten' };

function toRoute(trip) {
  const leg = trip.legs[0], ll = decode6(leg.shape), pts = ll.map(([a, b]) => toLocal(a, b)), cum = [0];
  for (let i = 1; i < pts.length; i++) cum.push(cum[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]));
  const n = pts.length - 1, names = new Array(n).fill(''), speeds = new Array(n).fill(50), maneuvers = [];
  leg.maneuvers.forEach((m, mi) => {
    const nameOf = x => x && ((x.street_names || x.begin_street_names || [])[0] || x.sign?.exit_toward_elements?.[0]?.text) || '';
    const street = nameOf(m) || (m.type === 26 ? nameOf(leg.maneuvers[mi + 1]) : '');
    const kmh = m.time > 0 ? Math.min(130, Math.max(8, m.length * 3600 / m.time)) : 30;
    for (let i = m.begin_shape_index; i < Math.min(n, m.end_shape_index); i++) { names[i] = street; speeds[i] = kmh; }
    if (m.type >= 4 && m.type <= 6) { maneuvers.push({ at: cum[n], turn: 0, street: 'Ziel', kind: 'destination', text: 'Ziel erreicht' }); return; }
    const kind = KIND[m.type]; if (!kind) return;
    let text = TEXT[kind];
    if (m.type === 26) text = `Im Kreisverkehr ${m.roundabout_exit_count || 1}. Ausfahrt`;
    if (m.type === 27) return; // Ausfahrt aus dem Kreisverkehr steckt schon in der Einfahrt
    if (m.type === 20 || m.type === 21) text = `Ausfahrt ${m.sign?.exit_number_elements?.[0]?.text || ''}`.trim() + ' nehmen';
    if (m.type === 18 || m.type === 19) text = 'Auffahrt nehmen';
    maneuvers.push({ at: cum[m.begin_shape_index], turn: 0, street, kind, text }); // GM-016: kein Platzhalter „Straße“
  });
  if (!maneuvers.length || maneuvers[maneuvers.length - 1].kind !== 'destination') maneuvers.push({ at: cum[n], turn: 0, street: 'Ziel', kind: 'destination', text: 'Ziel erreicht' });
  return { pts, cum, length: cum[n], seconds: trip.summary.time, names, speeds, maneuvers, edges: [], ids: [], remote: true, limits: null };
}

export async function valhallaRoutes(from, to, opts = {}) {
  const [la0, lo0] = toLatLon(from), [la1, lo1] = toLatLon(to);
  const start = { lat: la0, lon: lo0 }; if (opts.heading != null) Object.assign(start, { heading: Math.round((opts.heading + 360) % 360), heading_tolerance: 45 });
  const body = {
    locations: [start, { lat: la1, lon: lo1 }], costing: 'auto',
    costing_options: { auto: { use_highways: opts.avoidHighway ? 0 : 1, use_tolls: opts.avoidToll ? 0 : 1 } },
    directions_options: { language: 'de-DE', units: 'kilometers' }, alternates: opts.alternates ?? 2,
  };
  if (opts.exclude) body.exclude_locations = opts.exclude.map(p => { const [lat, lon] = toLatLon(p); return { lat, lon }; });
  const j = await post('/route', body);
  return [j.trip, ...(j.alternates || []).map(a => a.trip)].filter(Boolean).map(toRoute);
}

// Echte Tempolimits je Teilstück (für die ersten ~150 km, Rest bleibt geschätzt). 0 = unbekannt, -1 = unbegrenzt.
export async function speedLimits(route) {
  const step = Math.max(1, Math.round(15 / Math.max(1, route.length / route.pts.length))); // etwa alle 15 m ein Punkt
  const idx = []; for (let i = 0; i < route.pts.length && route.cum[i] < 150000; i += step) idx.push(i);
  const shape = idx.map(i => { const [lat, lon] = toLatLon(route.pts[i]); return { lat, lon }; });
  const j = await post('/trace_attributes', { shape, costing: 'auto', shape_match: 'map_snap', filters: { attributes: ['edge.speed_limit', 'matched.edge_index'], action: 'include' } });
  const lim = new Array(route.pts.length - 1).fill(0);
  j.matched_points.forEach((mp, k) => {
    const e = j.edges[mp.edge_index]; if (!e) return;
    const v = e.speed_limit === 'unlimited' ? -1 : +e.speed_limit || 0;
    for (let i = idx[k]; i < (idx[k + 1] ?? route.pts.length - 1); i++) lim[i] = v;
  });
  return lim;
}
export const segIndex = (route, d) => Math.max(0, pointAt(route.pts, route.cum, d).i - 1);
