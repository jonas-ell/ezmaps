// GM-049: Navigationskern der App für live.html – Abbild von Core/Route.swift, Core/NavigationSession.swift,
// Core/RerouteMonitor.swift, ValhallaClient.speedLimits und AppModel (startNavigation, feed, reroute, Demo-Fahrt). Change both.
'use strict';

// ---------- Route-Hilfen (Core/Route.swift) ----------
function segIndex(r, d) {
  const c = r.cum; if (c.length < 2) return 0;
  d = Math.min(Math.max(d, 0), r.length); let lo = 1, hi = c.length - 1;
  while (lo < hi) { const mid = (lo + hi) >> 1; if (c[mid] < d) lo = mid + 1; else hi = mid; }
  return Math.max(0, lo - 1);
}
function coordAt(r, d) {
  const i = segIndex(r, d), a = r.shape[i], b = r.shape[i + 1] || a, len = r.cum[i + 1] - r.cum[i];
  const t = len > 0 ? Math.min(1, Math.max(0, (Math.min(Math.max(d, 0), r.length) - r.cum[i]) / len)) : 0;
  return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
}
function headingAt(r, d) {
  const i = segIndex(r, d), a = r.shape[i], b = r.shape[i + 1] || a;
  return (Math.atan2((b[1] - a[1]) * Math.cos(a[0] * rad), b[0] - a[0]) / rad + 360) % 360;
}
const nextManeuver = (r, prog) => r.maneuvers.find(m => m.distance > prog + 3) || r.maneuvers[r.maneuvers.length - 1];
function speedLimitAt(r, prog) {
  if (!r.limits || !r.limits.length) return null;
  const v = r.limits[Math.min(segIndex(r, prog), r.limits.length - 1)]; return v === 0 ? null : v;
}
const project = (o, c) => { const kx = Math.cos(o[0] * rad) * 111320; return [(c[1] - o[1]) * kx, -(c[0] - o[0]) * 110540]; }; // LocalProjection
const spokenDistance = m => fmtDist(m).replace(' km', ' Kilometern').replace(' m', ' Metern');
const lowerFirst = t => t ? t[0].toLowerCase() + t.slice(1) : t;

// ---------- NavigationSession + RerouteMonitor (Core) ----------
class NavigationSession {
  constructor(route, destinationName) {
    Object.assign(this, { route, destinationName, progress: 0, arrived: false, spoken: new Set(), lastTrigger: null, snapTolerance: 30, arrivalRadius: 25 });
  }
  replaceRoute(r) { this.route = r; this.progress = 0; this.spoken = new Set(); this.lastTrigger = null; }
  startAnnouncement() { const m = Math.max(1, Math.round(this.route.duration / 60)); return `Route nach ${this.destinationName} gestartet. ${m} ${m === 1 ? 'Minute' : 'Minuten'}.`; }
  static segDist(p, a0, b0) {
    const a = project(p, a0), b = project(p, b0); const dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy;
    const t = Math.min(1, Math.max(0, l2 > 0 ? (-a[0] * dx - a[1] * dy) / l2 : 0));
    return { t, d: Math.hypot(a[0] + t * dx, a[1] + t * dy) };
  }
  static snap(p, r, near, lookahead) {
    if (r.shape.length < 2) return null;
    const from = segIndex(r, near - 50), to = Math.min(r.shape.length - 2, segIndex(r, near + lookahead)); if (from > to) return null;
    let best = null;
    for (let i = from; i <= to; i++) {
      const s = NavigationSession.segDist(p, r.shape[i], r.shape[i + 1]);
      const along = r.cum[i] + s.t * (r.cum[i + 1] - r.cum[i]);
      if (!best || s.d < best.distance) best = { along, distance: s.d };
    }
    return best;
  }
  static distanceToShape(p, shape) {   // RerouteMonitor.distance
    let best = Infinity; for (let i = 1; i < shape.length; i++) best = Math.min(best, NavigationSession.segDist(p, shape[i - 1], shape[i]).d); return best;
  }
  update(pos, speed, now = Date.now()) {
    const v = Math.max(0, speed || 0); let offRoute = false, reroute = false;
    if (!this.arrived) {
      let f = NavigationSession.snap(pos, this.route, this.progress, Math.max(400, v * 40));
      if (!f || f.distance > this.snapTolerance) f = NavigationSession.snap(pos, this.route, this.progress, this.route.length);
      if (f && f.distance <= this.snapTolerance) {
        if (f.along > this.progress || this.progress - f.along > 40) this.progress = f.along;
        this.lastTrigger = null;
      } else {
        offRoute = true;   // RerouteMonitor: mehr als 30 m weg, 8 s Sperrzeit
        if (NavigationSession.distanceToShape(pos, this.route.shape) > 30 && !(this.lastTrigger && now - this.lastTrigger < 8000)) { this.lastTrigger = now; reroute = true; }
      }
      const end = this.route.shape.length ? dist(pos, this.route.shape[this.route.shape.length - 1]) : Infinity;
      if (this.route.length - this.progress <= this.arrivalRadius || (end <= this.arrivalRadius && this.progress > this.route.length * 0.5)) {
        this.arrived = true; this.progress = this.route.length; offRoute = false; reroute = false;
      }
    }
    const state = this.makeState(offRoute);
    return { state, announcement: reroute ? null : this.announcement(state, v), shouldReroute: reroute };
  }
  makeState(offRoute) {
    const r = this.route, m = nextManeuver(r, this.progress); let then = null;
    const i = r.maneuvers.indexOf(m); if (m && i + 1 < r.maneuvers.length && r.maneuvers[i + 1].distance - m.distance < 300) then = r.maneuvers[i + 1];
    const remaining = Math.max(0, r.length - this.progress), seg = segIndex(r, this.progress);
    return { progress: this.progress, maneuver: m, distanceToManeuver: Math.max(0, (m ? m.distance : r.length) - this.progress), thenManeuver: then,
      remainingDistance: remaining, remainingTime: r.length > 0 ? r.duration * remaining / r.length : 0, currentStreet: r.names[seg] || '',
      speedLimit: speedLimitAt(r, this.progress), offRoute, arrived: this.arrived };
  }
  static thresholds(v) {
    return v > 25 ? [[2000, 'far'], [800, 'near'], [120, 'now']] : v > 14 ? [[800, 'far'], [300, 'near'], [60, 'now']] : [[400, 'far'], [150, 'near'], [30, 'now']];
  }
  announcement(st, v) {
    if (st.arrived) { if (this.spoken.has('arrived')) return null; this.spoken.add('arrived'); return `Sie haben ${this.destinationName} erreicht.`; }
    const m = st.maneuver; if (!m) return null;
    const d = st.distanceToManeuver, key = String(Math.round(m.distance)), steps = NavigationSession.thresholds(v);
    for (const [limit, tag] of steps.slice().reverse()) {
      if (d > limit) continue;
      if (tag === 'far' && d <= steps[1][0] + 50) return null;
      if (this.spoken.has(key + tag)) return null;
      this.spoken.add(key + tag);
      if (m.kind === 'destination') return tag === 'now' ? null : `In ${spokenDistance(d)} erreichen Sie Ihr Ziel.`;
      const onto = m.street ? ` auf ${m.street}` : '';
      return tag === 'now' ? `Jetzt ${lowerFirst(m.text)}${onto}.` : `In ${spokenDistance(d)} ${lowerFirst(m.text)}${onto}.`;
    }
    return null;
  }
}

// ---------- Sprache (SpeechService) und Hinweise (AppModel.show) ----------
function say(text) {
  if (!S.voice || !('speechSynthesis' in window)) return;
  const u = new SpeechSynthesisUtterance(text); u.lang = 'de-DE'; speechSynthesis.cancel(); speechSynthesis.speak(u);
}
function show(text) { S.message = text; render(); clearTimeout(show.t); show.t = setTimeout(() => { S.message = null; render(); }, 2500); }

// ---------- Tempolimits (ValhallaClient.speedLimits über trace_attributes, SpeedLimits.fill) ----------
async function loadSpeedLimits(route) {
  try {
    const avg = route.length / route.shape.length, step = Math.max(1, Math.round(15 / Math.max(1, avg))); const idx = [];
    for (let i = 0; i < route.shape.length && route.cum[i] < 150000; i += step) idx.push(i);
    const body = { shape: idx.map(i => ({ lat: route.shape[i][0], lon: route.shape[i][1] })), costing: 'auto', shape_match: 'map_snap',
      filters: { attributes: ['edge.speed_limit', 'matched.edge_index'], action: 'include' } };
    const j = await (await fetch(VALHALLA + '/trace_attributes', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) })).json();
    const lim = new Array(route.shape.length - 1).fill(0);
    (j.matched_points || []).forEach((pt, k) => {
      if (k >= idx.length) return; const e = pt.edge_index; if (e == null || e < 0 || !j.edges[e]) return;
      const sl = j.edges[e].speed_limit; const v = sl === 'unlimited' ? -1 : +sl || 0;
      const endI = k + 1 < idx.length ? idx[k + 1] : route.shape.length - 1;
      for (let s = idx[k]; s < Math.max(idx[k], endI) && s < lim.length; s++) lim[s] = v;
    });
    let lastV = 0; for (let i = 0; i < lim.length; i++) { if (lim[i]) lastV = lim[i]; else if (lastV) lim[i] = lastV; }
    const first = lim.find(x => x); if (first) for (let i = 0; i < lim.length && !lim[i]; i++) lim[i] = first;
    route.limits = lim;
  } catch (e) { console.warn('Tempolimits', e); }
}

// ---------- AppModel: startNavigation, feed, reroute, endNavigation ----------
let session = null, rerouting = false;
function startNav() {
  const r = S.routes[S.sel]; if (!r || !S.dest) return;
  session = new NavigationSession(r, S.dest.name); S.nav = null; routeSmoother.reset();   // GM-085
  S.navCoord = coordAt(r, 0); S.navHeading = headingAt(r, 0); S.navKmh = r.speeds[0] || 50;
  S.screen = 'navigating'; S.routes = [r]; S.sel = 0; S.trail = [];
  say(session.startAnnouncement()); loadSpeedLimits(r);
  startRouteSim();                                          // Demo-Fahrt (Einstellung „Demo-Fahrt“ der App)
  pcam.start(); ccam.start(); for (const m of maps()) pushOverlay(m); render();
}
function feed(pos, speed, course, simFactor = 1) {
  if (!session) return;
  const u = session.update(pos, speed); S.nav = u.state;
  const r = session.route;   // GM-049: neben der Route folgt der Pfeil dem Auto (wie AppModel.feed)
  S.navCoord = u.state.offRoute ? pos : coordAt(r, u.state.progress); S.navHeading = u.state.offRoute ? (course == null ? S.navHeading : course) : headingAt(r, u.state.progress);
  S.navKmh = r.speeds[segIndex(r, u.state.progress)] || 50;
  S.navAnchor = { progress: u.state.progress, mps: (speed == null ? S.navKmh / 3.6 : speed) * simFactor, t: performance.now() };   // GM-050
  routeSmoother.fix(u.state.progress, (speed == null ? S.navKmh / 3.6 : speed) * simFactor, clockS());   // GM-085
  if (u.announcement) say(u.announcement);
  if (u.shouldReroute) reroute(pos, course);
  if (u.state.arrived && S.screen === 'navigating') { sim = null; manual = null; S.screen = 'arrived'; }
}
async function reroute(pos, heading) {
  if (rerouting || !session || !S.dest) return; rerouting = true; render();
  show('Route wird neu berechnet'); say('Route wird neu berechnet.');
  const missedM = nextManeuver(session.route, session.progress); const missed = missedM ? coordAt(session.route, missedM.distance) : null;
  let r = null;
  try { if (missed) r = (await valhallaRoutes(pos, S.dest.c, { heading, exclude: [missed], alternates: 0 }))[0]; } catch (e) { /* GM-016: mit Sperre manchmal kein Weg */ }
  try { if (!r) r = (await valhallaRoutes(pos, S.dest.c, { heading, alternates: 0 }))[0]; } catch (e) { show('Neuberechnung fehlgeschlagen'); }
  if (r && session) { session.replaceRoute(r); S.routes = [r]; S.sel = 0; for (const m of maps()) pushOverlay(m); loadSpeedLimits(r); }
  rerouting = false; render();
}
function endNav() {
  sim = null; manual = null; session = null; S.nav = null; S.navCoord = null; if ('speechSynthesis' in window) speechSynthesis.cancel();
  S.screen = 'map'; S.routes = []; S.dest = null; pcam.stop(); tracking = true; for (const m of maps()) pushOverlay(m); render();
}
function navState() { return S.nav; }

// ---------- GPS-Quelle: Demo-Fahrt, feste Strecke, Tastatur ----------
let sim = null, manual = null, gpsTimer = 0; const keys = {};
function onFix(p, h, kmh, simFactor = 1) {                 // AppModel.handleGPS: Richtung nur ab 1,5 m/s
  S.pos = { p, h: kmh > 5.4 || !S.pos ? h : S.pos.h, kmh };
  S.driveAnchor = { p, mps: kmh / 3.6 * simFactor, t: performance.now() };   // GM-050
  freeSmoother.fix(p, kmh / 3.6 * simFactor, kmh > 5.4 ? h : null, clockS());   // GM-085
  S.trail.push(p); if (S.trail.length > 600) S.trail.shift();
  feed(p, kmh / 3.6, h, simFactor);
  for (const m of maps()) pushOverlay(m); render();
}
function startPathSim(pts, kmhAt) { manual = null; sim = { kind: 'path', pts, cum: cumul(pts), d: 0, kmhAt }; gpsTimer = 1; }
function startRouteSim() { manual = null; sim = { kind: 'route', route: session.route, d: session.progress }; gpsTimer = 1; }
function stepSim(dt) {
  if (!sim) return;
  let p, h, kmh, endLen;
  if (sim.kind === 'route') {
    if (!session) { sim = null; return; }
    if (session.route !== sim.route) { sim.route = session.route; sim.d = session.progress; }   // nach Neuberechnung auf der neuen Route weiter
    const r = sim.route; kmh = r.speeds[segIndex(r, sim.d)] || 50; sim.d = Math.min(r.length, sim.d + kmh / 3.6 * dt * S.speed);
    p = coordAt(r, sim.d); h = headingAt(r, sim.d); endLen = r.length;
  } else {
    const q = at(sim.pts, sim.cum, sim.d); kmh = sim.kmhAt(q.i - 1); sim.d += kmh / 3.6 * dt * S.speed;
    const q2 = at(sim.pts, sim.cum, sim.d); p = q2.p; h = q2.h; endLen = sim.cum[sim.cum.length - 1];
  }
  gpsTimer += dt;
  if (gpsTimer >= 1) { gpsTimer = 0; onFix(p, h, kmh, S.speed); }    // GPS 1×/s, Kamera rechnet dazwischen weiter
  if (sim && sim.kind === 'path' && sim.d >= endLen) sim = null;
}
// Tastatur: W/S oder ↑/↓ Gas/Bremse, A/D oder ←/→ lenken. In der Navigation: abweichen → Neuberechnung wie in der App;
// 3 s ohne Taste → Demo-Fahrt fährt auf der (neuen) Route weiter.
function stepManual(dt) {
  const up = keys.w || keys.arrowup, down = keys.s || keys.arrowdown, left = keys.a || keys.arrowleft, right = keys.d || keys.arrowright;
  const anyKey = up || down || left || right;
  if (!manual) { if (!anyKey || !S.pos) return; sim = null; manual = { p: S.pos.p.slice(), h: S.pos.h, kmh: S.pos.kmh || 0, idle: 0, cruise: 0 }; gpsTimer = 1; }
  const gas = up || manual.cruise > 0; manual.cruise = Math.max(0, manual.cruise - dt);
  manual.kmh = Math.max(0, Math.min(130, manual.kmh + (gas ? 28 : down ? -60 : -6) * dt));
  if (manual.kmh > 1) manual.h = (manual.h + ((right ? 1 : 0) - (left ? 1 : 0)) * Math.min(90, 900 / Math.max(10, manual.kmh)) * dt + 360) % 360;
  const m = manual.kmh / 3.6 * dt;
  manual.p = [manual.p[0] + m * Math.cos(manual.h * rad) / 111320, manual.p[1] + m * Math.sin(manual.h * rad) / (111320 * Math.cos(manual.p[0] * rad))];
  manual.idle = anyKey || manual.cruise > 0 ? 0 : manual.idle + dt;
  gpsTimer += dt;
  if (gpsTimer >= 1) { gpsTimer = 0; onFix(manual.p.slice(), manual.h, manual.kmh); }
  if (session && S.screen === 'navigating' && manual && manual.idle > 3 && !rerouting) startRouteSim();
}
// „Falsch abbiegen“: 6 s quer von der Route weg (wie der Knopf im alten Prototyp)
function wrongTurn() {
  if (!S.pos) return; sim = null;
  manual = { p: S.pos.p.slice(), h: (S.pos.h + 75) % 360, kmh: Math.max(30, S.pos.kmh || 40), idle: 0, cruise: 6 }; gpsTimer = 1;
}
// Klick auf die Karte: über echte Straßen dorthin fahren, ohne Navi
async function driveTo(lngLat) {
  if (S.screen !== 'map' || !S.pos) return;
  try {
    const [r] = await valhallaRoutes(S.pos.p, [lngLat.lat, lngLat.lng], { alternates: 0 });
    startPathSim(r.shape, i => r.speeds[Math.max(0, i)] || 50); tracking = true; ccam.attach(); ccam.start();
  } catch (e) { show('Keine Straße dorthin'); }
}

// GM-085: Mirror of Core/Sources/EzMapsCore/MotionSmoother.swift – change both.
// Weiterrechnen (frei: mit Drehrate) und Abweichung bei neuer Meldung weich über `blend` s ausgleichen → kein Ruck 1×/s.
const dAng = (a, b) => { let d = (b - a) % 360; if (d > 180) d -= 360; else if (d < -180) d += 360; return d; };
const nAng = h => ((h % 360) + 360) % 360;
const movedLL = (p, m, b) => [p[0] + m * Math.cos(b * rad) / 110540, p[1] + m * Math.sin(b * rad) / (111320 * Math.cos(p[0] * rad))];
class FreeMotionSmoother {
  constructor() { this.blend = 0.6; this.maxPredict = 2.5; this.minSpeed = 1.5; this.a = null; this.off = { n: 0, e: 0, h: 0, t: 0 }; }
  fix(c, speed, course, t) {
    const mps = Math.max(0, speed), old = this.pose(t);
    let heading = this.a ? this.a.h : (course ?? 0), turn = 0;
    if (this.a && mps >= this.minSpeed && course != null && course >= 0) { turn = Math.max(-45, Math.min(45, dAng(this.a.h, course) / Math.max(0.2, t - this.a.t))); heading = course; }
    else if (mps >= this.minSpeed && course != null && course >= 0) heading = course;
    this.a = { c, mps, h: heading, turn, t };
    if (old) {
      const raw = this.predict(t), k = 111320 * Math.cos(c[0] * rad);
      this.off = { n: (old.p[0] - raw.p[0]) * 110540, e: (old.p[1] - raw.p[1]) * k, h: dAng(raw.h, old.h), t };
      if (Math.hypot(this.off.n, this.off.e) > 60) this.off = { n: 0, e: 0, h: 0, t };
    }
  }
  predict(t) {
    const a = this.a; if (!a) return null;
    const dt = Math.max(0, Math.min(this.maxPredict, t - a.t));
    if (a.mps < this.minSpeed || dt <= 0) return { p: a.c, h: a.h };
    return { p: movedLL(a.c, a.mps * dt, a.h + a.turn * dt / 2), h: nAng(a.h + a.turn * dt) };
  }
  pose(t) {
    const p = this.predict(t); if (!p) return null;
    const age = t - this.off.t, f = age <= 0 ? 1 : Math.exp(-3 * age / this.blend), k = 111320 * Math.cos(p.p[0] * rad);
    return { p: [p.p[0] + this.off.n * f / 110540, p.p[1] + this.off.e * f / k], h: nAng(p.h + this.off.h * f) };
  }
}
class RouteProgressSmoother {
  constructor() { this.blend = 0.6; this.maxPredict = 2.5; this.reset(); }
  reset() { this.a = null; this.off = { v: 0, t: 0 }; }
  fix(progress, speed, t) { const old = this.value(t); this.a = { progress, mps: Math.max(0, speed), t }; if (old != null) { const d = old - progress; this.off = Math.abs(d) > 40 ? { v: 0, t } : { v: d, t }; } }
  value(t, limit = Infinity) {
    const a = this.a; if (!a) return null;
    const dt = Math.max(0, Math.min(this.maxPredict, t - a.t)), age = t - this.off.t, f = age <= 0 ? 1 : Math.exp(-3 * age / this.blend);
    return Math.min(limit, Math.max(0, a.progress + a.mps * dt + this.off.v * f));
  }
}
const freeSmoother = new FreeMotionSmoother(), routeSmoother = new RouteProgressSmoother();
const clockS = () => performance.now() / 1000;

// GM-050/064: AppModel.cameraTarget – in jedem Bild weiterrechnen, Sprünge weich ausgleichen
function cameraTarget() {
  if (S.screen === 'navigating' && S.navCoord) {
    if (session && !(S.nav && S.nav.offRoute)) {
      const r = session.route, d = routeSmoother.value(clockS(), r.length);
      if (d != null) return { p: coordAt(r, d), h: bearing(coordAt(r, d - 12), coordAt(r, d + 12)), kmh: S.navKmh };
    }
    return { p: S.navCoord, h: S.navHeading, kmh: S.navKmh };
  }
  if (!S.pos) return null;
  const p = freeSmoother.pose(clockS());
  if (p) return { p: p.p, h: p.h, kmh: S.pos.kmh };
  return { p: S.pos.p, h: S.pos.h, kmh: S.pos.kmh };
}
