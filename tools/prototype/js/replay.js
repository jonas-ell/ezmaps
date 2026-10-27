// GM-041: Fahrt-Replay – Kameraplan für ein 10-s-Video (GM-044: 16:9 wie CarPlay). Arbeitet hier in lokalen Metern [x, y] (y nach Süden)
// und mit Kamera-Werten des Prototyps (heading in Bogenmaß, scale = Pixel pro Meter).
// Mirror of Core/Sources/EzMapsCore/ReplayPlanner.swift – change both.
const ease = x => x < 0.5 ? 2 * x * x : 1 - (-2 * x + 2) ** 2 / 2;
const turn = (from, to, k) => { let d = (to - from) % (2 * Math.PI); if (d > Math.PI) d -= 2 * Math.PI; else if (d < -Math.PI) d += 2 * Math.PI; return from + d * k; };

export function planReplay(pts, { duration = 10, fps = 30, followShare = 0.72, followScale = 2.4, W = 960, H = 540 } = {}) {
  if (pts.length < 2) return [];
  const cum = [0]; for (let i = 1; i < pts.length; i++) cum.push(cum[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]));
  const total = Math.max(cum.at(-1), 1);
  const at = d => { let i = 1; while (i < cum.length - 1 && cum[i] < d) i++; const f = Math.min(1, Math.max(0, (d - cum[i - 1]) / Math.max(cum[i] - cum[i - 1], 1e-9))); const a = pts[i - 1], b = pts[i]; return [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f]; };
  const hd = (a, b) => Math.atan2(b[0] - a[0], -(b[1] - a[1]));
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity; for (const [x, y] of pts) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  const mid = [(x0 + x1) / 2, (y0 + y1) / 2], fit = Math.min(followScale, W * 0.8 / Math.max(x1 - x0, 1), H * 0.7 / Math.max(y1 - y0, 1));
  const n = Math.max(2, Math.round(duration * fps)), out = [];
  let head = hd(pts[0], at(Math.min(total, 60)));
  for (let i = 0; i < n; i++) {
    const t = i / (n - 1);
    if (t <= followShare) {
      const p = ease(t / followShare), d = p * total, here = at(d);
      if (d + 1 < total) head = turn(head, hd(here, at(Math.min(total, d + 80))), 0.12);
      out.push({ center: here, heading: head, scale: followScale, tilt: 55, progress: p });
    } else {
      const q = ease((t - followShare) / (1 - followShare)), end = pts.at(-1);
      out.push({ center: [end[0] + (mid[0] - end[0]) * q, end[1] + (mid[1] - end[1]) * q], heading: head * (1 - q), scale: followScale + (fit - followScale) * q, tilt: 55 * (1 - q), progress: 1 });
    }
  }
  return out;
}
