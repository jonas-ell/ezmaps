// EzMaps – klickbarer Prototyp. Gemeinsamer Zustand für iPhone und CarPlay (wie später ein geteiltes Modell in der App).
import { Router, pointAt, smoothHeading, edgeKey, fmtDist } from './route.js';
import { MapView, renderTexture, drawRoute, drawBlips, drawPlayer, drawDestination, drawFriend, drawFog, STYLES } from './map.js';
import { renderPhone, phoneCamera, phoneHud } from './phone.js';
import { renderCar, carCamera, carHud } from './carplay.js';
import { loadAssets } from './assets.js';
import { setIconStyle } from './icons.js';
import { restoreFocus } from './keys.js';

export const app = {
  scene: null, router: null, textures: {}, views: {},
  state: {
    style: 'neon', voice: true, ducking: true, speedLimit: true, friends: false, simSpeed: 3, carConnected: true, carSize: '1280x480',
    phone: { screen: 'splash', tab: 'map', overlay: null, query: '', sheet: null },
    car: { screen: 'map' },
    nav: null,          // { dest, routes, sel, route, progress, active, arrived, spoken }
    toast: null, speaking: false, loading: null, recents: [],
    browse: { phone: { center: null, scale: 0.42 }, car: { center: null, scale: 1.1 } },
  },
  explored: new Set(),
};
const subs = [];
export const onChange = fn => subs.push(fn);
export function set(patch) { deepMerge(app.state, patch); subs.forEach(f => f()); }
function deepMerge(t, s) { for (const k in s) { const v = s[k]; if (v && typeof v === 'object' && !Array.isArray(v) && !(v instanceof Set) && t[k] && typeof t[k] === 'object' && !Array.isArray(t[k])) deepMerge(t[k], v); else t[k] = v; } }
export function toast(text) { set({ toast: text }); clearTimeout(toast.t); toast.t = setTimeout(() => set({ toast: null }), 2600); }

// ------------------------------------------------------------ Laden
async function boot() {
  await loadAssets();
  const scene = await (await fetch('data/idstein.json')).json();
  app.scene = scene; app.router = new Router(scene.graph);
  app.start = scene.presets.start;
  app.state.browse.phone.center = [...app.start]; app.state.browse.car.center = [...app.start];
  setupExplore();
  app.tiles = new Worker('js/tileworker.js', { type: 'module' });
  app.tiles.postMessage({ type: 'scene', scene });
  app.tiles.onmessage = e => { const t = e.data; app.tilePending = false; if (t.style !== app.state.style) return; app.tile = t; for (const v of Object.values(app.views)) v.setDetail(t.bitmap, t.region, t.S, t.style); };
  app.views.phone = new MapView(document.getElementById('pmap'));
  app.views.car = new MapView(document.getElementById('cmap'));
  await useStyle('neon');
  onChange(renderAll); renderAll();
  bindGestures(app.views.phone, 'phone'); bindGestures(app.views.car, 'car');
  requestAnimationFrame(loop);
  window.__ready = true; document.title = 'EzMaps Prototyp';
}

export async function useStyle(style) {
  app.tile = null; for (const v of Object.values(app.views || {})) v.setDetail?.(null);
    if (!app.textures[style]) {
    set({ loading: `${STYLES[style].name} wird gezeichnet …` });
    await new Promise(r => setTimeout(r, 30));
    app.textures[style] = await renderTexture(app.scene, style);
  }
  setIconStyle(style);
  for (const v of Object.values(app.views)) v.setTexture(app.textures[style], style);
  document.getElementById('phone').className = `phone t-${style}`;
  document.getElementById('car').className = `car t-${style}`;
  set({ style, loading: null });
}
// GM-005: nur neu rendern, wenn wirklich eine Textur dazukam – sonst Endlosschleife über renderPhone → drawStyleMinis
export async function ensureTextures() { let added = false; for (const s of Object.keys(STYLES)) if (!app.textures[s]) { app.textures[s] = await renderTexture(app.scene, s); added = true; } if (added) set({}); }

// ------------------------------------------------------------ Nebel des Krieges + Ortsteile
function setupExplore() {
  const { nodes, edges } = app.scene.graph;
  const hexen = app.scene.presets.hexenturm;
  const villages = app.scene.places.filter(p => p.kind !== 'town');
  const districtOf = p => {
    if (Math.hypot(p[0] - hexen[0], p[1] - hexen[1]) < 420) return 'Altstadt';
    for (const v of villages) if (Math.hypot(p[0] - v.p[0], p[1] - v.p[1]) < 650) return v.name;
    const a = Math.atan2(p[0] - hexen[0], -(p[1] - hexen[1])) * 180 / Math.PI;
    return 'Idstein ' + (a > -45 && a <= 45 ? 'Nord' : a > 45 && a <= 135 ? 'Ost' : a > -135 && a <= -45 ? 'West' : 'Süd');
  };
  app.edgeInfo = new Map(); app.districts = {};
  for (const [a, b, len, , , , rank] of edges) {
    const mid = [(nodes[a][0] + nodes[b][0]) / 2, (nodes[a][1] + nodes[b][1]) / 2];
    if (Math.abs(mid[0]) > 1800 || Math.abs(mid[1]) > 1500 || rank > 6) continue;
    const d = districtOf(mid), k = edgeKey(a, b);
    app.edgeInfo.set(k, { a, b, len, d });
    (app.districts[d] ??= { total: 0, done: 0 }).total += len;
  }
  // Vorgeschichte: schon gefahrene Strecken (Pendelweg + einige Hauptstraßen)
  const seedRoutes = [[app.scene.presets.start, app.scene.presets.home], [app.scene.presets.start, app.scene.presets.work], [app.scene.presets.home, app.scene.presets.hexenturm]];
  for (const [f, t] of seedRoutes) { const r = app.router.route(f, t); r && r.edges.forEach(markExplored); }
  let i = 0; for (const [a, b, , , , , rank] of edges) if (rank <= 3 && (i++ % 2 === 0)) markExplored(edgeKey(a, b));
}
export function markExplored(k) {
  if (app.explored.has(k)) return false;
  const e = app.edgeInfo.get(k); if (!e) return false;
  app.explored.add(k); app.districts[e.d].done += e.len; return true;
}
export function exploredLines() {
  const n = app.scene.graph.nodes, out = [];
  for (const k of app.explored) { const e = app.edgeInfo.get(k); if (e) out.push([n[e.a], n[e.b]]); }
  return out;
}
export const pct = d => Math.round(100 * app.districts[d].done / app.districts[d].total);
export function totalPct() { let t = 0, d = 0; for (const v of Object.values(app.districts)) { t += v.total; d += v.done; } return Math.round(100 * d / t); }

// ------------------------------------------------------------ Navigation
export function planTo(dest) {
  const from = app.start, r = app.router;
  const opts = [['Schnellste', r.route(from, dest.p, 'fast')], ['Kürzeste', r.route(from, dest.p, 'short')], ['Neues entdecken', r.route(from, dest.p, 'explore', app.explored)]]
    .filter(([, x]) => x).filter(([, x], i, arr) => arr.findIndex(([, y]) => Math.abs(y.length - x.length) < 15) === i);
  const routes = opts.map(([label, route]) => ({ label, route, gain: newShare(route) }));
  set({ nav: { dest, routes, sel: 0, route: routes[0].route, progress: 0, active: false, arrived: false, spoken: {} } });
}
function newShare(route) { let l = 0; route.edges.forEach((k, i) => { if (!app.explored.has(k)) l += route.cum[i + 1] - route.cum[i]; }); return Math.round(100 * l / route.length); }
export function selectRoute(i) { const n = app.state.nav; set({ nav: { sel: i, route: n.routes[i].route } }); }
export function startNav() {
  const n = app.state.nav; if (!n) return;
  app.state.recents = [n.dest, ...app.state.recents.filter(r => r.name !== n.dest.name)].slice(0, 5);
  set({ nav: { active: true, progress: 0, arrived: false, spoken: {} }, phone: { overlay: 'nav', sheet: null }, car: { screen: 'nav' } });
  say(`Route nach ${n.dest.name} gestartet. ${fmtMin(n.route.seconds)}.`);
}
export function endNav() { speechSynthesis.cancel(); set({ nav: null, phone: { overlay: null, sheet: null }, car: { screen: 'map' }, speaking: false }); }
const fmtMin = s => `${Math.max(1, Math.round(s / 60))} Minuten`;
export function nextManeuver() {
  const n = app.state.nav; if (!n) return null;
  return n.route.maneuvers.find(m => m.at > n.progress + 3) || n.route.maneuvers[n.route.maneuvers.length - 1];
}
export function segSpeed() {
  const n = app.state.nav, r = n.route, i = pointAt(r.pts, r.cum, n.progress).i - 1;
  return r.speeds[Math.max(0, Math.min(r.speeds.length - 1, i))];
}
export function remaining() {
  const n = app.state.nav, r = n.route, frac = 1 - n.progress / r.length;
  return { m: r.length - n.progress, s: r.seconds * frac };
}
export function currentStreet() { const n = app.state.nav, r = n.route; return r.names[Math.max(0, pointAt(r.pts, r.cum, n.progress).i - 1)] || ''; }

// Ansagen: Ducking wird angezeigt (im Browser nicht hörbar – in der App per AVAudioSession .duckOthers)
export function say(text) {
  if (!app.state.voice || !('speechSynthesis' in window)) return;
  const u = new SpeechSynthesisUtterance(text); u.lang = 'de-DE'; u.rate = 1.05;
  const v = speechSynthesis.getVoices().find(v => v.lang.startsWith('de')); if (v) u.voice = v;
  u.onstart = () => set({ speaking: true }); u.onend = () => set({ speaking: false });
  speechSynthesis.speak(u);
}
function announce() {
  const n = app.state.nav, m = nextManeuver(); if (!m) return;
  const d = m.at - n.progress, key = Math.round(m.at);
  for (const [th, tag] of [[400, 'far'], [150, 'near'], [30, 'now']]) {
    if (d <= th && !n.spoken[key + tag] && (tag !== 'far' || d > 250)) {
      n.spoken[key + tag] = true;
      if (m.kind === 'destination') { if (tag !== 'far') say(tag === 'now' ? `Sie haben ${n.dest.name} erreicht.` : `In ${fmtDist(d).replace(' m', ' Metern')} erreichen Sie Ihr Ziel.`); }
      else say(tag === 'now' ? `Jetzt ${m.text.toLowerCase()} auf ${m.street}.` : `In ${fmtDist(d).replace(' m', ' Metern').replace(' km', ' Kilometern')} ${m.text.toLowerCase()} auf ${m.street}.`);
      break;
    }
  }
}

// GM-006: scharfe Detail-Kachel (900 × 900 m, 4 px/m) rund um das Auto – wie Kachel-Nachladen in echten Karten-Engines
const TILE = 900, TILE_S = 4;
export function requestTile(n) {
  if (app.state.style === 'pixel' || app.tilePending || !app.tiles) return;
  const ahead = pointAt(n.route.pts, n.route.cum, n.progress + 150).p, car = pointAt(n.route.pts, n.route.cum, n.progress).p;
  const t = app.tile;
  if (t && t.style === app.state.style) {
    const cx = t.region.x0 + TILE / 2, cy = t.region.y0 + TILE / 2;
    if (Math.hypot(car[0] - cx, car[1] - cy) < 220) return;
  }
  app.tilePending = true;
  app.tiles.postMessage({ type: 'tile', id: Date.now(), style: app.state.style, S: TILE_S, region: { x0: ahead[0] - TILE / 2, y0: ahead[1] - TILE / 2, w: TILE, h: TILE } });
}

// ------------------------------------------------------------ Hauptschleife
let last = performance.now();
const cams = { phone: null, car: null };
function loop(now) {
  const dt = Math.min(0.1, (now - last) / 1000); last = now;
  const n = app.state.nav;
  if (n && n.active && !n.arrived) {
    const v = segSpeed() / 3.6 * 0.92 * app.state.simSpeed;
    n.progress = Math.min(n.route.length, n.progress + v * dt);
    const i = pointAt(n.route.pts, n.route.cum, n.progress).i;
    if (n.route.edges[i - 1] !== undefined) markExplored(n.route.edges[i - 1]);
    announce();
    requestTile(n);
    if (n.progress >= n.route.length - 1) { n.arrived = true; app.start = n.route.pts[n.route.pts.length - 1]; set({ phone: { sheet: 'arrival' }, car: { screen: 'arrival' } }); }
  }
  for (const [key, view, camFn, hudFn] of [['phone', app.views.phone, phoneCamera, phoneHud], ['car', app.views.car, carCamera, carHud]]) {
    if (!view.tex || !view.el.clientWidth) continue;
    const target = camFn(view);
    cams[key] = cams[key] ? lerpCam(cams[key], target, Math.min(1, dt * 6)) : target;
    const u = view.apply(cams[key]);
    drawOverlay(u, view, key, target.mode);
    hudFn();
  }
  requestAnimationFrame(loop);
}
function lerpCam(a, b, t) {
  const L = (x, y) => x + (y - x) * t;
  let dh = ((b.heading - a.heading + Math.PI * 3) % (Math.PI * 2)) - Math.PI;
  return { ...b, center: [L(a.center[0], b.center[0]), L(a.center[1], b.center[1])], heading: a.heading + dh * t, scale: Math.exp(L(Math.log(a.scale), Math.log(b.scale))), tilt: L(a.tilt, b.tilt), anchor: [L(a.anchor[0], b.anchor[0]), L(a.anchor[1], b.anchor[1])] };
}
function drawOverlay(u, view, key, mode) {
  const s = app.state, n = s.nav, style = s.style;
  if (mode === 'explore') { drawFog(u, view, app.scene, exploredLines()); drawPlayer(u, view, app.start, 0, style, 9); return; }
  if (n && !n.active) n.routes.forEach((r, i) => i !== n.sel && drawRoute(u, view, r.route, 0, style, { alt: true }));
  if (n) drawRoute(u, view, n.route, n.active ? n.progress : 0, style);
  drawBlips(u, view, app.scene, style, { size: key === 'car' ? 13 : undefined }); // GM-008: große Symbole auf CarPlay
  if (s.friends) { drawFriend(u, view, [app.start[0] + 260, app.start[1] - 420], 'Max', style); drawFriend(u, view, [app.start[0] + 880, app.start[1] - 160], 'Lea', style); }
  if (n) drawDestination(u, view, n.dest.p, style, key === 'car' ? 7 : 8);
  if (n && n.active) {
    const p = pointAt(n.route.pts, n.route.cum, n.progress).p;
    drawPlayer(u, view, p, smoothHeading(n.route, n.progress), style, key === 'car' ? 17 : 15);
  } else drawPlayer(u, view, app.start, 0, style, key === 'car' ? 10 : 11);
}

// Ziehen und Zoomen in der Kartenansicht (nur wenn nicht navigiert wird)
function bindGestures(view, key) {
  let drag = null;
  view.el.addEventListener('pointerdown', e => { if (app.state.nav?.active || e.target.closest('[data-act]')) return; drag = { x: e.clientX, y: e.clientY }; });
  window.addEventListener('pointermove', e => {
    if (!drag) return; const b = app.state.browse[key], s = b.scale, h = view.cam.heading;
    const dx = (e.clientX - drag.x) / s, dy = (e.clientY - drag.y) / s; drag = { x: e.clientX, y: e.clientY };
    b.center = [Math.max(-1500, Math.min(1500, b.center[0] - dx * Math.cos(h) - dy * Math.sin(h))), Math.max(-1250, Math.min(1250, b.center[1] + dx * Math.sin(h) - dy * Math.cos(h)))];
  });
  window.addEventListener('pointerup', () => drag = null);
  view.el.addEventListener('wheel', e => { e.preventDefault(); zoom(key, e.deltaY < 0 ? 1.15 : 1 / 1.15); }, { passive: false });
}
export function zoom(key, f) { const b = app.state.browse[key]; b.scale = Math.max(key === 'car' ? 0.32 : 0.16, Math.min(1.6, b.scale * f)); }
export function recenter(key) { app.state.browse[key].center = [...app.start]; app.state.browse[key].scale = key === 'car' ? 1.1 : 0.42; }

function renderAll() { renderPhone(); renderCar(); restoreFocus(); }

// Steuerleiste der Seite
document.addEventListener('click', e => {
  const b = e.target.closest('[data-ctl]'); if (!b) return;
  const [k, v] = b.dataset.ctl.split(':');
  if (k === 'speed') set({ simSpeed: +v });
  if (k === 'carsize') { set({ carSize: v }); applyCarSize(); }
  if (k === 'car') set({ carConnected: !app.state.carConnected });
  if (k === 'reset') location.reload();
  document.querySelectorAll('[data-ctl]').forEach(x => x.classList.toggle('on', x.dataset.ctl === `speed:${app.state.simSpeed}` || x.dataset.ctl === `carsize:${app.state.carSize}`));
});
export function applyCarSize() { const [w, h] = app.state.carSize.split('x').map(Number); const c = document.getElementById('car'); c.style.width = w + 'px'; c.style.height = h + 'px'; }
applyCarSize();
boot().catch(e => { document.title = 'error: ' + e; console.error(e); document.body.insertAdjacentHTML('beforeend', `<pre style="color:#f66">${e.stack}</pre>`); });
