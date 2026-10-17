// CarPlay-Oberfläche. Systemteile (Leiste, Tasten, Listen, Abbiegekarte, Routen-Vorschau) sind
// CPMapTemplate/CPListTemplate/CPTripPreview nachgebaut – in der App zeichnet iOS sie selbst.
// Unser Teil: nur die Karte im carWindow plus kleine Einblendungen darin. Größe immer aus dem Fenster berechnen.
import { app, set, useStyle, planTo, currentLimit, selectRoute, startNav, endNav, nextManeuver, segSpeed, remaining, currentStreet, pct, zoom, recenter } from './app.js';
import { cpic as ic, manIc } from './icons.js';
import { fmtDist, fmtMin, smoothHeading, pointAt } from './route.js';
import { STYLES } from './map.js';
import { panBy } from './keys.js';
import { fit, category } from './phone.js';

const root = () => document.getElementById('cui');
let list = [];

export function carCamera(view) {
  const s = app.state, n = s.nav, c = s.car;
  if (n && n.active && n.arrived) return { mode: 'arrived', ...fit(n.route.pts, view, 60, 30, 30, 80) };
  if (n && n.active) {
    const r = n.route, pos = pointAt(r.pts, r.cum, n.progress).p;
    return { mode: 'nav', center: pos, heading: smoothHeading(r, n.progress), scale: 1.8, tilt: 0, anchor: [0.62, 0.6] }; // GM-008: Nutzervorlage – flach von oben wie ein Spiel-Radar, nah, Fahrtrichtung oben
  }
  const [W] = view.size();
  if (c.screen === 'preview' && n) return { mode: 'preview', ...fit(n.routes.map(r => r.route.pts).flat(), view, 70, 20, Math.min(330, W * 0.42) + 30, 80) };
  const b = s.browse.car;
  return { mode: 'browse', center: b.center, heading: 0, scale: b.scale, tilt: 0, anchor: [0.5, 0.55] };
}

let last = '';
export function carHud() {
  const n = app.state.nav; if (!n || !n.active || app.state.car.screen !== 'nav') return;
  const m = nextManeuver(), rem = remaining(), eta = new Date(Date.now() + rem.s * 1000);
  const vals = { dist: fmtDist(m.at - n.progress), street: m.kind === 'destination' ? n.dest.name : m.street, icon: m.kind, eta: eta.getHours() + ':' + String(eta.getMinutes()).padStart(2, '0'), rem: `${fmtMin(rem.s)} · ${fmtDist(rem.m)}`, cur: currentStreet() || '—', limit: currentLimit(), prog: n.progress / n.route.length };
  const ms = n.route.maneuvers, nx = ms[ms.indexOf(m) + 1];
  vals.then = nx ? (nx.kind === 'destination' ? `danach Ziel` : `danach ${nx.text.toLowerCase()} · ${nx.street}`) : '';
  const k = JSON.stringify(vals); if (k === last) return; last = k;
  const $ = id => root().querySelector(`[data-hud=${id}]`); if (!$('dist')) return;
  $('dist').textContent = vals.dist; $('street').textContent = vals.street; $('icon').innerHTML = manIc(vals.icon, 54, true);
  $('eta').textContent = vals.eta; $('rem').textContent = vals.rem; $('cur').textContent = vals.cur; $('then').textContent = vals.then;
  $('limit').textContent = vals.limit; $('prog').style.width = vals.prog * 100 + '%';
}

export function renderCar() {
  const s = app.state, c = s.car; last = '';
  document.querySelector('.carmain').classList.toggle('off', !s.carConnected);
  if (!s.carConnected) { root().innerHTML = `<div class="cp-off"><div class="cp-logo">CarPlay</div><div>Nicht verbunden</div></div>`; return; }
  let h = '';
  if (c.screen === 'map') h = mapTpl();
  else if (c.screen === 'dest') h = listTpl('Ziele', destItems(), 'map');
  else if (c.screen === 'cat') h = listTpl(c.title, list, 'dest');
  else if (c.screen === 'styles') h = listTpl('Stil', Object.entries(STYLES).map(([k, v]) => ({ name: v.name, sub: k === 'neon' ? 'Gratis' : 'Vorschau', icon: s.style === k ? 'check' : 'style', act: `style:${k}` })), 'map');
  else if (c.screen === 'preview' && s.nav) h = previewTpl();
  else if (c.screen === 'arrival' && s.nav) h = navbar([], [['end', 'close', 'Beenden']]) + alertTpl() + '<div class="cp-attrib">© OpenStreetMap-Mitwirkende</div>'; // GM-009 (1.6)
  else if (c.screen === 'nav' && s.nav) h = navTpl();
  else h = mapTpl();
  h = h.replace(/class="head([^"]*)" style="font-size:(\d+)px/g, (m, c, n) => `class="head${c}" style="font-size:calc(${n}px * var(--hs))`);
  root().innerHTML = h;
}

const navbar = (left, right) => `<div class="cp-navbar"><div>${left.map(([a, i, t]) => `<button data-act="${a}"${i === 'back' ? ' class="back"' : ''}>${ic(i, 18)}${t ? `<span>${t}</span>` : ''}</button>`).join('')}</div><div>${right.map(([a, i, t]) => `<button data-act="${a}">${ic(i, 18)}${t ? `<span>${t}</span>` : ''}</button>`).join('')}</div></div>`;
const mapButtons = (pan = false) => `<div class="cp-mapbtns">${[['zoom:in', 'plus'], ['zoom:out', 'minus'], ...(pan ? [['pan:on', 'pan']] : []), ['recenter', 'locate']].map(([a, i]) => `<button data-act="${a}">${ic(i, 22)}</button>`).join('')}</div>`;
function mapTpl() {
  const d = 'Altstadt';
  // Verschiebe-Modus wie CPMapTemplate.showPanningInterface: vier Pfeile, Pfeiltasten bewegen die Karte
  if (app.state.car.pan) return navbar([], [['pan:off', 'check', 'Fertig']]) + `<div class="cp-pan">${[['move:0,-1', 'up', 'top'], ['move:0,1', 'down', 'bottom'], ['move:-1,0', 'left', 'left'], ['move:1,0', 'right', 'right']].map(([a, i, c]) => `<button class="${c}" data-act="${a}">${ic(i, 26)}</button>`).join('')}</div><div class="cp-cross"></div><div class="cp-attrib">© OpenStreetMap-Mitwirkende</div>`;
  return navbar([['go:dest', 'search', 'Ziele'], ['go:styles', 'layers', 'Stil']], [['friends', 'friends', '']]) + mapButtons(true) +
    `<div class="scalebar cp" data-scale></div><div class="cp-district panel"><div class="row sb"><span class="upper b">Idstein ${d}</span><span class="head">${pct(d)}%</span></div><div class="bar thin"><i style="width:${pct(d)}%;background:var(--ok)"></i></div></div><div class="cp-attrib">© OpenStreetMap-Mitwirkende</div>`;
}
function destItems() {
  const p = app.scene.presets;
  const items = [{ name: 'Zuhause', sub: 'Lanaer Straße', p: p.home, icon: 'home' }, { name: 'Arbeit', sub: 'Black-und-Decker-Straße', p: p.work, icon: 'work' },
    ...(app.state.recents.length ? app.state.recents : [{ name: 'Hexenturm', sub: 'Sehenswürdigkeit', p: p.hexenturm, icon: 'star' }]).map(r => ({ ...r, icon: 'clock' })),
    { name: 'Tankstellen', sub: 'In der Nähe', icon: 'fuel', act: 'cat:fuel' }, { name: 'Parkplätze', sub: 'In der Nähe', icon: 'parking', act: 'cat:parking' }];
  list = items; return items;
}
function listTpl(title, items, back) {
  list = items;
  return `<div class="cp-list"><div class="cp-lhead"><button data-act="go:${back}">${ic('back', 20)}<span>${back === 'map' ? 'Karte' : 'Zurück'}</span></button><b>${title}</b><span></span></div>
    ${items.map((r, i) => `<button class="cp-row" data-act="${r.act || 'pick:' + i}"><span class="cp-ricon">${ic(r.icon, 22)}</span><span class="tl">${r.name}<small>${r.sub || ''}${r.p ? ' · ' + fmtDist(Math.hypot(r.p[0] - app.start[0], r.p[1] - app.start[1])) : ''}</small></span>${ic('chevron', 16)}</button>`).join('')}<div class="cp-list-osm">Ortsdaten © OpenStreetMap-Mitwirkende</div></div>`;
}
function previewTpl() {
  const n = app.state.nav;
  return navbar([['go:dest', 'back', 'Zurück']], []) + `<div class="cp-trip"><div class="b big">${n.dest.name}</div><div class="muted small">${n.dest.sub || ''}</div>
    ${n.routes.slice(0, 3).map((r, i) => `<button class="cp-opt ${i === n.sel ? 'sel' : ''}" data-act="route:${i}"><span>${r.label}</span><span>${fmtMin(r.route.seconds)} · ${fmtDist(r.route.length)}</span></button>`).join('')}
    <button class="cp-go" data-act="start">Los</button></div><div class="cp-attrib">© OpenStreetMap-Mitwirkende</div>`;
}
function navTpl() {
  return navbar([], [['voice', app.state.voice ? 'volume' : 'mute', ''], ['end', 'close', 'Beenden']]) + mapButtons() +
    `<div class="cp-maneuver"><div data-hud="icon"></div><div style="min-width:0"><div class="b" style="font-size:30px" data-hud="dist"></div><div class="cp-street" data-hud="street"></div></div></div>
    <div class="cp-eta"><b data-hud="eta"></b><span data-hud="rem"></span></div>
    <div class="cp-ours"><div class="streetbox panel" data-hud="cur"></div><div class="then panel" data-hud="then"></div><div class="bar thin" style="width:150px;margin-top:6px"><i data-hud="prog" style="background:var(--ok)"></i></div></div>
    ${app.state.speedLimit ? '<div class="limit cp"><span data-hud="limit"></span></div>' : ''}<div class="cp-attrib">© OpenStreetMap-Mitwirkende</div>`;
}
const alertTpl = () => `<div class="cp-alert-bg"><div class="cp-alert"><b>Ziel erreicht</b><span>${app.state.nav.dest.name}</span><button data-act="end">OK</button></div></div>`;

document.getElementById('cui').addEventListener('click', async e => {
  const b = e.target.closest('[data-act]'); if (!b) return;
  const [a, v = ''] = b.dataset.act.split(/:(.*)/s);
  switch (a) {
    case 'go': if (v === 'dest' && app.state.nav && !app.state.nav.active) set({ nav: null }); set({ car: { screen: v } }); break;
    case 'cat': { const items = category(v).map(r => ({ ...r })); list = items; set({ car: { screen: 'cat', title: v === 'fuel' ? 'Tankstellen' : 'Parkplätze' } }); list = items; renderCarList(items); break; }
    case 'pick': { const d = list[+v]; if (!d?.p) return; planTo(d).then(ok => ok && set({ car: { screen: 'preview' } })); break; }
    case 'route': selectRoute(+v); break;
    case 'start': startNav(); break;
    case 'end': endNav(); break;
    case 'voice': set({ voice: !app.state.voice }); break;
    case 'style': await useStyle(v); set({ car: { screen: 'map' } }); break;
    case 'friends': set({ friends: !app.state.friends }); break;
    case 'zoom': zoom('car', v === 'in' ? 1.4 : 1 / 1.4); break;
    case 'recenter': recenter('car'); break;
    case 'pan': set({ car: { pan: v === 'on' } }); break;
    case 'move': { const [dx, dy] = v.split(',').map(Number); panBy('car', dx, dy); break; }
  }
});
function renderCarList(items) { root().innerHTML = listTpl(app.state.car.title, items, 'dest'); }
