// Routing im Browser: Dijkstra über den OSM-Straßengraphen, Abbiegehinweise, Ankunftszeit.
// Spiegel der späteren Swift-Logik in Core/ (RoutePlanner) – bei Änderungen beide anpassen.

export class Router {
  constructor(graph) {
    this.nodes = graph.nodes;
    this.names = graph.names;
    this.adj = this.nodes.map(() => []);
    for (const [a, b, len, speed, name, oneway, rank] of graph.edges) {
      this.adj[a].push({ to: b, len, speed, name, rank });
      if (!oneway) this.adj[b].push({ to: a, len, speed, name, rank });
    }
  }

  nearest(p) {
    let best = -1, bd = Infinity;
    for (let i = 0; i < this.nodes.length; i++) {
      if (!this.adj[i].length || this.adj[i].every(e => e.rank >= 6)) continue; // GM-005: nicht auf Zufahrten/Spielstraßen starten
      const d = (this.nodes[i][0] - p[0]) ** 2 + (this.nodes[i][1] - p[1]) ** 2;
      if (d < bd) { bd = d; best = i; }
    }
    return best;
  }

  // mode: 'fast' (Zeit), 'short' (Strecke), 'explore' (unentdeckte Straßen bevorzugen)
  route(from, to, mode = 'fast', explored = null) {
    const s = this.nearest(from), t = this.nearest(to);
    const n = this.nodes.length, dist = new Float64Array(n).fill(Infinity), prev = new Int32Array(n).fill(-1), via = new Array(n);
    const heap = new MinHeap();
    dist[s] = 0; heap.push(0, s);
    while (heap.size) {
      const [d, u] = heap.pop();
      if (u === t) break;
      if (d > dist[u]) continue;
      for (const e of this.adj[u]) {
        let w = mode === 'short' ? e.len : e.len / e.speed * 3.6;
        if (mode === 'explore' && explored && !explored.has(edgeKey(u, e.to))) w *= 0.6;
        const nd = d + w;
        if (nd < dist[e.to]) { dist[e.to] = nd; prev[e.to] = u; via[e.to] = e; heap.push(nd, e.to); }
      }
    }
    if (prev[t] === -1 && s !== t) return null;
    const ids = [t], segs = [];
    while (ids[ids.length - 1] !== s) { const v = ids[ids.length - 1]; segs.push(via[v]); ids.push(prev[v]); }
    ids.reverse(); segs.reverse();
    return this.describe(ids, segs);
  }

  describe(ids, segs) {
    const pts = ids.map(i => this.nodes[i]);
    const cum = [0];
    for (let i = 1; i < pts.length; i++) cum.push(cum[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]));
    const length = cum[cum.length - 1];
    const seconds = segs.reduce((s, e) => s + e.len / e.speed * 3.6, 0);
    const names = segs.map(e => this.names[e.name] || '');
    const at = d => pointAt(pts, cum, d).p;
    const maneuvers = [];
    for (let i = 1; i < pts.length - 1; i++) {
      if (names[i - 1] === names[i] && !(segs[i - 1].rank <= 1) ) continue;
      const d = cum[i];
      const turn = norm(bearing(pts[i], at(d + 25)) - bearing(at(d - 25), pts[i]));
      if (Math.abs(turn) < 30) continue;
      if (maneuvers.length && d - maneuvers[maneuvers.length - 1].at < 30) maneuvers.pop();
      maneuvers.push({ at: d, turn, street: names[i] || names[Math.min(i + 1, names.length - 1)] || 'Straße', ...turnText(turn) });
    }
    maneuvers.push({ at: length, turn: 0, street: 'Ziel', kind: 'destination', text: 'Ziel erreicht' });
    return { ids, pts, cum, length, seconds, names, maneuvers, speeds: segs.map(e => e.speed), edges: ids.slice(1).map((v, i) => edgeKey(ids[i], v)) };
  }
}

export const edgeKey = (a, b) => a < b ? a * 100000 + b : b * 100000 + a;

export function pointAt(pts, cum, d) {
  d = Math.max(0, Math.min(cum[cum.length - 1], d));
  let lo = 1, hi = pts.length - 1;
  while (lo < hi) { const m = (lo + hi) >> 1; if (cum[m] < d) lo = m + 1; else hi = m; }
  const i = lo, a = pts[i - 1], b = pts[i], l = (cum[i] - cum[i - 1]) || 1, t = (d - cum[i - 1]) / l;
  return { p: [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t], i, heading: Math.atan2(b[0] - a[0], -(b[1] - a[1])) };
}
export function smoothHeading(r, d) {
  const a = pointAt(r.pts, r.cum, d).p, b = pointAt(r.pts, r.cum, d + 40).p;
  return Math.atan2(b[0] - a[0], -(b[1] - a[1]));
}
const bearing = (a, b) => Math.atan2(b[0] - a[0], -(b[1] - a[1])) * 180 / Math.PI;
const norm = a => ((a + 540) % 360) - 180;

function turnText(turn) {
  const side = turn < 0 ? 'links' : 'rechts', a = Math.abs(turn);
  if (a > 150) return { kind: turn < 0 ? 'uturn-left' : 'uturn-right', text: 'Wenden' };
  if (a > 110) return { kind: `sharp-${turn < 0 ? 'left' : 'right'}`, text: `Scharf ${side} abbiegen` };
  if (a > 55) return { kind: turn < 0 ? 'left' : 'right', text: `${side[0].toUpperCase() + side.slice(1)} abbiegen` };
  return { kind: `slight-${turn < 0 ? 'left' : 'right'}`, text: `Leicht ${side} halten` };
}

export function fmtDist(m) {
  if (m >= 1000) return (m / 1000).toFixed(m >= 10000 ? 0 : 1).replace('.', ',') + ' km';
  if (m >= 100) return Math.round(m / 50) * 50 + ' m';
  return Math.max(0, Math.round(m / 10) * 10) + ' m';
}
export const fmtMin = s => Math.max(1, Math.round(s / 60)) + ' Min';

class MinHeap {
  constructor() { this.k = []; this.v = []; }
  get size() { return this.k.length; }
  push(k, v) {
    const a = this.k, b = this.v; let i = a.length; a.push(k); b.push(v);
    while (i > 0) { const p = (i - 1) >> 1; if (a[p] <= k) break; a[i] = a[p]; b[i] = b[p]; i = p; }
    a[i] = k; b[i] = v;
  }
  pop() {
    const a = this.k, b = this.v, top = [a[0], b[0]], k = a.pop(), v = b.pop();
    if (a.length) {
      let i = 0; const n = a.length;
      while (true) {
        let c = 2 * i + 1; if (c >= n) break;
        if (c + 1 < n && a[c + 1] < a[c]) c++;
        if (a[c] >= k) break;
        a[i] = a[c]; b[i] = b[c]; i = c;
      }
      a[i] = k; b[i] = v;
    }
    return top;
  }
}
