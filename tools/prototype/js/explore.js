// GM-041: „Stadt aufdecken“ – Straßenzellen (Kacheln Zoom 20, ~24 m in Deutschland).
// Mirror of Core/Sources/EzMapsCore/Exploration.swift – change both.
const Z = 20, N = 2 ** Z;

export function cellKey(lat, lon) {
  const la = Math.max(-85.0511, Math.min(85.0511, lat)) * Math.PI / 180;
  const x = Math.max(0, Math.min(N - 1, Math.floor((lon + 180) / 360 * N)));
  const y = Math.max(0, Math.min(N - 1, Math.floor((1 - Math.log(Math.tan(la) + 1 / Math.cos(la)) / Math.PI) / 2 * N)));
  return x * N + y;
}

export function cellCenter(k) {
  const x = Math.floor(k / N) + 0.5, y = (k % N) + 0.5;
  return [Math.atan(Math.sinh(Math.PI * (1 - 2 * y / N))) * 180 / Math.PI, x / N * 360 - 180];
}

const dist = ([a, b], [c, d]) => {
  const r = 6371000, p = Math.PI / 180, dLa = (c - a) * p, dLo = (d - b) * p;
  const h = Math.sin(dLa / 2) ** 2 + Math.cos(a * p) * Math.cos(c * p) * Math.sin(dLo / 2) ** 2;
  return 2 * r * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
};

/** Zellen entlang [[lat, lon], …]; Sprünge über maxGap (Tunnel, GPS-Lücke) werden nicht aufgefüllt */
export function cellsAlong(line, step = 8, maxGap = 400) {
  if (!line.length) return [];
  const out = [], seen = new Set();
  const add = (la, lo) => { const k = cellKey(la, lo); if (!seen.has(k)) { seen.add(k); out.push(k); } };
  add(...line[0]);
  for (let i = 1; i < line.length; i++) {
    const a = line[i - 1], b = line[i], d = dist(a, b);
    if (d > maxGap) { add(...b); continue; }
    const n = Math.max(1, Math.ceil(d / step));
    for (let j = 1; j <= n; j++) { const t = j / n; add(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t); }
  }
  return out;
}

export const LEVELS = [[0, 'Neu hier'], [0.10, 'Unterwegs'], [0.25, 'Kenner'], [0.50, 'Insider'], [0.75, 'Legende']];
export function levelFor(share) {
  let i = 0; LEVELS.forEach(([t], j) => { if (share >= t) i = j; });
  return { number: i + 1, title: LEVELS[i][1], next: LEVELS[i + 1]?.[0] ?? null };
}

export class Exploration {
  constructor() { this.driven = new Set(); this.totalMeters = 0; this.trips = 0; }
  /** Fahrt eintragen, gibt { newCells, totalCells, newPercent } zurück */
  addTrip(track) {
    const cells = cellsAlong(track), fresh = cells.filter(k => !this.driven.has(k));
    cells.forEach(k => this.driven.add(k));
    for (let i = 1; i < track.length; i++) this.totalMeters += Math.min(dist(track[i - 1], track[i]), 400);
    if (cells.length > 1) this.trips++;
    return { newCells: fresh, totalCells: cells.length, newPercent: cells.length ? Math.round(fresh.length / cells.length * 100) : 0 };
  }
  newShare(route) { const c = cellsAlong(route); return c.length ? c.filter(k => !this.driven.has(k)).length / c.length : 0; }
  share(roadCells) { if (!roadCells.size) return 0; let n = 0; for (const k of roadCells) if (this.driven.has(k)) n++; return n / roadCells.size; }
}
