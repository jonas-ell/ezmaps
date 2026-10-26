// GM-022: Ideen-Vorschau – zeichnet Mock-ups mit dem echten Karten-Renderer (map.js) und echten Daten.
// Nur zum Zeigen; die Umsetzung in Swift steht im CHANGELOG (GM-022, „Auftrag“).
import { MapView, renderTexture, renderRegion, drawRoute, drawBlips, drawPlayer, drawDestination, STYLES } from './map.js';
import { Router, pointAt, smoothHeading } from './route.js';
import { loadAssets, appIconUrl } from './assets.js';
import { toLocal } from './geo.js';

const $ = (h) => { const t = document.createElement('template'); t.innerHTML = h.trim(); return t.content.firstElementChild; };
const main = document.getElementById('vz');
const tex = {};
let scene, router, works;

// ------------------------------------------------------------ Zeichen-Bausteine (Spiegel für Swift: siehe CHANGELOG GM-022)

/** Geparktes Auto von oben, Schnauze nach oben (eigene Zeichnung, nicht aus einem Spiel). size = Länge in px */
export function drawParkedCar(u, x, y, size, style, rot = 0) {
  const C = {
    neon: { body: '#ffffff', edge: '#000000', glass: '#1c1c1d', light: '#ffd84a' },
    classic: { body: '#1a73e8', edge: '#ffffff', glass: '#0b3d91', light: '#ffe08a' },
    western: { body: '#f2e4bf', edge: '#2e1e10', glass: '#6b4f2e', light: '#c0261f' },
    pixel: { body: '#ffffff', edge: '#000000', glass: '#1a2a6c', light: '#ffcc33' },
    toy: { body: '#e3412f', edge: '#2f3640', glass: '#7cc3ee', light: '#ffd23f' },
  }[style];
  const L = size, W = size * 0.52;
  if (style === 'pixel') { // kleine Pixel-Grafik, hart vergrößert
    const g = document.createElement('canvas'); g.width = 10; g.height = 18; const p = g.getContext('2d');
    const rows = ['..XXXXXX..', '.XWWWWWWX.', 'XWYWWWWYWX', 'XWWWWWWWWX', 'XWGGGGGGWX', 'XGGGGGGGGX', 'XWWWWWWWWX', 'XWWWWWWWWX', 'XWWWWWWWWX', 'XWWWWWWWWX', 'XWWWWWWWWX', 'XWWWWWWWWX', 'XWGGGGGGWX', 'XWWWWWWWWX', 'XWWWWWWWWX', 'XWRWWWWRWX', '.XWWWWWWX.', '..XXXXXX..'];
    const col = { X: C.edge, W: C.body, G: C.glass, Y: C.light, R: '#e33' };
    rows.forEach((r, j) => [...r].forEach((ch, i) => { if (col[ch]) { p.fillStyle = col[ch]; p.fillRect(i, j, 1, 1); } }));
    u.save(); u.imageSmoothingEnabled = false; u.translate(x, y); u.rotate(rot); u.drawImage(g, -W / 2, -L / 2, W, L); u.restore(); return;
  }
  u.save(); u.translate(x, y); u.rotate(rot); u.lineJoin = 'round';
  const rr = (x0, y0, w, h, r) => { u.beginPath(); u.roundRect(x0, y0, w, h, r); };
  u.shadowColor = 'rgba(0,0,0,.45)'; u.shadowBlur = 6; u.shadowOffsetY = 2;
  rr(-W / 2, -L / 2, W, L, W * 0.38); u.fillStyle = C.body; u.fill(); u.shadowColor = 'transparent';
  u.lineWidth = Math.max(1.5, size * 0.07); u.strokeStyle = C.edge; u.stroke();
  // Spiegel
  u.fillStyle = C.edge; u.fillRect(-W / 2 - size * 0.07, -L * 0.14, size * 0.08, size * 0.06); u.fillRect(W / 2 - size * 0.01, -L * 0.14, size * 0.08, size * 0.06);
  // Frontscheibe, Dach, Heckscheibe
  u.fillStyle = C.glass;
  u.beginPath(); u.moveTo(-W * 0.38, -L * 0.18); u.lineTo(W * 0.38, -L * 0.18); u.lineTo(W * 0.3, -L * 0.04); u.lineTo(-W * 0.3, -L * 0.04); u.closePath(); u.fill();
  u.beginPath(); u.moveTo(-W * 0.3, L * 0.22); u.lineTo(W * 0.3, L * 0.22); u.lineTo(W * 0.36, L * 0.33); u.lineTo(-W * 0.36, L * 0.33); u.closePath(); u.fill();
  if (style === 'toy') { u.fillStyle = 'rgba(255,255,255,.35)'; rr(-W * 0.26, -L * 0.02, W * 0.52, L * 0.22, 4); u.fill(); }
  // Scheinwerfer
  u.fillStyle = C.light; u.fillRect(-W * 0.36, -L / 2 + size * 0.02, W * 0.18, size * 0.05); u.fillRect(W * 0.18, -L / 2 + size * 0.02, W * 0.18, size * 0.05);
  u.restore();
}

/** Baustelle/Sperrung als Strecke im jeweiligen Stil, Symbol in der Mitte */
export function drawWork(u, mv, item, style, scale = 1) {
  const pts = item.line.map(([lo, la]) => mv.project(toLocal(la, lo))).filter(q => q[2] > 0);
  if (pts.length < 2) return null;
  const closure = item.type === 'CLOSURE';
  const S = {
    neon: { base: '#0b0b0c', dash: closure ? '#ff2d55' : '#ff9f1c', glow: closure ? '#ff2d55' : '#ff9f1c', w: 7 },
    classic: { base: '#ffffff', dash: closure ? '#d93025' : '#e8710a', w: 6 },
    western: { base: '#f2e4bf', dash: closure ? '#7a1d12' : '#c0261f', w: 6 },
    pixel: { base: '#000000', dash: closure ? '#ff3b3b' : '#ffcc33', w: 6, square: true },
    toy: { base: '#ffffff', dash: closure ? '#e3412f' : '#ff6b00', w: 8 },
  }[style];
  const path = () => { u.beginPath(); pts.forEach((q, i) => i ? u.lineTo(q[0], q[1]) : u.moveTo(q[0], q[1])); };
  u.save(); u.lineJoin = 'round';
  u.lineCap = S.square ? 'butt' : 'round';
  if (S.glow) { u.shadowColor = S.glow; u.shadowBlur = 10; }
  path(); u.strokeStyle = S.base; u.lineWidth = (S.w + 3) * scale; u.stroke(); u.shadowColor = 'transparent';
  path(); u.strokeStyle = S.dash; u.lineWidth = S.w * scale; u.setLineDash(S.square ? [6 * scale, 6 * scale] : [9 * scale, 7 * scale]); u.stroke();
  u.restore();
  const vis = pts.filter(q => mv.visible(q, -20)); if (!vis.length) return null; // Symbol nur in der sichtbaren Mitte der Strecke
  const mid = vis[vis.length >> 1];
  drawWorkIcon(u, mid[0], mid[1], 13 * scale, style, closure);
  return mid;
}

/** Symbol: Leitkegel (Baustelle) bzw. Durchfahrt-verboten-Schild (Sperrung) je Stil */
export function drawWorkIcon(u, x, y, r, style, closure) {
  u.save(); u.translate(x, y);
  if (closure) {
    const ring = style === 'western' ? '#2e1e10' : style === 'pixel' ? '#000' : '#ffffff';
    if (style === 'neon') { u.shadowColor = '#ff2d55'; u.shadowBlur = 12; }
    u.beginPath(); u.arc(0, 0, r, 0, 7); u.fillStyle = ring; u.fill(); u.shadowColor = 'transparent';
    u.beginPath(); u.arc(0, 0, r * 0.82, 0, 7); u.fillStyle = style === 'western' ? '#7a1d12' : '#e30613'; u.fill();
    u.fillStyle = style === 'western' ? '#f2e4bf' : '#fff'; u.fillRect(-r * 0.55, -r * 0.16, r * 1.1, r * 0.32);
    u.restore(); return;
  }
  if (style === 'western') { // Holzbock mit X
    u.strokeStyle = '#2e1e10'; u.lineWidth = r * 0.28; u.lineCap = 'round';
    u.beginPath(); u.moveTo(-r, r * 0.7); u.lineTo(r, -r * 0.6); u.moveTo(-r, -r * 0.6); u.lineTo(r, r * 0.7); u.stroke();
    u.fillStyle = '#c0261f'; u.strokeStyle = '#2e1e10'; u.lineWidth = r * 0.12;
    u.beginPath(); u.rect(-r * 1.15, -r * 0.35, r * 2.3, r * 0.5); u.fill(); u.stroke();
    u.fillStyle = '#f2e4bf'; for (let i = -1; i <= 1; i++) u.fillRect(i * r * 0.7 - r * 0.15, -r * 0.35, r * 0.3, r * 0.5);
    u.restore(); return;
  }
  if (style === 'pixel') { // Pixel-Kegel
    const px = Math.max(2, Math.round(r / 4)), rows = ['...O...', '..OOO..', '..WWW..', '.OOOOO.', '.WWWWW.', 'OOOOOOO', 'KKKKKKK'];
    const col = { O: '#ff7a00', W: '#ffffff', K: '#000000' };
    rows.forEach((row, j) => [...row].forEach((ch, i) => { if (col[ch]) { u.fillStyle = col[ch]; u.fillRect((i - 3.5) * px, (j - 4) * px, px, px); } }));
    u.restore(); return;
  }
  // Leitkegel: Neon (leuchtend, schwarzer Rand), Klassik (rundes Schild), Toy (Spielzeug)
  if (style === 'classic') {
    u.beginPath(); u.arc(0, 0, r, 0, 7); u.fillStyle = '#e8710a'; u.fill(); u.lineWidth = r * 0.18; u.strokeStyle = '#fff'; u.stroke();
    u.scale(0.62, 0.62);
  }
  if (style === 'neon') { u.shadowColor = '#ff9f1c'; u.shadowBlur = 12; }
  const edge = style === 'toy' ? '#2f3640' : '#000';
  u.beginPath(); u.moveTo(0, -r); u.lineTo(r * 0.62, r * 0.7); u.lineTo(-r * 0.62, r * 0.7); u.closePath();
  u.fillStyle = style === 'classic' ? '#ffffff' : '#ff7a00'; u.fill(); u.shadowColor = 'transparent';
  if (style !== 'classic') { u.lineWidth = r * 0.16; u.strokeStyle = edge; u.stroke(); }
  u.fillStyle = style === 'classic' ? '#e8710a' : '#ffffff';
  u.beginPath(); u.moveTo(-r * 0.3, -r * 0.1); u.lineTo(r * 0.3, -r * 0.1); u.lineTo(r * 0.4, r * 0.22); u.lineTo(-r * 0.4, r * 0.22); u.closePath(); u.fill();
  u.fillStyle = style === 'classic' ? '#ffffff' : edge; u.fillRect(-r * 0.85, r * 0.7, r * 1.7, r * 0.22);
  u.restore();
}

// ------------------------------------------------------------ Karten-Helfer

function view(el, style, cam, detail) {
  const v = new MapView(el); v.setTexture(tex[style], style);
  if (detail) { const S = 4, R = 1100, g = { x0: cam.center[0] - R / 2, y0: cam.center[1] - R / 2 - 250, w: R, h: R }; v.setDetail(renderRegion(scene, style, g, S), g, S, style); }
  return { v, u: v.apply(cam) };
}
function fitCam(pts, el, pad = 30, ax = [0.5, 0.5]) {
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const [x, y] of pts) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  const W = el.clientWidth - 2 * pad, H = el.clientHeight - 2 * pad;
  return { center: [(x0 + x1) / 2, (y0 + y1) / 2], heading: 0, scale: Math.min(W / (x1 - x0), H / (y1 - y0)), tilt: 0, anchor: ax };
}
const worksNear = (p, r) => works.filter(w => w.line.some(([lo, la]) => { const q = toLocal(la, lo); return Math.hypot(q[0] - p[0], q[1] - p[1]) < r; }));

/** Radar: runde, flache Minikarte, Fahrtrichtung oben, Route, Baustellen, Auto, Ortssymbole */
function radar(host, style, at, heading, route, fromD, parked) {
  const wrap = $(`<div class="radar"><div class="fill"></div><div class="ring"></div><div class="north">N</div></div>`);
  host.append(wrap);
  const scale = 0.085, cam = { center: at, heading, scale, tilt: 0, anchor: [0.5, 0.5] };
  const { v, u } = view(wrap.firstElementChild, style, cam);
  drawRoute(u, v, route, fromD, style, { width: 5 });
  for (const w of worksNear(at, 1300)) drawWork(u, v, w, style, 0.6);
  drawBlips(u, v, scene, style, { size: 5 });
  if (parked) { const q = v.project(parked); drawParkedCar(u, q[0], q[1], 18, style, -heading); }
  drawPlayer(u, v, at, heading, style, 10);
  // Nordpfeil am Rand, dreht mit
  const rr = 98 - 12, a = -heading;
  const n = wrap.querySelector('.north'); n.style.left = (98 + Math.sin(a) * rr) + 'px'; n.style.top = (98 - Math.cos(a) * rr) + 'px';
  return wrap;
}

// ------------------------------------------------------------ Abschnitte

function section(title, text) { const s = $(`<section class="sec"><h2>${title}</h2><p>${text}</p><div class="vrow"></div></section>`); main.append(s); return s.querySelector('.vrow'); }
const figure = (el, cap) => { const f = $(`<div></div>`); f.append(el); if (cap) f.append($(`<div class="cap">${cap}</div>`)); return f; };

function carNav(row, style, label, wide = true) {
  const route = router.route(scene.presets.start, scene.presets.work.map((v, i) => v + (i ? -350 : 120))) || router.route(scene.presets.start, scene.presets.hexenturm);
  const d = Math.min(route.length * 0.35, 380), at = pointAt(route.pts, route.cum, d).p, hd = smoothHeading(route, d);
  const car = $(`<div class="vcar ${wide ? '' : 'small'} t-${style}"><div class="vdock"><div>16:48</div><img class="vapp" src="${appIconUrl}"><div class="vapp"></div><div class="vapp" style="background:#2c7be5"></div></div><div class="main"><div class="fill"></div></div></div>`);
  row.append(figure(car, label));
  const m = car.querySelector('.main'), mapEl = m.firstElementChild;
  const { v, u } = view(mapEl, style, { center: at, heading: hd, scale: 4.6, tilt: 60, anchor: [0.62, 0.82] }, true);
  drawRoute(u, v, route, d, style); drawBlips(u, v, scene, style, { size: 12 }); drawPlayer(u, v, at, hd, style, 18);
  const nx = route.maneuvers.find(x => x.at > d + 5) || route.maneuvers[0];
  m.append($(`<div class="cp-card cp-man"><svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round"><path d="M7 21V10a4 4 0 0 1 4-4h8"/><path d="m15 2 4 4-4 4"/></svg><div><b>${Math.round((nx.at - d) / 10) * 10} m</b><span>${nx.street || 'Weilburger Straße'}</span></div></div>`));
  m.append($(`<div class="cp-card cp-eta"><b>16:56</b>8 Min · 4,1 km</div>`));
  m.append($(`<div class="cp-end">✕ Beenden</div>`));
  m.append($(`<div class="cp-btns" style="top:56px"><div>＋</div><div>－</div></div>`));
  const l = $(`<div class="vlimit" style="right:16px;bottom:22px">50</div>`); m.append(l);
  m.append($(`<div class="vosm" style="bottom:4px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`));
  const rw = $(`<div class="radar-wrap" style="left:14px;bottom:14px"></div>`); m.append(rw);
  radar(rw, style, at, hd, route, d, [scene.presets.start[0] + 60, scene.presets.start[1] - 40]);
}

function phoneNav(row, style) {
  const route = router.route(scene.presets.start, scene.presets.hexenturm), d = 260, at = pointAt(route.pts, route.cum, d).p, hd = smoothHeading(route, d);
  const ph = $(`<div class="vphone"><div class="fill"></div><div class="island"></div><div class="sbar"><span class="tm">16:48</span></div><div class="hb"></div></div>`);
  row.append(figure(ph, 'iPhone: Radar unten links (ersetzt das Straßenfeld), Straßenname wandert in den Abbiegehinweis. Tippen auf das Radar = Vollbild-Übersicht.'));
  const { v, u } = view(ph.firstElementChild, style, { center: at, heading: hd, scale: 3.4, tilt: 58, anchor: [0.5, 0.62] }, true);
  drawRoute(u, v, route, d, style); drawBlips(u, v, scene, style, { size: 11 }); drawPlayer(u, v, at, hd, style, 16);
  ph.append($(`<div class="npanel nman"><svg width="46" height="46" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round"><path d="M7 21V10a4 4 0 0 1 4-4h8"/><path d="m15 2 4 4-4 4"/></svg><div><div class="d">150 m</div><div class="s">Am Bahnhof</div><div class="x">Rechts abbiegen · jetzt: Wiesbadener Str.</div></div></div>`));
  ph.append($(`<div class="vlimit" style="right:18px;top:196px">50</div>`));
  const rw = $(`<div class="radar-wrap" style="left:14px;bottom:110px"></div>`); ph.append(rw);
  radar(rw, style, at, hd, route, d, [scene.presets.start[0] + 60, scene.presets.start[1] - 40]);
  ph.append($(`<div class="npanel" style="right:16px;bottom:118px;padding:8px 12px;text-align:center"><div style="font:800 24px Inter">46</div><div style="font:500 11px Inter;color:#a9a9ad">km/h</div></div>`));
  ph.append($(`<div class="vosm" style="bottom:100px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`));
  ph.append($(`<div class="npanel nbottom"><div><div class="eta">16:53</div><small>5 Min · 1,1 km</small></div><div class="nend">Ende</div></div>`));
}

function parking(row) {
  const style = 'neon', car = [scene.presets.start[0] + 60, scene.presets.start[1] - 40], me = scene.presets.hexenturm;
  const ph = $(`<div class="vphone"><div class="fill"></div><div class="island"></div><div class="sbar"><span class="tm">18:10</span></div><div class="hb"></div></div>`);
  row.append(figure(ph, 'Beim Trennen von CarPlay merkt sich die App den Standort. Auf der Karte steht dein Auto (von oben, Schnauze oben). Unten: Karte „Dein Auto“ mit Fußweg und Navigation zu Fuß (Apple Karten öffnen).'));
  const el = ph.firstElementChild, { v, u } = view(el, style, { ...fitCam([car, me], el, 90, [0.5, 0.42]) });
  drawBlips(u, v, scene, style, { size: 8 });
  const q = v.project(car); drawParkedCar(u, q[0], q[1], 34, style);
  u.save(); u.font = '700 12px Inter'; const t = 'Dein Auto · seit 14:32'; const w = u.measureText(t).width + 16;
  u.fillStyle = 'rgba(0,0,0,.88)'; u.fillRect(q[0] - w / 2, q[1] - 46, w, 22); u.fillStyle = '#fff'; u.textAlign = 'center'; u.fillText(t, q[0], q[1] - 31); u.restore();
  drawPlayer(u, v, me, 0.6, style, 13);
  ph.append($(`<div class="npanel" style="left:16px;right:16px;top:58px;height:52px;display:flex;align-items:center;gap:10px;padding:0 16px;border-left:5px solid #a13df0;font:700 20px Inter">⌕ Wohin?</div>`));
  ph.append($(`<div class="npanel" style="left:16px;right:16px;bottom:110px;padding:14px 16px"><div style="display:flex;gap:12px;align-items:center"><canvas width="84" height="84" style="width:42px;height:42px" id="pk-ico"></canvas><div><div style="font:800 18px Inter">Dein Auto</div><div style="font:500 13px Inter;color:#a9a9ad">Bahnhofstraße · seit 14:32 · 950 m · 12 Min zu Fuß</div></div></div><div style="display:flex;gap:8px;margin-top:12px"><div style="flex:1;background:#a13df0;padding:11px;text-align:center;font:800 15px Inter">Zu Fuß hin</div><div style="background:#1c1c1e;padding:11px 14px;font:700 15px Inter">Teilen</div><div style="background:#1c1c1e;padding:11px 14px;font:700 15px Inter">✕</div></div></div>`));
  ph.append($(`<div class="vosm" style="bottom:96px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`));
  const ic = ph.querySelector('#pk-ico').getContext('2d'); ic.scale(2, 2); drawParkedCar(ic, 21, 21, 34, style);
  // alle Stile nebeneinander
  const strip = $(`<div class="legend-box" style="width:auto"><h4>Auto-Symbol je Stil</h4><div style="display:flex;gap:16px"></div></div>`);
  for (const st of ['classic', 'neon', 'western', 'pixel', 'toy']) {
    const box = $(`<div style="text-align:center;font-size:12px"><canvas width="160" height="160" style="width:80px;height:80px;border-radius:12px;background:${STYLES[st].bg}"></canvas><div>${STYLES[st].name}</div></div>`);
    strip.lastElementChild.append(box); const c = box.firstElementChild.getContext('2d'); c.scale(2, 2); drawParkedCar(c, 40, 40, 46, st);
  }
  row.append(strip);
}

function roadworks(row) {
  const w = works.find(x => x.title.includes('Bad Camberg - Niedernhausen')) || works[0];
  // Stelle der Meldung, die Idstein am nächsten liegt (dort hat die Vorschau die genaue Karte)
  const pts = w.line.map(([lo, la]) => toLocal(la, lo)), mid = pts.reduce((b, q) => Math.hypot(q[0], q[1]) < Math.hypot(b[0], b[1]) ? q : b);
  for (const st of ['classic', 'neon', 'western', 'pixel', 'toy']) {
    const t = $(`<div class="vtile t-${st}"><div class="fill"></div><div class="lab">${STYLES[st].name}</div></div>`); row.append(t);
    const { v, u } = view(t.firstElementChild, st, { center: [mid[0] + 330, mid[1] + 60], heading: 0, scale: 0.3, tilt: 0, anchor: [0.5, 0.5] });
    for (const x of worksNear(mid, 900)) drawWork(u, v, x, st, 1.1);
    drawBlips(u, v, scene, st, { size: 7 });
  }
  const lg = $(`<div class="legend-box"><h4>Zeichen</h4><div><canvas width="56" height="56" style="width:28px;height:28px"></canvas>Baustelle / Fahrstreifen verengt</div><div><canvas width="56" height="56" style="width:28px;height:28px"></canvas>Vollsperrung</div><p style="margin-top:8px;color:#888">Quelle: Autobahn GmbH (verkehr.autobahn.de), echte Meldung „${w.title}“, ${w.subtitle}. Auf der Strecke liegt die Markierung genau auf der Fahrbahn, in Fahrtrichtung getrennt.</p></div>`);
  const cs = lg.querySelectorAll('canvas'); [false, true].forEach((cl, i) => { const c = cs[i].getContext('2d'); c.scale(2, 2); drawWorkIcon(c, 14, 14, 11, 'neon', cl); });
  row.append(lg);
  // Warnbanner während der Fahrt je Stil
  const banners = $(`<div style="display:flex;flex-direction:column;gap:10px;width:420px"></div>`);
  for (const st of ['classic', 'neon', 'western', 'pixel', 'toy']) {
    const b = $(`<div class="warn ${st}" style="position:relative;left:0;right:0"><canvas class="ico" width="68" height="68"></canvas><div><b>Baustelle in 1,2 km</b><span>A3 Idstein → Niedernhausen · rechter Fahrstreifen gesperrt</span></div></div>`);
    banners.append(b); const c = b.querySelector('canvas').getContext('2d'); c.scale(2, 2); drawWorkIcon(c, 17, 17, 12, st, false);
  }
  row.append(figure(banners, 'Hinweis erscheint 2 km vorher unter dem Abbiegehinweis (Autobahn), mit kurzer Ansage. Nur Meldungen auf der eigenen Route und in Fahrtrichtung.'));
}

function voices(row) {
  const ph = $(`<div class="vphone"><div class="ios">
    <div class="nav"><span class="bl">‹ Einstellungen</span><span>Stimme</span><span style="width:90px"></span></div>
    <div class="gh">Stimme für Ansagen</div>
    <div class="grp">
      <div class="it"><span class="play">▶</span><span class="grow">Anna<span class="sub">Deutsch · Standard</span></span><span class="chk">✓</span></div>
      <div class="it"><span class="play">▶</span><span class="grow">Helena<span class="sub">Deutsch · Erweitert</span></span><span class="tag">Beste</span></div>
      <div class="it"><span class="play">▶</span><span class="grow">Martin<span class="sub">Deutsch · Erweitert</span></span></div>
      <div class="it"><span class="play">▶</span><span class="grow">Petra<span class="sub">Deutsch · Premium</span></span><span class="tag dl">laden</span></div>
      <div class="it"><span class="play">▶</span><span class="grow">Markus<span class="sub">Deutsch · Premium</span></span><span class="tag dl">laden</span></div>
      <div class="it"><span class="play">▶</span><span class="grow">Yannick<span class="sub">Deutsch · Premium</span></span><span class="tag dl">laden</span></div>
    </div>
    <div class="foot">Die Liste kommt aus iOS (alle deutschen Stimmen auf diesem iPhone). Premium-Stimmen lädst du in iOS: Einstellungen → Bedienungshilfen → Gesprochene Inhalte → Stimmen.</div>
    <div class="gh">Sprechtempo</div>
    <div class="grp"><div class="it"><span>🐢</span><div class="slider"><i></i><b></b></div><span>🐇</span></div></div>
    <div class="gh">Ansagen</div>
    <div class="grp"><div class="it"><span class="grow">Musik bei Ansagen leiser</span><span class="toggle"></span></div><div class="it"><span class="grow">Probeansage<span class="sub">„In 300 Metern rechts abbiegen auf Hauptstraße.“</span></span><span class="play">▶</span></div></div>
  </div><div class="island"></div><div class="sbar"><span class="tm">9:41</span></div><div class="hb"></div></div>`);
  row.append(figure(ph, 'Allgemeine Stimmen-Auswahl (nicht je Stil): Liste aller deutschen iOS-Stimmen mit Probehören, Qualität sichtbar, Premium-Stimmen mit Hinweis zum Laden. Namen hier sind Beispiele – die echte Liste liefert AVSpeechSynthesisVoice.'));
}

function widgets(row) {
  const home = scene.presets.home, work = scene.presets.work, start = scene.presets.start;
  const r1 = router.route(start, home), r2 = router.route(start, work);
  const ph = $(`<div class="vphone"><div class="home"><div class="wgrid">
      <div><div class="wd s" id="w1"><div class="map"></div><div class="badge">⌂ Nach Hause</div><div class="info"><b>14 Min</b><span>Ankunft 17:12 · frei</span></div></div><div class="wlabel">EzMaps</div></div>
      <div><div class="wd s" id="w2"><div class="map"></div><div class="badge">🚗 Dein Auto</div><div class="info"><b>950 m</b><span>Bahnhofstraße</span></div></div><div class="wlabel">EzMaps</div></div>
      <div class="wd m" id="w3"><div class="split"><div class="map"></div><div class="txt"><div><div style="font:700 12px Inter;color:#a9a9ad">ZUR ARBEIT</div><div style="font:800 28px Inter">22 Min</div><span class="warnchip">Baustelle A3</span></div><div style="font:600 12px Inter;background:#a13df0;padding:8px;text-align:center">Losfahren</div></div></div></div>
    </div><div class="apps"><img src="${appIconUrl}"><div></div><div></div><div></div><div></div><div></div><div></div><div></div></div></div>
    <div class="island"></div><div class="sbar"><span class="tm">9:41</span></div><div class="hb"></div></div>`);
  row.append(figure(ph, 'Home-Bildschirm: klein „Nach Hause“ und „Dein Auto“, mittel „Zur Arbeit“ mit Baustellen-Hinweis und Knopf „Losfahren“ (öffnet die App direkt in der Routen-Vorschau). Karten im gewählten Stil.'));
  const mini = (id, route, mark) => {
    const el = ph.querySelector(`#${id} .map`), cam = fitCam(route.pts, el, 16);
    const { v, u } = view(el, 'neon', cam); drawRoute(u, v, route, 0, 'neon', { width: 4 }); drawPlayer(u, v, route.pts[0], 0, 'neon', 7);
    if (mark) { const q = v.project(mark); drawParkedCar(u, q[0], q[1], 22, 'neon'); } else drawDestination(u, v, route.pts[route.pts.length - 1], 'neon', 5);
  };
  mini('w1', r1); mini('w3', r2);
  { const el = ph.querySelector('#w2 .map'), p = [start[0] + 60, start[1] - 40]; const { v, u } = view(el, 'neon', { center: p, heading: 0, scale: 0.35, tilt: 0, anchor: [0.5, 0.4] }); const q = v.project(p); drawParkedCar(u, q[0], q[1], 26, 'neon'); }

  const lock = $(`<div class="vphone"><div class="lock"><div class="date">Montag, 26. Oktober</div><div class="clock">7:42</div>
    <div class="lockw"><div class="c">22<br>Min</div><div class="r">🚗 Zur Arbeit · 22 Min<small>Ankunft 8:04 · Baustelle A3 (+3 Min)</small></div></div>
    <div class="siri"><div class="q">„Hey Siri, navigiere nach Hause“</div><div class="a">EzMaps: Route nach Hause · 14 Min</div><span class="btn">Los</span> <span class="btn" style="background:#2c2c2e">Abbrechen</span></div></div>
    <div class="island"></div><div class="sbar"><span class="tm">7:42</span></div><div class="hb"></div></div>`);
  row.append(figure(lock, 'Sperrbildschirm-Widgets (rund + rechteckig) und Siri/Kurzbefehl „Navigiere nach Hause“ – startet direkt die Navigation, auch in CarPlay.'));
  const sc = $(`<div class="shortcuts">
    <div class="sc" style="background:linear-gradient(135deg,#a13df0,#5b1f8f)"><div class="i">⌂</div><div>Navigiere nach Hause<small>„Hey Siri, nach Hause mit EzMaps“</small></div></div>
    <div class="sc" style="background:linear-gradient(135deg,#2c7be5,#164a8f)"><div class="i">💼</div><div>Navigiere zur Arbeit<small>„Hey Siri, zur Arbeit“</small></div></div>
    <div class="sc" style="background:linear-gradient(135deg,#ff9f1c,#b85d00)"><div class="i">🚗</div><div>Wo ist mein Auto?<small>Zeigt den Parkplatz</small></div></div>
    <div class="sc" style="background:linear-gradient(135deg,#34c759,#1c7a35)"><div class="i">⏱</div><div>Fahrzeit nach Hause<small>Antwort ohne App zu öffnen</small></div></div>
    <div class="sc" style="background:linear-gradient(135deg,#ff2d55,#8f1430)"><div class="i">⛽</div><div>Tankstelle in der Nähe<small>Startet die Suche</small></div></div>
  </div>`);
  row.append(figure(sc, 'Kurzbefehle (App Intents) – erscheinen automatisch in der Kurzbefehle-App und in Siri, ohne Einrichtung.'));
}

function photo(row) {
  const route = router.route(scene.presets.start, scene.presets.home);
  const mk = (style, pad) => {
    const s = $(`<div class="story t-${style}"><div class="map"></div><div class="top"><div class="vlogo">EzMaps</div><div class="ttl">Idstein · Feierabend-Runde</div><div class="dt">26.10.2026 · 17:05</div></div><div class="stats"><div>4,2 km<small>gefahren</small></div><div>9 Min<small>Fahrzeit</small></div><div class="g">+12 %<small>neue Straßen</small></div></div><div class="osm2">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div></div>`);
    return [s, () => { const el = s.firstElementChild, cam = fitCam(route.pts, el, pad, [0.5, 0.52]); const { v, u } = view(el, style, cam); drawRoute(u, v, route, 0, style, { width: 7 }); drawPlayer(u, v, route.pts[0], 0, style, 10); drawDestination(u, v, route.pts[route.pts.length - 1], style, 7); }];
  };
  const ph = $(`<div class="vphone"><div class="editor"><div class="vbar"><span class="x">Abbrechen</span><span>Fotomodus</span><span class="ok">Sichern</span></div><div class="stage"></div>
    <div class="vchips"><span class="chip2 on">Story 9:16</span><span class="chip2">Quadrat</span><span class="chip2">Breit</span></div>
    <div class="vchips"><span class="chip2">Klassik</span><span class="chip2 on">Neon</span><span class="chip2">Western</span><span class="chip2">Pixel</span><span class="chip2">Toy</span></div>
    <div class="vchips"><span class="chip2 on">✓ Werte</span><span class="chip2 on">✓ Titel</span><span class="chip2">Datum</span><span class="chip2">Ohne Start/Ziel</span></div>
    <div class="share">Teilen …</div></div><div class="island"></div><div class="sbar"><span class="tm">17:06</span></div><div class="hb"></div></div>`);
  const [s1, draw1] = mk('neon', 46); ph.querySelector('.stage').append(s1);
  row.append(figure(ph, 'Nach der Ankunft (oder in „Meine Fahrten“): Bild der Route im Kartenstil, Format, Stil, Texte wählbar. Start/Ziel lassen sich ausblenden (Privatsphäre: Wohnort).'));
  const others = $(`<div style="display:flex;gap:16px;align-items:flex-start"></div>`); const draws = [draw1];
  for (const st of ['western', 'pixel', 'toy']) { const [s, d] = mk(st, 46); others.append(s); draws.push(d); }
  row.append(figure(others, 'Dieselbe Fahrt als Story in anderen Stilen (1080 × 1920 beim Teilen).'));
  requestAnimationFrame(() => draws.forEach(f => f()));
}

function fastLoad(row) {
  const route = router.route(scene.presets.start, scene.presets.home), a = route.pts[0], b = route.pts[route.pts.length - 1];
  const ph = $(`<div class="vphone"><div class="fill"></div><div class="island"></div><div class="sbar"><span class="tm">16:48</span></div><div class="hb"></div></div>`);
  row.append(figure(ph, 'Sofort nach dem Tippen (0 ms): Ziel ist auf der Karte, gestrichelte Luftlinie, Blatt mit Ziel und „Los“ schon da – nur ein kleiner Hinweis statt Vollbild-Ladefenster. Die Route ersetzt die Luftlinie nach ~0,5 s.'));
  const el = ph.firstElementChild, cam = fitCam([a, b], el, 70, [0.5, 0.36]);
  const { v, u } = view(el, 'neon', cam);
  const qa = v.project(a), qb = v.project(b);
  u.save(); u.setLineDash([10, 9]); u.lineWidth = 4; u.strokeStyle = 'rgba(161,61,240,.85)'; u.beginPath(); u.moveTo(qa[0], qa[1]); u.lineTo(qb[0], qb[1]); u.stroke(); u.restore();
  drawPlayer(u, v, a, 0, 'neon', 12); drawDestination(u, v, b, 'neon', 8);
  ph.append($(`<div class="chiploading"><span class="spin"></span>Route kommt …</div>`));
  ph.append($(`<div class="npanel" style="left:0;right:0;bottom:0;padding:18px 18px 34px"><div style="font:800 28px Inter">Zuhause</div><div style="font:500 14px Inter;color:#a9a9ad;margin:2px 0 12px">Lanaer Straße · 1,4 km Luftlinie</div><div style="background:#fff;color:#000;padding:12px 14px;display:flex;justify-content:space-between"><b>Schnellste</b><b>≈ 5 Min</b></div><div style="margin-top:10px;background:#a13df0;height:54px;display:grid;place-items:center;font:800 20px Inter">Los</div></div>`));
  const tl = $(`<div class="timeline"><h4>Heute</h4><div class="vtl"><i style="left:0;width:8%;background:#444">Tippen</i><i style="left:8%;width:62%;background:#5a5a60">Vollbild „Route wird berechnet …“</i><i style="left:70%;width:30%;background:#a13df0">Vorschau</i></div>
    <h4>Neu</h4><div class="vtl"><i style="left:0;width:3%;background:#444"></i><i style="left:3%;width:97%;background:#a13df0">Vorschau sofort (Ziel + Luftlinie), Route blendet bei ~0,5 s ein</i></div>
    <div class="axis"><span>0 s</span><span>0,5 s</span><span>1 s</span><span>1,5 s</span></div>
    <p style="margin-top:12px;color:#aaa;line-height:1.5">Gemessen (FOSSGIS-Valhalla, Idstein → Frankfurt): 0,5–1,0 s je Anfrage, Alternativen kosten kaum mehr. Schneller wird es durch: Anfrage schon beim Antippen des Treffers starten (nicht erst nach dem Wechsel), oberste 1–2 Suchtreffer im Hintergrund vorab berechnen, Antworten 5 Min merken, Tempolimits erst nach „Los“, Verbindung offen halten.</p></div>`);
  row.append(tl);
}

function styleShop(row) {
  const ph = $(`<div class="vphone"><div class="ios" style="padding-top:58px"><h1>Stile</h1><div class="stylegrid">
    <div class="scard big" data-st="neon"><div class="vmini"></div><span class="pill hot">Beliebtester Stil</span><span class="pill pro">Premium</span><div class="foot"><b class="sf-n">Neon City</b><small>Dunkle Open-World-Karte · inkl. CarPlay</small></div></div>
    <div class="scard" data-st="classic"><div class="vmini"></div><span class="pill free">Gratis</span><div class="foot"><b>Klassik</b><small>Aktiv</small></div></div>
    <div class="scard" data-st="western"><div class="vmini"></div><span class="pill pro">Premium</span><div class="foot"><b class="sf-w">Wild West</b><small>Tippen zum Testen</small></div></div>
    <div class="scard" data-st="pixel"><div class="vmini"></div><span class="pill pro">Premium</span><div class="foot"><b class="sf-p">Pixel Quest</b><small>Tippen zum Testen</small></div></div>
    <div class="scard" data-st="toy"><div class="vmini"></div><span class="pill pro">Premium</span><div class="foot"><b class="sf-t">Toy Town</b><small>Tippen zum Testen</small></div></div>
  </div><div class="buy"><div><b>Alle Stile</b> · einmalig, auch künftige</div><span>Freischalten</span></div></div><div class="island"></div><div class="sbar"><span class="tm">9:41</span></div><div class="hb"></div></div>`);
  row.append(figure(ph, 'Gratis ist ab jetzt „Klassik“ (heller Stadtplan). Neon City wird groß und zuerst gezeigt (beliebtester Stil), Premium-Stile kann man vor dem Kauf auf der echten Karte testen (Vorschau-Fahrt).'));
  const route = router.route(scene.presets.start, scene.presets.hexenturm), d = 700, at = pointAt(route.pts, route.cum, d).p, hd = smoothHeading(route, d);
  requestAnimationFrame(() => ph.querySelectorAll('.scard').forEach(c => {
    const st = c.dataset.st, { v, u } = view(c.querySelector('.vmini'), st, { center: at, heading: hd, scale: 1.25, tilt: 50, anchor: [0.5, 0.7] });
    drawRoute(u, v, route, d, st, { width: 7 }); drawBlips(u, v, scene, st, { size: 7 }); drawPlayer(u, v, at, hd, st, 10);
  }));
  // Klassik groß, damit man den Gratis-Stil sieht
  const t = $(`<div class="vtile t-classic" style="width:393px;height:520px"><div class="fill"></div><div class="lab">Klassik (gratis) – Stadtübersicht</div></div>`); row.append(figure(t, 'Neuer Gratis-Stil „Klassik“: ruhig, hell, gut lesbar – absichtlich ohne Spiel-Look, damit sich Neon City lohnt.'));
  requestAnimationFrame(() => { const { v, u } = view(t.firstElementChild, 'classic', { center: [80, 120], heading: 0, scale: 0.3, tilt: 0, anchor: [0.5, 0.5] }); drawRoute(u, v, route, 0, 'classic'); drawBlips(u, v, scene, 'classic', {}); drawPlayer(u, v, route.pts[0], 0, 'classic', 12); });
}

// ------------------------------------------------------------ Start
async function boot() {
  await loadAssets();
  scene = await (await fetch('data/idstein.json')).json();
  works = (await (await fetch('data/autobahn_a3_idstein.json')).json()).meldungen;
  router = new Router(scene.graph);
  for (const st of ['classic', 'neon', 'western', 'pixel', 'toy']) tex[st] = await renderTexture(scene, st);
  await document.fonts.ready;

  carNav(section('1 · Radar-Minikarte in CarPlay', 'Runde, flache Übersicht unten links (Fahrtrichtung oben, Nordpfeil am Rand), ~1,2 km Umkreis: Route, Baustellen, Ortssymbole, dein geparktes Auto. Die große Karte bleibt die 3D-Fahransicht. Abbiegekarte und Ankunftszeit oben links zeichnet iOS (CarPlay-Vorlage) – das Radar liegt in unserem Kartenfenster.'), 'neon', 'CarPlay 1280 × 480 · Neon City');
  const r1b = main.lastElementChild.querySelector('.vrow'); carNav(r1b, 'classic', 'CarPlay 800 × 480 · Klassik (gratis) – Radar gibt es in jedem Stil', false);
  carNav(r1b, 'western', 'CarPlay 800 × 480 · Wild West', false);
  phoneNav(section('2 · Radar auf dem iPhone', 'Gleiches Radar während der Navigation auf dem iPhone.'), 'neon');
  parking(section('3 · „Wo hab ich geparkt?“', 'Auto-Symbol von oben, richtig herum (Schnauze oben), eigene Zeichnung je Stil.'));
  roadworks(section('4 · Baustellen und Sperrungen (Autobahn GmbH) – je Stil', 'Echte Meldungen von heute auf der A3 bei Idstein. Markierung direkt auf der Fahrbahn im Stil der Karte, Symbol in der Mitte, Warnung vor der Stelle.'));
  voices(section('5 · Stimmen-Auswahl (allgemein)', 'Eine Auswahl für alle Stile, in den Einstellungen.'));
  widgets(section('6 · Widgets und Kurzbefehle', 'Home-Bildschirm, Sperrbildschirm, Siri und die Kurzbefehle-App.'));
  photo(section('7 · Fotomodus', 'Teilbares Bild der Fahrt im Kartenstil.'));
  fastLoad(section('8 · Route ohne Wartezeit', 'Statt Ladebildschirm mit Tipps: die Vorschau ist sofort da.'));
  styleShop(section('9 · Neuer Gratis-Stil, Neon City als Premium', 'Stile-Seite mit Gratis/Premium.'));
  window.__ready = true;
}
boot().catch(e => { console.error(e); document.body.insertAdjacentHTML('beforeend', `<pre style="color:#f66">${e.stack}</pre>`); });
