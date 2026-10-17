// iPhone-Oberfläche (393 × 852 pt, 1 CSS-px = 1 pt).
import { app, set, toast, useStyle, ensureTextures, planTo, selectRoute, startNav, endNav, nextManeuver, segSpeed, remaining, currentStreet, pct, totalPct, zoom, recenter } from './app.js';
import { ic, manIc } from './icons.js';
import { badgeUrl, appIconUrl } from './assets.js';
import { fmtDist, fmtMin, smoothHeading, pointAt } from './route.js';
import { MapView, STYLES, drawRoute, drawPlayer, drawBlips, drawDestination, LEGEND, legendSrc } from './map.js';

const root = () => document.getElementById('pui');
const H = 852, W = 393;

// ------------------------------------------------------------ Kamera
export function phoneCamera(view) {
  const s = app.state, n = s.nav, p = s.phone;
  if (n && n.active && n.arrived) return { mode: 'arrived', ...fit(n.route.pts, view, 70, 330) }; // GM-009 (1.6): Übersicht der gefahrenen Strecke
  if (n && n.active) {
    const r = n.route, pos = pointAt(r.pts, r.cum, n.progress).p;
    return { mode: 'nav', center: pos, heading: smoothHeading(r, n.progress), scale: 3.4, tilt: 58, anchor: [0.5, 0.63] }; // GM-009 (1.4): Pfeil über dem Straßenfeld // GM-006: Nutzerwunsch – nah wie Apple Maps (Pfeil unten, steile Neigung)
  }
  if (p.overlay === 'preview' && n) return { mode: 'preview', ...fit(n.routes.map(r => r.route.pts).flat(), view, 120, 470) };
  if (!p.overlay && p.tab === 'explore') return { mode: 'explore', center: [0, 80], heading: 0, scale: 0.155, tilt: 0, anchor: [0.5, 0.42] };
  const b = s.browse.phone;
  return { mode: 'browse', center: b.center, heading: 0, scale: b.scale, tilt: 0, anchor: [0.5, 0.5] };
}
export function fit(pts, view, top, bottom, left = 20, right = 20) {
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const [x, y] of pts) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  const [Wv, Hv] = view.size(), aw = Wv - left - right, ah = Hv - top - bottom;
  const scale = Math.min(1.1, Math.min(aw / Math.max(60, x1 - x0), ah / Math.max(60, y1 - y0)) * 0.9);
  return { center: [(x0 + x1) / 2, (y0 + y1) / 2], heading: 0, scale, tilt: 0, anchor: [(left + aw / 2) / Wv, (top + ah / 2) / Hv] };
}

// ------------------------------------------------------------ Live-Werte während der Fahrt
let lastHud = '';
export function phoneHud() {
  const n = app.state.nav; if (!n || !n.active || app.state.phone.overlay !== 'nav') return;
  const m = nextManeuver(), rem = remaining(), sp = segSpeed();
  const eta = new Date(Date.now() + rem.s * 1000), etaStr = eta.getHours() + ':' + String(eta.getMinutes()).padStart(2, '0');
  const vals = { dist: fmtDist(m.at - n.progress), street: m.kind === 'destination' ? n.dest.name : m.street, text: m.text, eta: etaStr, rem: `${fmtMin(rem.s)} · ${fmtDist(rem.m)}`, cur: currentStreet() || '—', limit: limitFor(sp), speed: Math.round(sp * 0.92), icon: m.kind, prog: n.progress / n.route.length };
  const key = JSON.stringify(vals); if (key === lastHud) return; lastHud = key;
  const $ = id => root().querySelector(`[data-hud=${id}]`);
  if (!$('dist')) return;
  $('dist').textContent = vals.dist; $('dist2').textContent = '↑ ' + vals.dist; $('street').textContent = vals.street; $('text').textContent = vals.text;
  $('eta').textContent = vals.eta; $('rem').textContent = vals.rem; $('cur').textContent = vals.cur; $('limit').textContent = vals.limit; $('speed').textContent = vals.speed;
  $('icon').innerHTML = manIc(vals.icon, 64); $('prog').style.width = (vals.prog * 100) + '%'; $('time').style.width = (100 - vals.prog * 80) + '%';
}
export const limitFor = sp => sp >= 100 ? 120 : sp >= 70 ? 100 : sp >= 45 ? 50 : sp >= 25 ? 30 : 10;

// ------------------------------------------------------------ Rendern
export function renderPhone() {
  const s = app.state, p = s.phone;
  lastHud = '';
  let html = '';
  if (p.screen === 'splash') html = splash();
  else if (p.screen === 'permission') html = splash(true) + permission();
  else if (p.screen === 'pickStyle') html = pickStyle();
  else {
    if (p.overlay === 'search') html = search();
    else if (p.overlay === 'preview') html = preview();
    else if (p.overlay === 'nav') html = nav();
    else html = ({ map: home, explore, styles, profile })[p.tab]() + tabs(p.tab);
    if (p.sheet === 'arrival') html += arrival();
    if (p.sheet === 'friends') html += friendsSheet();
  }
  html += osm();
  if (s.toast) html += `<div class="toast panel">${s.toast}</div>`;
  if (s.loading) html += `<div class="loading"><div class="spinner"></div>${s.loading}</div>`;
  // GM-007: in der Suche bleibt der Cursor immer im Feld (auch nach Bildschirm-Tasten und Neuzeichnen)
  const keepInput = app.state.phone.overlay === 'search' && !app.state.phone.cat;
  html = html.replace(/class="head([^"]*)" style="font-size:(\d+)px/g, (m, c, n) => `class="head${c}" style="font-size:calc(${n}px * var(--hs))`);
  root().innerHTML = html;
  if (keepInput) { const q = document.getElementById('q'); q.focus(); q.setSelectionRange(q.value.length, q.value.length); }
  if (p.tab === 'styles' && !p.overlay && p.screen === 'main') drawStyleMinis();
}

const btn = (act, icon, extra = '') => `<button class="mbtn panel" data-act="${act}" ${extra}>${ic(icon, 22)}</button>`;
const tabs = on => `<nav class="tabs">${[['map', 'map', 'Karte'], ['explore', 'explore', 'Entdecken'], ['styles', 'style', 'Stile'], ['profile', 'profile', 'Profil']].map(([k, i, t]) => `<button data-act="tab:${k}" class="${k === on ? 'on' : ''}">${ic(i, 26)}<span>${t}</span></button>`).join('')}</nav>`;

function splash(dim) {
  return `<div class="splash ${dim ? 'dim' : ''}">
    <img class="logo" src="${appIconUrl}" alt="EzMaps"><div class="head" style="font-size:52px;margin-top:22px">EzMaps</div>
    <div class="sub">Deine Stadt als Open World.<br>Echte Navigation – iPhone &amp; CarPlay.</div>
    ${dim ? '' : `<button class="cta" data-act="go:permission">Los geht's</button><div class="fine">Kartendaten © OpenStreetMap-Mitwirkende</div>`}</div>`;
}
function permission() {
  return `<div class="ios-alert-bg"><div class="ios-alert">
    <div class="t">„EzMaps“ erlauben, deinen Standort zu verwenden?</div>
    <div class="m">Für Abbiegehinweise und um die Karte dort aufzudecken, wo du schon gefahren bist. Deine Fahrten bleiben auf deinem iPhone.</div>
    <div class="mini-map"><span>Genau: An</span></div>
    <button data-act="go:pickStyle">Einmal erlauben</button><button data-act="go:pickStyle">Beim Verwenden der App erlauben</button><button data-act="go:pickStyle">Nicht erlauben</button></div></div>`;
}
function pickStyle() {
  return `<div class="page solid"><div class="page-in">
    <div class="head" style="font-size:40px">Wähle deinen Stil</div>
    <div class="muted" style="margin:8px 0 22px">Neon City ist gratis – mit CarPlay. Weitere Stile kannst du später testen.</div>
    ${Object.entries(STYLES).map(([k, v]) => `<button class="stylepick st-${k} ${app.state.style === k ? 'sel' : ''}" data-act="style:${k}"><span class="sw"></span><span><b class="sf-${k}">${v.name}</b><small>${k === 'neon' ? 'Gratis · inkl. CarPlay' : 'Vorschau verfügbar'}</small></span>${app.state.style === k ? ic('check', 22) : ''}</button>`).join('')}
    <button class="cta" style="margin-top:24px;width:100%" data-act="go:main">Weiter</button></div></div>`;
}

function home() {
  const d = districtHere();
  return `<div class="searchbar panel" data-act="open:search">${ic('search', 20)}<span class="head" style="font-size:26px">Wohin?</span><span class="muted" style="margin-left:auto">${ic('mic', 20)}</span></div>
    <div class="chips">${[['home', 'Zuhause', 'dest:home', '#fff'], ['work', 'Arbeit', 'dest:work', '#fff'], ['fuel', 'Tanken', 'cat:fuel', '#f08a2c'], ['parking', 'Parken', 'cat:parking', '#5fb6ff']].map(([i, t, a, c]) => `<button class="chip panel" data-act="${a}"><span style="color:${c}">${ic(i, 16)}</span>${t}</button>`).join('')}</div>
    <div class="rbtns">${btn('legend', 'layers')}${btn('sheet:friends', 'friends')}${btn('recenter', 'locate')}${btn('zoom:in', 'plus')}${btn('zoom:out', 'minus')}</div>
    ${app.state.legend ? legend() : ''}
    <div class="scalebar" data-scale></div>
    <button class="district panel" data-act="tab:explore"><div class="row sb"><span class="upper b">${d}</span><span class="head" style="font-size:30px">${pct(d)}%</span></div>
      <div class="bar"><i style="width:${pct(d)}%;background:var(--ok)"></i></div><div class="muted small">entdeckt · tippe für deine Karte</div></button>
`;
}
function districtHere() { const e = [...app.edgeInfo.values()].reduce((b, e) => { const n = app.scene.graph.nodes[e.a], d = Math.hypot(n[0] - app.start[0], n[1] - app.start[1]); return d < b[0] ? [d, e.d] : b; }, [1e9, 'Altstadt']); return e[1]; }

// GM-010 (0.6) / GM-012: Legende rechts – weißer Text auf schwarzen Kästen, Symbole wie auf der Karte, Tippen hebt hervor
function legend() {
  return `<div class="legend"><div class="lg-title">Legende</div>${LEGEND.map(([k, t]) => `<button class="lg-row ${app.state.highlight === k ? 'on' : ''}" data-act="hl:${k}"><span>${t}</span><img src="${legendSrc(k)}" alt=""></button>`).join('')}</div>`;
}

// ---------------- Suche
const presetDest = k => ({ home: { name: 'Zuhause', sub: 'Lanaer Straße', p: app.scene.presets.home, icon: 'home' }, work: { name: 'Arbeit', sub: 'Black-und-Decker-Straße', p: app.scene.presets.work, icon: 'work' } })[k];
function results(q) {
  q = q.trim().toLowerCase(); if (!q) return [];
  const out = [], seen = new Set();
  for (const s of app.scene.search) if (s.name.toLowerCase().includes(q) && !seen.has(s.name)) { seen.add(s.name); out.push({ name: s.name, sub: s.label + (s.street ? ` · ${s.street} ${s.no}` : ''), p: s.p, icon: iconFor(s.kind) }); }
  for (const l of app.scene.lines) if (l.k === 'road' && l.name && l.name.toLowerCase().includes(q) && !seen.has(l.name)) { seen.add(l.name); out.push({ name: l.name, sub: 'Straße · Idstein', p: l.pts[l.pts.length >> 1], icon: 'pin' }); }
  return out.map(r => ({ ...r, d: Math.hypot(r.p[0] - app.start[0], r.p[1] - app.start[1]) })).sort((a, b) => (b.name.toLowerCase().startsWith(q) - a.name.toLowerCase().startsWith(q)) || a.d - b.d).slice(0, 7);
}
const iconFor = k => ({ fuel: 'fuel', parking: 'parking', restaurant: 'food', cafe: 'food', fast_food: 'food', supermarket: 'star', attraction: 'star', station: 'pin' })[k] || 'pin';
export function category(kind) {
  return app.scene.search.filter(s => s.kind === kind).map(s => ({ name: s.name, sub: s.label, p: s.p, icon: iconFor(kind), d: Math.hypot(s.p[0] - app.start[0], s.p[1] - app.start[1]) })).sort((a, b) => a.d - b.d).slice(0, 6);
}
let lastList = [];
function row(r, i, sel) { return `<button class="item ${sel ? 'sel' : ''}" data-act="pick:${i}"><span class="row" style="gap:14px"><span class="ricon">${ic(r.icon, 22)}</span><span class="tl">${r.name}<small>${r.sub}${r.d != null ? ' · ' + fmtDist(r.d) : ''}</small></span></span>${ic('chevron', 16)}</button>`; }
function search() {
  const q = app.state.phone.query, cat = app.state.phone.cat;
  let sections;
  if (cat) { lastList = category(cat); sections = [[cat === 'fuel' ? 'Tankstellen' : 'Parkplätze', lastList]]; }
  else if (q) { lastList = results(q); sections = [['Treffer', lastList]]; }
  else {
    const fav = [presetDest('home'), presetDest('work')], hex = { name: 'Hexenturm', sub: 'Sehenswürdigkeit', p: app.scene.presets.hexenturm, icon: 'star' };
    const rec = app.state.recents.length ? app.state.recents : [hex];
    lastList = [...fav, ...rec].map(r => ({ ...r, d: Math.hypot(r.p[0] - app.start[0], r.p[1] - app.start[1]) }));
    sections = [['Favoriten', lastList.slice(0, 2)], ['Zuletzt', lastList.slice(2)]];
  }
  let idx = 0;
  const list = sections.map(([t, items]) => `<div class="menu panel"><div class="mtitle head">${t}</div>${items.length ? items.map(r => row(r, idx++, idx === 1 && (q || cat))).join('') : '<div class="item muted">Nichts gefunden</div>'}</div>`).join('');
  return `<div class="dimmer"></div>
    <div class="searchtop"><div class="sfield">${ic('search', 18)}<input id="q" value="${q.replace(/"/g, '&quot;')}" placeholder="Ort, Adresse oder Kontakt" autocomplete="off"></div><button class="link" data-act="close:search">Abbrechen</button></div>
    <div class="slist">${list}</div>${keyboard()}`;
}
function keyboard() {
  const rows = ['qwertzuiopü', 'asdfghjklöä', '⇧yxcvbnm⌫'];
  return `<div class="kbd">${rows.map(r => `<div class="krow">${[...r].map(k => `<button data-act="key:${k}" class="${'⇧⌫'.includes(k) ? 'wide' : ''}">${k}</button>`).join('')}</div>`).join('')}
    <div class="krow"><button class="wide2">123</button><button class="space" data-act="key: ">Leerzeichen</button><button class="wide2 go" data-act="key:⏎">Los</button></div></div>`;
}

// ---------------- Routen-Vorschau
function preview() {
  const n = app.state.nav;
  return `<div class="topbar panel"><button data-act="close:preview">${ic('back', 20)}</button><span>Mein Standort → <b>${n.dest.name}</b></span></div>
    <div class="sheet panel">
      <div class="head" style="font-size:38px">${n.dest.name}</div><div class="muted" style="margin:4px 0 12px">${n.dest.sub || ''}</div>
      <div class="menu">${n.routes.map((r, i) => `<button class="item ${i === n.sel ? 'sel' : ''}" data-act="route:${i}"><span class="tl">${r.label}<small>${fmtDist(r.route.length)}${r.gain ? ` · <span class="gain">+${r.gain} % neue Straßen</span>` : ''}</small></span><span class="rtime ${i === n.sel ? 'big' : ''}">${fmtMin(r.route.seconds)}</span></button>`).join('')}</div>
      <div class="row" style="gap:10px;margin-top:14px"><button class="cta go" data-act="start">Los</button><button class="mbtn panel" style="width:58px;height:58px" data-act="toast:Teilen, Abfahrt planen, Stopps – kommt später">${ic('more', 22)}</button></div></div>`;
}

// ---------------- Navigation
function nav() {
  const s = app.state;
  if (s.nav?.arrived) return ''; // GM-009 (1.6): bei Ankunft kein Tacho, Tempolimit, Musik-Hinweis
  return `<div class="maneuver panel"><div data-hud="icon" class="micon"></div><div style="min-width:0"><div class="head mdist" data-hud="dist"></div><div class="mstreet upper" data-hud="street"></div><div class="mtext muted" data-hud="text"></div></div></div>
    ${s.speedLimit ? `<div class="limit"><span data-hud="limit"></span></div>` : ''}
    <div class="lbtns">${btn('voice', s.voice ? 'volume' : 'mute')}${btn('clip', 'clip')}</div>
    ${s.speaking && s.ducking ? `<div class="duck panel">${ic('volume', 14)} Musik leiser</div>` : ''}
    <div class="navinfo"><div class="streetbox panel upper" data-hud="cur"></div>
      <div class="row" style="gap:8px;margin-top:8px"><span class="head d2" data-hud="dist2"></span></div>
      <div class="row" style="gap:5px;margin-top:6px"><div class="bar" style="width:130px"><i data-hud="prog" style="background:var(--ok)"></i></div><div class="bar" style="width:70px"><i data-hud="time" style="background:var(--accent2)"></i></div></div></div>
    <div class="speedo panel"><b data-hud="speed"></b><small>km/h</small></div>
    <div class="navbottom panel"><div><div class="head" style="font-size:34px" data-hud="eta"></div><div class="muted small" data-hud="rem"></div></div>
      <button class="endbtn" data-act="end">Ende</button></div>`;
}
function arrival() {
  const n = app.state.nav;
  return `<div class="ios-sheet-bg"><div class="sheet panel arrival">
    <div class="muted upper small">Angekommen</div><div class="head" style="font-size:40px;margin:6px 0 14px">${n.dest.name}</div>
    <div class="stats"><div><b>${fmtDist(n.route.length)}</b><small>gefahren</small></div><div><b>${fmtMin(n.route.seconds)}</b><small>Fahrzeit</small></div><div><b class="gain">${totalPct()} %</b><small>Idstein entdeckt</small></div></div>
    <div class="row" style="gap:10px;margin-top:16px"><button class="cta go" data-act="end">Fertig</button><button class="mbtn panel" style="width:58px;height:58px" data-act="clip">${ic('share', 22)}</button></div></div></div>`;
}

// ---------------- Tabs
function explore() {
  const ds = Object.keys(app.districts).sort((a, b) => pct(b) - pct(a));
  return `<div class="exploretop panel"><div class="upper muted small b">Idstein</div><div class="row sb"><span class="head" style="font-size:56px">${totalPct()}%</span><span style="text-align:right" class="b">entdeckt<br><span class="muted small">${Math.round([...app.explored].reduce((s, k) => s + (app.edgeInfo.get(k)?.len || 0), 0) / 1000)} von ${Math.round(Object.values(app.districts).reduce((s, d) => s + d.total, 0) / 1000)} km</span></span></div></div>
    <div class="explorepanel panel"><div class="row sb" style="margin-bottom:10px"><span class="head" style="font-size:28px">Ortsteile</span><button data-act="clip" class="muted">${ic('share', 20)}</button></div>
      <div class="dlist">${ds.map(d => `<div class="drow"><div class="row sb b"><span>${d}</span><span>${pct(d)} %</span></div><div class="bar thin"><i style="width:${pct(d)}%;background:var(--ok)"></i></div></div>`).join('')}</div>
      <div class="row" style="gap:8px;margin-top:10px"><div class="tile"><small class="muted">Wochenziel</small><div class="head" style="font-size:24px">8 / 10 km</div><div class="bar thin"><i style="width:80%;background:var(--accent2)"></i></div></div>
      <div class="tile"><small class="muted">Abzeichen · 3 / 12</small><div class="row" style="gap:4px;margin-top:6px">${[['first-drive', 'gold'], ['old-town', 'silver'], ['10-km', 'bronze'], ['explorer-50', 'locked']].map(([n, t]) => `<img class="badge" src="${badgeUrl(n, t)}" alt="">`).join('')}</div></div></div></div>`;
}
function styles() {
  return `<div class="page solid"><div class="page-in">
    <div class="head" style="font-size:44px">Stile</div><div class="muted" style="margin:6px 0 16px">Karte, Symbole, Schrift und Stimme – alles neu.</div>
    ${Object.entries(STYLES).map(([k, v]) => `<button class="stylecard ${app.state.style === k ? 'sel' : ''}" data-act="style:${k}"><div class="mini" data-style="${k}"></div>
      <div class="chipman st-${k}">${ic('turnLeft', 18, 'stroke-width:3')}<span class="sf-${k}">230 m</span></div>
      <div class="card-osm">© OpenStreetMap</div>
      <div class="cardfoot"><div><div class="sf-${k} cname">${v.name}</div><small>${k === 'neon' ? 'Gratis · inkl. CarPlay' : app.state.style === k ? 'Aktiv (Vorschau)' : 'Tippen zum Testen'}</small></div><span class="dot" style="background:${v.route}"></span></div></button>`).join('')}
    <div class="muted small" style="margin:6px 0 120px">Preise folgen. Im Prototyp sind alle Stile frei.</div></div></div>`;
}
function profile() {
  const t = (k, label, sub) => `<button class="srow" data-act="toggle:${k}"><span class="tl">${label}${sub ? `<small>${sub}</small>` : ''}</span><span class="switch ${app.state[k] ? 'on' : ''}"><i></i></span></button>`;
  return `<div class="page solid"><div class="page-in">
    <div class="head" style="font-size:44px">Profil</div>
    <div class="group"><div class="gt">Navigation</div>${t('voice', 'Sprachansagen')}${t('ducking', 'Musik bei Ansagen leiser', 'statt sie zu unterbrechen')}${t('speedLimit', 'Tempolimit anzeigen')}</div>
    <div class="group"><div class="gt">Datenschutz</div>${t('friends', 'Freunde sehen meinen Standort', 'nur mit Zustimmung, jederzeit aus')}
      <div class="srow"><span class="tl">Gefahrene Strecken<small>nur auf diesem iPhone gespeichert</small></span><span class="muted">${ic('lock', 18)}</span></div>
      <button class="srow" data-act="toast:Im Prototyp nicht aktiv"><span class="tl" style="color:#ff453a">Entdeckte Karte zurücksetzen</span></button></div>
    <div class="group"><div class="gt">Über</div><div class="srow"><span class="tl">Kartendaten<small>© OpenStreetMap-Mitwirkende (ODbL)</small></span></div><div class="srow"><span class="tl">Höhendaten (Relief)<small>Terrain Tiles (AWS Open Data) · SRTM (NASA) · EU-DEM © Copernicus</small></span></div><div class="srow"><span class="tl">Version<small>Prototyp ${app.version}</small></span></div></div>
    <div style="height:120px"></div></div></div>`;
}
function friendsSheet() {
  const on = app.state.friends;
  return `<div class="ios-sheet-bg" data-act="sheet:"><div class="sheet panel" onclick="event.stopPropagation()">
    <div class="head" style="font-size:30px">Freunde auf der Karte</div>
    <div class="muted" style="margin:8px 0 16px">Freunde, die zustimmen, erscheinen als Symbole. Du teilst deinen Standort nur, solange du es erlaubst – und kannst es jederzeit beenden.</div>
    <button class="cta go" data-act="friends:${on ? 0 : 1}" style="width:100%">${on ? 'Teilen beenden' : 'Standort mit Freunden teilen'}</button>
    <button class="link" data-act="sheet:" style="width:100%;margin-top:10px">Nicht jetzt</button></div></div>`;
}

// Mini-Vorschauen in der Stil-Auswahl: echte Karte, Navigationspfeil und Route je Stil
let minis = {};
async function drawStyleMinis() {
  await ensureTextures();
  const demo = app.demoRoute ??= app.router.route(app.scene.presets.start, app.scene.presets.hexenturm);
  for (const el of root().querySelectorAll('.mini')) {
    const st = el.dataset.style; if (el.dataset.done) continue; el.dataset.done = 1;
    const v = new MapView(el); v.setTexture(app.textures[st], st);
    const d = 900, p = pointAt(demo.pts, demo.cum, d).p;
    await new Promise(r => requestAnimationFrame(r));
    const u = v.apply({ center: p, heading: smoothHeading(demo, d), scale: 0.62, tilt: 44, anchor: [0.5, 0.72] });
    drawBlips(u, v, app.scene, st, { size: 7 }); drawRoute(u, v, demo, d, st, { width: 7 }); drawDestination(u, v, demo.pts[demo.pts.length - 1], st, 7);
    drawPlayer(u, v, p, smoothHeading(demo, d), st, 11);
  }
}

// ------------------------------------------------------------ Bedienung
document.addEventListener('input', e => { if (e.target.id === 'q') { app.state.phone.query = e.target.value; app.state.phone.cat = null; renderPhone(); } });
document.addEventListener('keydown', e => { if (e.target.id === 'q' && e.key === 'Enter' && lastList[0] && !document.querySelector('#pui .kfocus')) choose(lastList[0]); });
document.getElementById('pui').addEventListener('click', async e => {
  const b = e.target.closest('[data-act]'); if (!b) return;
  const [a, v = ''] = b.dataset.act.split(/:(.*)/s);
  const s = app.state;
  switch (a) {
    case 'go': set({ phone: { screen: v } }); break;
    case 'tab': set({ phone: { tab: v, overlay: null, sheet: null } }); break;
    case 'open': set({ phone: { overlay: v, query: '', cat: null } }); setTimeout(() => document.getElementById('q')?.focus(), 0); break;
    case 'close': if (v === 'preview') set({ nav: null, phone: { overlay: 'search' } }); else set({ phone: { overlay: null, cat: null } }); break;
    case 'cat': set({ phone: { overlay: 'search', cat: v, query: '' } }); break;
    case 'dest': choose(presetDest(v)); break;
    case 'pick': choose(lastList[+v]); break;
    case 'key': {
      if (v === '⌫') s.phone.query = s.phone.query.slice(0, -1);
      else if (v === '⏎') { if (lastList[0]) return choose(lastList[0]); }
      else if (v !== '⇧') s.phone.query += v;
      s.phone.cat = null; renderPhone(); break;
    }
    case 'route': selectRoute(+v); break;
    case 'start': startNav(); break;
    case 'end': endNav(); break;
    case 'voice': set({ voice: !s.voice }); if (!s.voice) speechSynthesis.cancel(); break;
    case 'clip': toast('Clip der letzten 10 s gespeichert'); break;
    case 'toast': toast(v); break;
    case 'style': await useStyle(v); break;
    case 'toggle': set({ [v]: !s[v] }); break;
    case 'sheet': set({ phone: { sheet: v || null } }); break;
    case 'friends': set({ friends: v === '1', phone: { sheet: null } }); toast(v === '1' ? 'Freunde sehen dich jetzt' : 'Teilen beendet'); break;
    case 'recenter': recenter('phone'); break;
    case 'legend': set({ legend: !s.legend, highlight: null }); break;
    case 'hl': set({ highlight: s.highlight === v ? null : v }); break;
    case 'zoom': zoom('phone', v === 'in' ? 1.4 : 1 / 1.4); break;
  }
});
function choose(dest) {
  planTo(dest);
  if (!app.state.nav) return toast('Keine Route gefunden');
  set({ phone: { overlay: 'preview' } });
}

// GM-009 (1.1): „© OpenStreetMap-Mitwirkende“ auf jedem Screen, Lage je nach Bildschirm (über Tab-Leiste, Tastatur oder im Blatt)
function osm() {
  const p = app.state.phone, n = app.state.nav;
  if (p.screen === 'splash') return '';
  let pos = 'sheet';
  if (p.screen === 'main') {
    if (p.sheet) pos = 'sheet';
    else if (p.overlay === 'search') pos = 'kb';
    else if (p.overlay === 'preview') pos = 'sheet';
    else if (p.overlay === 'nav') pos = n?.arrived ? 'sheet' : 'nav';
    else pos = 'tabs';
  }
  return `<div class="osm osm-${pos}">© OpenStreetMap-Mitwirkende</div>`;
}
