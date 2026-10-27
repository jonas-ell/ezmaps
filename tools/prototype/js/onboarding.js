// GM-031: Onboarding und weitere Screens in den vier Richtungen (A HUD, B Glas, C Minimal, D Sticker).
// Ein Satz Bildschirme (gleiches HTML), das Aussehen kommt nur aus onboarding.css je Richtung.
import { MapView, renderTexture, drawRoute, drawBlips, drawPlayer, drawDestination, STYLES } from './map.js';
import { Router } from './route.js';
import { loadAssets, appIconUrl } from './assets.js';
import { drawParkedCar } from './vorschau.js';

const $ = h => { const t = document.createElement('template'); t.innerHTML = h.trim(); return t.content.firstElementChild; };
const main = document.getElementById('dz');
const tex = {};
let scene, R;

const icon = (d, s = 20, c = 'currentColor', w = 2.2) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="${c}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
const I = { loc: '<path d="M12 2 19 21 12 17 5 21z"/>', pin: '<path d="M12 22s7-7.5 7-12a7 7 0 0 0-14 0c0 4.5 7 12 7 12z"/><circle cx="12" cy="10" r="2.5"/>', lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>', bell: '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 8 3 8H3s3-1 3-8"/><path d="M10 21h4"/>', car: '<path d="M5 17h14v-5l-2-5H7l-2 5z"/><circle cx="8" cy="17" r="2"/><circle cx="16" cy="17" r="2"/>', home: '<path d="M3 11 12 4l9 7v9h-6v-6H9v6H3z"/>', work: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V4h8v3"/>', search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>', clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>', fuel: '<path d="M4 21V4h9v17M4 11h9M13 8l4 3v7a2 2 0 0 0 4 0V9"/>', p: '<path d="M7 21V3h6a5 5 0 0 1 0 10H7"/>', food: '<path d="M7 3v18M4 3v6a3 3 0 0 0 6 0V3M17 21V3c-2 2-3 5-3 8h3"/>', share: '<path d="M12 3v13M7 8l5-5 5 5"/><path d="M5 13v7h14v-7"/>', star: '<path d="m12 3 2.8 5.8 6.2.9-4.5 4.4 1 6.2L12 17.3 6.5 20.3l1-6.2L3 9.7l6.2-.9z"/>', vol: '<path d="M4 9v6h4l5 4V5L8 9z"/><path d="M16 8a5 5 0 0 1 0 8"/>', shield: '<path d="M12 3 4 6v6c0 5 3.5 8 8 9 4.5-1 8-4 8-9V6z"/>', chev: '<path d="m9 6 6 6-6 6"/>', mic: '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>' };
const steps = n => `<div class="steps">${[1, 2, 3].map(i => `<i class="${i <= n ? 'on' : ''}"></i>`).join('')}</div>`;

function phone(row, cls, cap) {
  const w = $(`<div><div class="dph ${cls}"><div class="fill"></div><div class="isl"></div><div class="sb">9:41</div><div class="hbar"></div></div><div class="cap">${cap}</div></div>`);
  row.append(w); return w.firstElementChild;
}
function mapInto(el, style, cam, draw) { const v = new MapView(el); v.setTexture(tex[style], style); const u = v.apply(cam); draw && draw(u, v); return v; }
const browse = (el, style = 'neon', scale = 0.45) => mapInto(el, style, { center: [-500, 300], heading: 0, scale, tilt: 0, anchor: [0.5, 0.5] }, (u, v) => { drawBlips(u, v, scene, style, {}); drawPlayer(u, v, R.pts[0], 0, style, 12); });

// ------------------------------------------------------------ Bildschirme (gleich für alle Richtungen)
const SCREENS = [
  ['1 Willkommen', 'Karte im Hintergrund läuft langsam, App-Name groß. Kein Text-Wall, ein Knopf.', ph => {
    browse(ph.querySelector('.fill'), 'neon', 0.3);
    ph.append($(`<div class="f"><div class="dim" style="background:linear-gradient(rgba(0,0,0,.1),rgba(0,0,0,.25) 40%,rgba(0,0,0,.92) 75%)"></div><div class="grow"></div>
      <img src="${appIconUrl}" style="width:76px;height:76px;border-radius:18px;margin-bottom:16px">
      <div class="logo">EzMaps</div><div class="sub" style="font-size:17px">Deine Stadt als Spielwelt. Echte Navigation für ganz Deutschland, auch in CarPlay.</div>
      <div class="btn" style="margin-top:24px">Los geht's</div><div class="btn2">Ich habe schon EzMaps</div></div>`));
  }],
  ['2 Standort (vor der iOS-Frage)', 'Erklärt erst den Nutzen, dann kommt die iOS-Abfrage. Hintergrund nur „Beim Verwenden“, Hintergrund erst bei der ersten Fahrt.', ph => {
    browse(ph.querySelector('.fill'), 'neon', 0.9);
    ph.append($(`<div class="f"><div class="dim" style="background:rgba(0,0,0,.72)"></div>${steps(1)}<div class="kick">Schritt 1 von 3</div>
      <div class="h1">Wo bist du gerade?</div><div class="sub">Damit EzMaps dich navigiert und deine Stadt aufdeckt.</div>
      <div class="grow" style="display:grid;place-items:center"><div class="bigicon" style="color:var(--acc)">${icon(I.pin, 110, 'currentColor', 1.6)}</div></div>
      <div class="card"><div class="li"><span class="ic">${icon(I.loc, 18)}</span><span>Karte zeigt dich<small>Nur während die App offen ist</small></span></div><div class="li"><span class="ic">${icon(I.vol, 18)}</span><span>Ansagen laufen weiter<small>Auch bei gesperrtem iPhone, nur während einer Fahrt</small></span></div></div>
      <div class="btn">Standort erlauben</div><div class="btn2">Später</div></div>`));
  }],
  ['3 Stil wählen', 'Echte Karten-Vorschau je Stil. Klassik gratis, Premium mit „Testen“.', ph => {
    ph.querySelector('.fill').style.background = '#0b0b0d';
    const f = $(`<div class="f">${steps(2)}<div class="kick">Schritt 2 von 3</div><div class="h1">Wie soll deine Welt aussehen?</div><div class="sub">Du kannst jederzeit wechseln.</div>
      <div class="grid2" style="margin-top:16px">${['classic', 'neon', 'western', 'pixel'].map((s, i) => `<div class="tile ${s === 'classic' ? 'sel' : ''}"><div class="m" data-s="${s}"></div><span class="pill ${STYLES[s].free ? '' : 'pro'}">${STYLES[s].free ? 'GRATIS' : 'PREMIUM'}</span><div class="t">${STYLES[s].name}<small>${STYLES[s].free ? 'Inklusive' : 'Kostenlos testen'}</small></div></div>`).join('')}</div>
      <div class="grow"></div><div class="btn">Weiter mit Klassik</div></div>`);
    ph.append(f);
    requestAnimationFrame(() => f.querySelectorAll('.m').forEach(m => { const s = m.dataset.s; mapInto(m, s, { center: [40, -20], heading: 0.4, scale: 1.1, tilt: 45, anchor: [0.5, 0.6] }, (u, v) => { drawRoute(u, v, R, 0, s, { width: 6 }); drawPlayer(u, v, R.pts[0], 0, s, 9); }); }));
  }],
  ['4 Zuhause und Arbeit', 'Für Widgets, Siri und Schnellziele. Überspringbar.', ph => {
    browse(ph.querySelector('.fill'), 'neon', 0.6);
    ph.append($(`<div class="f"><div class="dim" style="background:rgba(0,0,0,.78)"></div>${steps(3)}<div class="kick">Schritt 3 von 3</div><div class="h1">Wohin fährst du oft?</div><div class="sub">Dann reicht später ein Tipp oder „Hey Siri, nach Hause“.</div>
      <div style="display:flex;flex-direction:column;gap:10px;margin-top:20px"><div class="field">${icon(I.home, 20)}<span>Lanaer Straße 12, Idstein</span></div><div class="field">${icon(I.work, 20)}<span style="opacity:.6">Arbeit hinzufügen</span></div></div>
      <div class="card" style="margin-top:16px"><div class="li"><span class="ic">${icon(I.vol, 18)}</span><span>Sprachansagen<small>Musik wird dabei nur leiser</small></span><span class="toggle" style="margin-left:auto"></span></div></div>
      <div class="grow"></div><div class="btn">Fertig, los!</div><div class="btn2">Überspringen</div></div>`));
  }],
  ['5 Suche', 'Leere Suche ist nützlich: Kategorien, Zuletzt, Favoriten. Tastatur unten.', ph => {
    ph.querySelector('.fill').style.background = '#0b0b0d';
    ph.append($(`<div class="f" style="padding-top:60px"><div class="field" style="border:1.5px solid var(--acc)">${icon(I.search, 20)}<span>Wohin?</span><span style="margin-left:auto">${icon(I.mic, 18)}</span></div>
      <div class="grid2" style="margin-top:14px;grid-template-columns:repeat(4,1fr);gap:8px">${[['fuel', 'Tanken'], ['p', 'Parken'], ['food', 'Essen'], ['star', 'Favoriten']].map(([i, t]) => `<div class="card" style="padding:10px 4px;text-align:center;font:700 12px Inter"><div style="display:grid;place-items:center;margin-bottom:6px;color:var(--acc)">${icon(I[i], 22)}</div>${t}</div>`).join('')}</div>
      <div class="kick" style="margin-top:18px">Zuletzt</div>
      <div class="card"><div class="li"><span class="ic">${icon(I.home, 18)}</span><span>Zuhause<small>Lanaer Straße · 14 Min</small></span><span class="r">2,1 km</span></div><div class="li"><span class="ic">${icon(I.clock, 18)}</span><span>Hexenturm<small>Altstadt, Idstein</small></span><span class="r">1,9 km</span></div><div class="li"><span class="ic">${icon(I.clock, 18)}</span><span>Römerberg<small>Frankfurt am Main</small></span><span class="r">33 km</span></div></div>
      <div class="grow"></div><div style="height:250px;margin:0 -22px -34px;background:#2b2b2e;opacity:.9;display:grid;place-items:center;font:500 12px Inter;color:#888">Tastatur</div></div>`));
  }],
  ['6 Ankunft', 'Belohnung nur im Stand: neue Straßen, Stufe, Foto teilen.', ph => {
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity; for (const [x, y] of R.pts) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
    mapInto(ph.querySelector('.fill'), 'neon', { center: [(x0 + x1) / 2, (y0 + y1) / 2], heading: 0, scale: Math.min(320 / (x1 - x0), 300 / (y1 - y0)), tilt: 0, anchor: [0.5, 0.28] }, (u, v) => { drawRoute(u, v, R, 0, 'neon', { width: 7 }); drawDestination(u, v, R.pts[R.pts.length - 1], 'neon', 8); });
    ph.append($(`<div class="f onmap"><div class="grow"></div><div class="sheet card" style="padding:18px">
      <div class="kick">Angekommen · 9:47</div><div class="h1">Hexenturm</div>
      <div class="stat" style="margin-top:14px"><div>1,9 km<small>gefahren</small></div><div>6 Min<small>Fahrzeit</small></div><div style="color:#58b05f">+12 %<small>neue Straßen</small></div></div>
      <div style="margin-top:14px;font:700 13px Inter;display:flex;justify-content:space-between"><span>Idstein-Kenner · Stufe 3</span><span style="opacity:.6">340 / 500</span></div><div class="xp" style="margin-top:6px"><i style="width:68%"></i></div>
      <div style="display:flex;gap:8px;margin-top:6px"><div class="btn" style="flex:1">Fertig</div><div class="btn" style="width:56px;background:rgba(255,255,255,.12)">${icon(I.share, 20)}</div></div></div></div>`));
  }],
  ['7 Einstellungen', 'Gruppiert, kurz, mit Stil oben. Rechtliches unten.', ph => {
    ph.querySelector('.fill').style.background = '#0b0b0d';
    ph.append($(`<div class="f" style="padding-top:60px"><div class="h1">Einstellungen</div>
      <div class="card" style="margin-top:16px;display:flex;gap:12px;align-items:center"><canvas width="88" height="120" style="width:44px;height:60px" id="setcar"></canvas><div><div style="font:800 17px Inter">Neon City</div><div style="font:500 13px Inter;opacity:.6">Stil ändern</div></div><span style="margin-left:auto;opacity:.5">${icon(I.chev, 18)}</span></div>
      <div class="kick" style="margin-top:18px">Navigation</div>
      <div class="card"><div class="li"><span class="ic">${icon(I.vol, 18)}</span><span>Stimme<small>Helena · Erweitert</small></span><span class="r">${icon(I.chev, 16)}</span></div><div class="li"><span class="ic">${icon(I.car, 18)}</span><span>Autobahn meiden</span><span class="toggle off" style="margin-left:auto"></span></div><div class="li"><span class="ic">${icon(I.shield, 18)}</span><span>Tempolimit anzeigen</span><span class="toggle" style="margin-left:auto"></span></div></div>
      <div class="kick" style="margin-top:18px">Orte</div>
      <div class="card"><div class="li"><span class="ic">${icon(I.home, 18)}</span><span>Zuhause<small>Lanaer Straße 12</small></span><span class="r">${icon(I.chev, 16)}</span></div><div class="li"><span class="ic">${icon(I.work, 18)}</span><span>Arbeit<small>Nicht festgelegt</small></span><span class="r">${icon(I.chev, 16)}</span></div></div>
      <div class="grow"></div><div style="font:500 11px Inter;opacity:.5;text-align:center">Datenschutz · Impressum · © OpenStreetMap-Mitwirkende</div></div>`));
    const c = ph.querySelector('#setcar').getContext('2d'); c.scale(2, 2); const fake = { project: () => [22, 32, 1], cam: { heading: 0, tilt: 0 } }; drawPlayer(c, fake, [0, 0], 0, 'neon', 16);
  }],
];

async function boot() {
  await loadAssets();
  scene = await (await fetch('data/idstein.json')).json();
  R = new Router(scene.graph).route(scene.presets.start, scene.presets.hexenturm);
  for (const s of ['classic', 'neon', 'western', 'pixel']) tex[s] = await renderTexture(scene, s);
  await document.fonts.ready;
  const dirs = [['A', 'A · HUD', 'Schmale Fettschrift, abgeschrägte Ecken, Zahlen in Monospace.'], ['B', 'B · Glas', 'Weiche Glasflächen, runde Ecken, Verlauf-Knopf.'], ['C', 'C · Minimal', 'Schwarz, Pillen, wenig Schmuck.'], ['D', 'D · Sticker', 'Weiße Karten mit dicker Kontur, Gelb und Lila.']];
  for (const [cls, t, p] of dirs) {
    const s = $(`<section class="dsec"><h2>${t}</h2><p>${p}</p><div class="drow"></div></section>`); main.append(s);
    const row = s.lastElementChild;
    for (const [name, cap, fn] of SCREENS) fn(phone(row, cls, `<b>${name}</b> · ${cap}`));
  }
  window.__ready = true;
}
boot().catch(e => { console.error(e); document.body.insertAdjacentHTML('beforeend', `<pre style="color:#f66">${e.stack}</pre>`); });
