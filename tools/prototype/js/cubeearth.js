// GM-090: Würfel-Erde für Pixel Quest (ganz rausgezoomt). Mirror von Core/Sources/EzMapsCore/CubeEarth.swift – change both.
(function () {
  const M = window.LANDMASK;
  const bits = Uint8Array.from(atob(M.base64), c => c.charCodeAt(0));
  function isLand(lat, lon) {
    const x = Math.floor((lon + 180) / 360 * M.width);
    let y = Math.floor((90 - lat) / 180 * M.height);
    y = y < 0 ? 0 : y >= M.height ? M.height - 1 : y;
    const i = y * M.width + (((x % M.width) + M.width) % M.width);
    return (bits[i >> 3] & (0x80 >> (i & 7))) !== 0;
  }
  // Seiten wie SCNBox: vorn, rechts, hinten, links, oben, unten – [Normale, rechts, unten]
  const BASIS = [
    [[0, 0, 1], [1, 0, 0], [0, -1, 0]], [[1, 0, 0], [0, 0, -1], [0, -1, 0]], [[0, 0, -1], [-1, 0, 0], [0, -1, 0]],
    [[-1, 0, 0], [0, 0, 1], [0, -1, 0]], [[0, 1, 0], [1, 0, 0], [0, 0, 1]], [[0, -1, 0], [1, 0, 0], [0, 0, -1]],
  ];
  const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
  const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
  const mul = (a, s) => [a[0] * s, a[1] * s, a[2] * s];
  const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  const point = (f, u, v) => add(add(BASIS[f][0], mul(BASIS[f][1], u)), mul(BASIS[f][2], v));
  function coordinate(p) {
    const len = Math.hypot(p[0], p[1], p[2]);
    return { lat: Math.asin(Math.max(-1, Math.min(1, p[1] / len))) * 180 / Math.PI, lon: Math.atan2(p[0], p[2]) * 180 / Math.PI };
  }
  const landAt = p => { const c = coordinate(p); return isLand(c.lat, c.lon); };
  const B = { deepWater: 0, water: 1, ice: 2, sand: 3, grass: 4, forest: 5, snow: 6 };
  const COLOR = [[0.11, 0.17, 0.60], [0.16, 0.25, 0.80], [0.72, 0.86, 0.96], [0.87, 0.80, 0.54], [0.36, 0.61, 0.22], [0.20, 0.44, 0.15], [0.95, 0.97, 1.0]];
  const DIRT = [0.47, 0.33, 0.20];
  const raisedB = b => b >= B.sand;
  const scaled = (c, s) => c.map(x => Math.min(1, x * s));
  function hash(a, b, c) {
    let h = (Math.imul(a, 374761393) + Math.imul(b, 668265263) + Math.imul(c, 1274126177)) >>> 0;
    h = Math.imul(h ^ (h >>> 13), 1274126177) >>> 0;
    h = (h ^ (h >>> 16)) >>> 0;
    return h / 4294967295;
  }
  function blocks(n) {
    const step = 2 / n, out = [];
    for (let f = 0; f < 6; f++) {
      const g = [];
      for (let row = 0; row < n; row++) for (let col = 0; col < n; col++) {
        const u = -1 + (col + 0.5) * step, v = -1 + (row + 0.5) * step;
        const lat = Math.abs(coordinate(point(f, u, v)).lat);
        let hits = 0;
        for (const a of [-0.33, 0, 0.33]) for (const b of [-0.33, 0, 0.33]) if (landAt(point(f, u + a * step, v + b * step))) hits++;
        const near = [[1, 0], [-1, 0], [0, 1], [0, -1]].map(([a, b]) => landAt(point(f, u + a * step, v + b * step)));
        if (hits >= 5) g.push(lat > 62 ? B.snow : near.filter(x => !x).length >= 2 ? B.sand : lat > 50 ? B.forest : B.grass);
        else if (lat > 74) g.push(B.ice);
        else {
          const far = [[2.5, 0], [-2.5, 0], [0, 2.5], [0, -2.5]].every(([a, b]) => !landAt(point(f, u + a * step, v + b * step)));
          g.push(near.includes(true) || !far ? B.water : B.deepWater);
        }
      }
      out.push(g);
    }
    return out;
  }
  function newMesh() { return { positions: [], normals: [], colors: [], indices: [] }; }
  function quad(m, a, b, c, d, normal, color) {
    const pts = dot(cross(sub(b, a), sub(c, a)), normal) >= 0 ? [a, b, c, d] : [a, d, c, b];
    const base = m.positions.length / 3;
    for (const p of pts) { m.positions.push(...p); m.normals.push(...normal); m.colors.push(...color); }
    m.indices.push(base, base + 1, base + 2, base, base + 2, base + 3);
  }
  function mesh(n, bl) {
    const m = newMesh(), t = 2 / n, SUB = 2;
    for (let f = 0; f < 6; f++) {
      const [nv, r, d] = BASIS[f], grid = bl[f];
      const raised = (col, row) => col >= 0 && col < n && row >= 0 && row < n && raisedB(grid[row * n + col]);
      const at = (u, v, h) => add(add(mul(nv, 1 + h * t), mul(r, u)), mul(d, v));
      for (let row = 0; row < n; row++) for (let col = 0; col < n; col++) {
        const b = grid[row * n + col], h = raisedB(b) ? 1 : 0;
        const u0 = -1 + col * t, v0 = -1 + row * t, base = COLOR[b], s = t / SUB;
        for (let j = 0; j < SUB; j++) for (let i = 0; i < SUB; i++) {
          const shade = 0.9 + 0.2 * hash(f * 7 + i, col * 2 + j, row);
          const a = u0 + i * s, c = v0 + j * s;
          quad(m, at(a, c, h), at(a, c + s, h), at(a + s, c + s, h), at(a + s, c, h), nv, scaled(base, shade));
        }
        if (!h) continue;
        const sides = [
          [raised(col - 1, row), mul(r, -1), at(u0, v0, 0), at(u0, v0 + t, 0)],
          [raised(col + 1, row), r, at(u0 + t, v0, 0), at(u0 + t, v0 + t, 0)],
          [raised(col, row - 1), mul(d, -1), at(u0, v0, 0), at(u0 + t, v0, 0)],
          [raised(col, row + 1), d, at(u0, v0 + t, 0), at(u0 + t, v0 + t, 0)],
        ];
        const band = b === B.sand ? 1 : 0.3;
        for (const [covered, out, e0, e1] of sides) {
          if (covered) continue;
          const up = mul(nv, t), mid = mul(nv, t * (1 - band)), shade = 0.85 + 0.1 * hash(f, col, row);
          if (band < 1) quad(m, e0, e1, add(e1, mid), add(e0, mid), out, scaled(DIRT, shade));
          quad(m, add(e0, mid), add(e1, mid), add(e1, up), add(e0, up), out, scaled(base, shade * 0.92));
        }
      }
    }
    return m;
  }
  function clouds(n, seed = 1) {
    const m = newMesh(), t = 2 / n, h = 4.5;
    for (let f = 0; f < 6; f++) {
      const [nv, r, d] = BASIS[f];
      const at = (u, v) => add(add(mul(nv, 1 + h * t), mul(r, u)), mul(d, v));
      for (let row = 0; row < n; row++) for (let col = 0; col < n; col++) {
        const coarse = hash(f + seed * 11, Math.floor(col / 4), Math.floor(row / 3)), fine = hash(f + seed * 13, col, row);
        if (!((coarse > 0.8 && fine > 0.4) || fine > 0.995)) continue;
        const u0 = -1 + col * t, v0 = -1 + row * t;
        quad(m, at(u0, v0), at(u0, v0 + t), at(u0 + t, v0 + t), at(u0 + t, v0), nv, [1, 1, 1]);
      }
    }
    return m;
  }
  function cell(lat, lon, n) {
    const la = lat * Math.PI / 180, lo = lon * Math.PI / 180;
    const p = [Math.cos(la) * Math.sin(lo), Math.sin(la), Math.cos(la) * Math.cos(lo)];
    let f = 0;
    for (let i = 1; i < 6; i++) if (dot(BASIS[i][0], p) > dot(BASIS[f][0], p)) f = i;
    const k = dot(BASIS[f][0], p), idx = x => Math.max(0, Math.min(n - 1, Math.floor((x + 1) / 2 * n)));
    return { face: f, col: idx(dot(BASIS[f][1], p) / k), row: idx(dot(BASIS[f][2], p) / k) };
  }
  window.CubeEarth = { isLand, blocks, mesh, clouds, cell, coordinate, point, hash, BASIS };
})();
