// GM-033: weitere Screens im Glas-Design (Shop, Stil testen, Freigeschaltet, Meine Fahrten, Favoriten, Parkplatz,
// Baustelle in der Navigation, Fehlerzustände). Nur zum Zeigen; Umsetzung siehe CHANGELOG GM-033.
import { MapView, renderTexture, renderRegion, drawRoute, drawBlips, drawPlayer, drawDestination, STYLES } from './map.js';
import { Router, pointAt, smoothHeading } from './route.js';
import { loadAssets } from './assets.js';
import { toLocal } from './geo.js';
import { drawParkedCar, drawWork } from './vorschau.js';
import { placeAttribution } from './glasfix.js';

const $ = h => { const t = document.createElement('template'); t.innerHTML = h.trim(); return t.content.firstElementChild; };
const main = document.getElementById('dz');
const tex = {};
let scene, router, R, works;

const icon = (d, s = 20, c = 'currentColor', w = 2.2) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="${c}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
const I = { back: '<path d="m15 6-6 6 6 6"/>', x: '<path d="M6 6l12 12M18 6 6 18"/>', check: '<path d="m5 12 5 5 9-10"/>', star: '<path d="m12 3 2.8 5.8 6.2.9-4.5 4.4 1 6.2L12 17.3 6.5 20.3l1-6.2L3 9.7l6.2-.9z"/>', share: '<path d="M12 3v13M7 8l5-5 5 5"/><path d="M5 13v7h14v-7"/>', walk: '<circle cx="13" cy="4" r="2"/><path d="m9 21 2-6 3 3v3M7 12l3-4 4 1 3 3M10 8l-1 5"/>', wifi: '<path d="M2 9a15 15 0 0 1 20 0M5 13a10 10 0 0 1 14 0M8.5 16.5a5 5 0 0 1 7 0"/><path d="m3 3 18 18"/>', gps: '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/><circle cx="12" cy="12" r="7"/>', loc: '<path d="M12 2 19 21 12 17 5 21z"/>', gear: '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9 7 7M17 17l2.1 2.1M4.9 19.1 7 17M17 7l2.1-2.1"/>', search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>', mic: '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>', home: '<path d="M3 11 12 4l9 7v9h-6v-6H9v6H3z"/>', reroute: '<path d="M4 12a8 8 0 0 1 14-5.3M20 12a8 8 0 0 1-14 5.3"/><path d="M18 3v4h-4M6 21v-4h4"/>' };
const limit = (n, s = 56) => `<div style="width:${s}px;height:${s}px;border-radius:50%;background:#fff;border:${s * .11}px solid #e30613;color:#000;display:grid;place-items:center;font:800 ${s * .38}px Inter">${n}</div>`;
const arrow = (s = 44) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M7 21V10a4 4 0 0 1 4-4h8"/><path d="m15 2 4 4-4 4"/></svg>`;
const osm = b => `<div class="osm" style="right:16px;bottom:${b}px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`;

function phone(row, cap) {
  const w = $(`<div><div class="dph B"><div class="fill"></div><div class="isl"></div><div class="sb">9:41</div><div class="hbar"></div></div><div class="cap">${cap}</div></div>`);
  row.append(w); return w.firstElementChild;
}
function mapInto(el, style, cam, draw) { const v = new MapView(el); v.setTexture(tex[style], style); const u = v.apply(cam); draw && draw(u, v); return v; }
function fit(pts, el, padW = 300, padH = 300, ay = 0.35) {
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity; for (const [x, y] of pts) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  return { center: [(x0 + x1) / 2, (y0 + y1) / 2], heading: 0, scale: Math.min(padW / Math.max(80, x1 - x0), padH / Math.max(80, y1 - y0)), tilt: 0, anchor: [0.5, ay] };
}
function navMap(el, style, route, d) {
  const at = pointAt(route.pts, route.cum, d).p, hd = smoothHeading(route, d), cam = { center: at, heading: hd, scale: 3.2, tilt: 58, anchor: [0.5, 0.66] };
  const v = new MapView(el); v.setTexture(tex[style], style);
  const g = { x0: at[0] - 550, y0: at[1] - 800, w: 1100, h: 1100 }; v.setDetail(renderRegion(scene, style, g, 4), g, 4, style);
  const u = v.apply(cam); drawRoute(u, v, route, d, style); drawBlips(u, v, scene, style, { size: 11 }); drawPlayer(u, v, at, hd, style, 16); return { u, v };
}
const sheet = inner => `<div class="f" style="padding:0"><div style="flex:1"></div><div class="sheet" style="margin:0 10px 22px">${inner}</div></div>`;

// ------------------------------------------------------------ Screens
const SCREENS = [
  ['Shop (EzMaps Plus)', 'Ein Abo „Plus“ für alle Stile. Psychologie: teurer Einmalkauf oben als Anker, Jahresabo vorausgewählt mit Preis pro Monat, Gratis-Woche, Monatsabo als Einstieg. Apple-Pflichten: Preis und Verlängerung klar, Kündigen-Hinweis, Bedingungen, Datenschutz, Wiederherstellen.', ph => {
    ph.querySelector('.fill').style.background = '#0b0b0d';
    const styles = [['neon', '<span class="nname">Neon City</span>'], ['western', '<span class="wname">Wild West</span>'], ['pixel', '<span class="pname">Pixel Quest</span>'], ['toy', '<span class="tname">Toy Town</span>']];
    const f = $(`<div class="f" style="padding-top:56px"><div style="display:flex;justify-content:space-between;align-items:center"><div class="h1" style="font-size:28px">EzMaps <span style="color:#c27bff">Plus</span></div><div class="g round" style="width:36px;height:36px">${icon(I.x, 16)}</div></div>
      <div class="sub" style="margin-top:2px">Alle Stile, auf dem iPhone und in CarPlay. Jeder neue Stil inklusive.</div>
      <div class="sgrid">${styles.map(([s, n]) => `<div class="stile" style="height:138px"><div class="m" data-s="${s}"></div><span>${n}</span></div>`).join('')}</div>
      <div class="grow"></div>
      <div class="plan"><span><b>Für immer</b><small>einmal zahlen</small></span><span class="pp"><b>79,99 €</b></span></div>
      <div class="plan on"><span class="tag">Beliebt · spare 50 %</span><span><b>Jährlich</b><small>7 Tage gratis, dann 29,99 € im Jahr</small></span><span class="pp"><b>2,50 €</b><small>pro Monat</small></span></div>
      <div class="plan"><span><b>Monatlich</b><small>jederzeit kündbar</small></span><span class="pp"><b>4,99 €</b><small>pro Monat</small></span></div>
      <div class="btn" style="margin-top:12px">7 Tage gratis testen</div>
      <div class="fine">Danach 29,99 € pro Jahr, verlängert sich automatisch. Kündigen jederzeit in den iPhone-Einstellungen, spätestens 24 h vor Ablauf. Klassik und Navigation bleiben gratis.</div>
      <div class="link">Nur einen Stil kaufen ›</div><div class="link" style="margin-top:4px;opacity:.75">Käufe wiederherstellen · Bedingungen · Datenschutz</div></div>`);
    ph.append(f);
    requestAnimationFrame(() => f.querySelectorAll('.m').forEach(m => { const s = m.dataset.s; mapInto(m, s, { center: [40, -20], heading: 0.4, scale: 0.8, tilt: 45, anchor: [0.5, 0.6] }, (u, v) => { drawRoute(u, v, R, 0, s, { width: 6 }); drawPlayer(u, v, R.pts[0], 0, s, 9); }); }));
  }],
  ['Einzelkauf', 'Tipp auf eine Stil-Kachel oder „Nur einen Stil kaufen“. Einzelstil absichtlich teuer (Neon 39,99 €, andere 29,99 €): Plus steht daneben als klar bessere Wahl. Einmalkauf, gehört dir für immer.', ph => {
    const el = ph.querySelector('.fill'); el.style.background = '#0b0b0d';
    const f = $(`<div class="f" style="padding:0"><div class="hero" style="height:430px;border-radius:0"><div class="m" data-s="neon"></div><div class="t" style="padding:60px 22px 18px"><b style="font-size:40px"><span class="nname">Neon City</span></b><small style="font-size:14px">Dunkle Open-World-Karte · Neon-Route · auch in CarPlay</small></div></div>
      <div style="position:absolute;left:16px;top:58px" class="g round">${icon(I.back, 20)}</div>
      <div style="padding:16px 22px 34px;display:flex;flex-direction:column;flex:1">
      <div style="display:flex;gap:8px;flex-wrap:wrap"><span class="chip">Eigene Symbole</span><span class="chip">Nachtmodus</span><span class="chip">Baustellen im Stil</span></div>
      <div class="grow"></div>
      <div class="plan on" style="margin-top:0"><span class="tag">Besser · alle 4 Stile</span><span><b>Mit Plus</b><small>alle Stile + jeder neue Stil</small></span><span class="pp"><b>2,50 €</b><small>pro Monat</small></span></div>
      <div class="btn" style="margin-top:12px">Plus 7 Tage gratis testen</div>
      <div class="btn2" style="margin-top:10px;height:52px"><span>Nur <span class="nname">Neon City</span> · 39,99 € einmalig</span></div>
      <div class="fine">Einzelkauf gehört dir für immer, nur dieser Stil. Wild West, Pixel Quest, Toy Town je 29,99 €. Wer später Plus nimmt, behält den Stil.</div></div></div>`);
    ph.append(f);
    requestAnimationFrame(() => { const m = f.querySelector('.m'); mapInto(m, 'neon', { center: [40, -20], heading: 0.4, scale: 1.25, tilt: 50, anchor: [0.5, 0.5] }, (u, v) => { drawRoute(u, v, R, 0, 'neon', { width: 9 }); drawPlayer(u, v, R.pts[0], 0, 'neon', 14); drawBlips(u, v, scene, 'neon', { size: 10 }); }); });
  }],
  ['Stil testen', 'Plus-Stil 10 Minuten auf der echten Karte testen. Läuft nie während einer Fahrt ab (erst nach Ankunft zurück zu Klassik).', ph => {
    mapInto(ph.querySelector('.fill'), 'neon', { center: [-500, 300], heading: 0, scale: 0.6, tilt: 0, anchor: [0.5, 0.45] }, (u, v) => { drawBlips(u, v, scene, 'neon', {}); drawPlayer(u, v, R.pts[0], 0, 'neon', 12); });
    ph.append($(`<div class="f"><div class="banner g" style="border-radius:18px"><div style="width:40px;height:40px;border-radius:12px;background:linear-gradient(135deg,#b44dff,#7a2bd8);display:grid;place-items:center;font:800 13px Inter">9:42</div><div style="flex:1"><b><span class="nname">Neon City</span> · Vorschau</b><small>Noch 9 Min 42 s</small></div><span class="price" style="background:#b44dff">Plus holen</span></div>
      <div class="grow"></div><div class="g" style="padding:12px 14px"><div class="grab"></div><div style="display:flex;align-items:center;gap:10px;background:rgba(255,255,255,.08);border-radius:14px;padding:12px 14px">${icon(I.search, 20, '#c9c9d0')}<span style="font:600 18px Inter;color:#d0d0d6">Wohin?</span></div></div>${osm(140)}</div>`));
  }],
  ['Plus aktiv', 'Nach dem Kauf (Apple zeigt das Bezahlfenster selbst). Kurz feiern, gewählter Stil sofort aktiv.', ph => {
    mapInto(ph.querySelector('.fill'), 'neon', { center: [40, -20], heading: 0.5, scale: 1.2, tilt: 50, anchor: [0.5, 0.45] }, (u, v) => { drawRoute(u, v, R, 0, 'neon', { width: 8 }); drawPlayer(u, v, R.pts[0], 0, 'neon', 14); });
    ph.append($(`<div class="f"><div class="confetti"></div><div class="grow"></div><div class="sheet" style="text-align:center"><div class="grab"></div>
      <div style="width:64px;height:64px;border-radius:32px;margin:6px auto 12px;background:linear-gradient(135deg,#b44dff,#7a2bd8);display:grid;place-items:center">${icon(I.check, 30, '#fff', 3)}</div>
      <div class="h1" style="font-size:26px">Plus ist aktiv</div><div class="sub" style="margin-top:6px"><span class="nname">Neon City</span> läuft jetzt auf dem iPhone und in CarPlay. Alle anderen Stile sind auch frei.</div>
      <div class="btn">Losfahren</div><div class="btn2">Andere Stile ansehen</div></div></div>`));
  }],
  ['Meine Fahrten', 'Lokaler Verlauf (nur auf dem iPhone). Von hier: Fotomodus, Strecke nochmal fahren, löschen.', ph => {
    ph.querySelector('.fill').style.background = '#0b0b0d';
    const trips = [[scene.presets.start, scene.presets.hexenturm, 'Hexenturm', '9:41 · 1,9 km · 6 Min'], [scene.presets.home, scene.presets.work, 'Arbeit', '7:48 · 3,4 km · 9 Min'], [scene.presets.work, scene.presets.home, 'Zuhause', 'Gestern 17:12 · 3,5 km · 10 Min']];
    const f = $(`<div class="f" style="padding-top:58px"><div style="display:flex;align-items:center;gap:10px"><div class="g round" style="width:38px;height:38px">${icon(I.back, 18)}</div><div class="h1" style="font-size:28px">Meine Fahrten</div></div>
      <div class="sum" style="margin-top:14px"><div>186 km<small>diesen Monat</small></div><div>23<small>Fahrten</small></div><div>4 h 12<small>unterwegs</small></div></div>
      <div class="day">Heute</div><div class="card" style="padding:4px 14px">${trips.slice(0, 2).map((t, i) => `<div class="srow"><div class="thumb"><div class="m" data-i="${i}"></div></div><div style="flex:1"><b>${t[2]}</b><small>${t[3]}</small></div><span style="opacity:.5">${icon(I.share, 18)}</span></div>`).join('')}</div>
      <div class="day">Gestern</div><div class="card" style="padding:4px 14px"><div class="srow"><div class="thumb"><div class="m" data-i="2"></div></div><div style="flex:1"><b>${trips[2][2]}</b><small>${trips[2][3]}</small></div><span style="opacity:.5">${icon(I.share, 18)}</span></div></div>
      <div class="grow"></div><div class="fine">Fahrten bleiben nur auf diesem iPhone. Speichern in den Einstellungen abschaltbar.</div></div>`);
    ph.append(f);
    requestAnimationFrame(() => f.querySelectorAll('.m').forEach(m => { const t = trips[+m.dataset.i], r = router.route(t[0], t[1]); mapInto(m, 'neon', fit(r.pts, m, 40, 40, 0.5), (u, v) => drawRoute(u, v, r, 0, 'neon', { width: 3 })); }));
  }],
  ['Favorit merken', 'Logik-Lücke geschlossen: Die Kategorie „Favoriten“ braucht einen Weg, Orte zu merken. Stern in der Routen-Vorschau.', ph => {
    const el = ph.querySelector('.fill'); mapInto(el, 'neon', fit(R.pts, el, 330, 330, 0.3), (u, v) => { drawRoute(u, v, R, 0, 'neon', { width: 7 }); drawPlayer(u, v, R.pts[0], 0, 'neon', 11); drawDestination(u, v, R.pts[R.pts.length - 1], 'neon', 8); });
    ph.append($(`<div class="f" style="padding:0"><div class="g round" style="position:absolute;left:16px;top:60px">${icon(I.back, 22)}</div><div class="grow"></div><div class="sheet" style="margin:0 10px 22px"><div class="grab"></div>
      <div style="display:flex;justify-content:space-between;align-items:flex-start"><div><div style="font:800 28px Inter;letter-spacing:-.6px">Hexenturm</div><div style="color:#a9a9b2;font:500 14px Inter">Altstadt · Idstein</div></div><div style="display:flex;gap:8px"><div class="g round" style="width:36px;height:36px;background:rgba(180,77,255,.35)">${icon(I.star, 17, '#ffd23f')}</div><div class="g round" style="width:36px;height:36px">${icon(I.x, 16)}</div></div></div>
      <div class="chip" style="margin-top:10px">${icon(I.star, 14, '#ffd23f')} Als Favorit gemerkt</div>
      <div class="ropt on"><span><b style="font:700 16px Inter">6 Min</b><small>Schnellste · 1,9 km · an 9:47</small></span><span class="chip" style="padding:4px 9px;font-size:12px">Empfohlen</span></div>
      <div class="cta" style="height:56px;margin-top:12px">Los</div></div>${osm(300)}</div>`));
  }],
  ['Wo hab ich geparkt?', 'Im Glas-Look: Auto-Symbol (Schnauze oben), Blatt mit Fußweg. Erscheint nach dem Trennen von CarPlay.', ph => {
    const car = [scene.presets.start[0] + 60, scene.presets.start[1] - 40], me = scene.presets.hexenturm, el = ph.querySelector('.fill');
    mapInto(el, 'neon', fit([car, me], el, 260, 300, 0.36), (u, v) => { drawBlips(u, v, scene, 'neon', { size: 8 }); const q = v.project(car); drawParkedCar(u, q[0], q[1], 34, 'neon'); drawPlayer(u, v, me, 0.6, 'neon', 13); });
    const f = $(`<div class="f" style="padding:0"><div class="grow"></div><div class="sheet" style="margin:0 10px 22px"><div class="grab"></div>
      <div style="display:flex;gap:12px;align-items:center"><canvas width="88" height="120" style="width:44px;height:60px"></canvas><div><div style="font:800 22px Inter">Dein Auto</div><div style="color:#a9a9b2;font:500 13.5px Inter">Bahnhofstraße · seit 14:32</div></div><div class="g round" style="margin-left:auto;width:36px;height:36px">${icon(I.x, 16)}</div></div>
      <div style="display:flex;gap:8px;margin-top:12px"><div class="cta" style="flex:1;height:52px">${icon(I.walk, 18)}&nbsp;12 Min zu Fuß</div><div class="g round" style="width:52px;height:52px;border-radius:18px">${icon(I.share, 20)}</div></div></div>${osm(186)}</div>`);
    ph.append(f); const c = f.querySelector('canvas').getContext('2d'); c.scale(2, 2); drawParkedCar(c, 22, 30, 50, 'neon');
  }],
  ['Baustelle voraus', 'Warnung 2 km vorher als oranges Glas unter dem Abbiegehinweis, Strecke auf der Karte markiert.', ph => {
    const w = works.find(x => x.title.includes('Bad Camberg - Niedernhausen')) || works[0];
    const pts = w.line.map(([lo, la]) => toLocal(la, lo)), at = pts.reduce((b, q) => Math.hypot(q[0], q[1]) < Math.hypot(b[0], b[1]) ? q : b);
    const v = new MapView(ph.querySelector('.fill')); v.setTexture(tex.neon, 'neon');
    const u = v.apply({ center: [at[0] + 40, at[1] + 700], heading: 0, scale: 0.9, tilt: 55, anchor: [0.5, 0.7] });
    drawWork(u, v, w, 'neon', 1.3); drawPlayer(u, v, [at[0] + 40, at[1] + 700], 0, 'neon', 16);
    ph.append($(`<div class="f" style="padding:58px 10px 24px"><div class="g" style="padding:14px 18px;display:flex;gap:14px;align-items:center;background:rgba(124,40,200,.72)"><svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round"><path d="M12 21V4"/><path d="m7 9 5-5 5 5"/></svg><div><div style="font:800 38px Inter;letter-spacing:-1px;line-height:1">8 km</div><div style="font:700 17px Inter">A 3 Richtung Frankfurt</div></div></div>
      <div class="banner warn" style="margin-top:8px"><div style="width:36px;height:36px;border-radius:10px;background:rgba(0,0,0,.18);display:grid;place-items:center;font:900 18px Inter">!</div><div><b>Baustelle in 1,8 km</b><small>Rechter Fahrstreifen gesperrt · bis 19.12.</small></div></div>
      <div style="position:absolute;right:16px;top:250px">${limit(80)}</div>
      <div class="grow"></div><div class="g" style="padding:12px 14px;display:flex;align-items:center;gap:12px"><div class="round" style="background:rgba(255,255,255,.08)"><div style="text-align:center;line-height:1"><b style="font:800 18px Inter">78</b><div style="font:500 9px Inter;color:#a9a9b2">km/h</div></div></div><div style="flex:1;text-align:center"><div style="font:800 24px Inter">10:12</div><div style="color:#a9a9b2;font:500 13px Inter">31 Min · 38 km</div></div><div class="round" style="background:#ff3b4e">${icon(I.x, 20)}</div></div></div>`));
  }],
  ['Neu berechnen', 'Abgewichen: kurzer Hinweis statt Vollbild, alte Route grau bis die neue da ist.', ph => {
    const d = 420; const { u, v } = navMap(ph.querySelector('.fill'), 'neon', R, d);
    ph.append($(`<div class="f" style="padding:58px 10px 24px"><div class="banner info g" style="background:rgba(124,40,200,.8)"><div style="width:40px;height:40px;border-radius:12px;background:rgba(255,255,255,.15);display:grid;place-items:center">${icon(I.reroute, 22)}</div><div><b>Route wird neu berechnet</b><small>Du bist anders gefahren</small></div></div>
      <div class="grow"></div><div class="g" style="padding:12px 14px;display:flex;align-items:center;gap:12px"><div class="round" style="background:rgba(255,255,255,.08)"><div style="text-align:center;line-height:1"><b style="font:800 18px Inter">32</b><div style="font:500 9px Inter;color:#a9a9b2">km/h</div></div></div><div style="flex:1;text-align:center"><div style="font:800 24px Inter;opacity:.5">9:48</div><div style="color:#a9a9b2;font:500 13px Inter">wird aktualisiert …</div></div><div class="round" style="background:#ff3b4e">${icon(I.x, 20)}</div></div></div>`));
  }],
  ['Kein GPS / kein Netz', 'Fehlerzustände ruhig anzeigen: Tunnel (Navigation läuft geschätzt weiter), kein Netz (letzte Route bleibt).', ph => {
    navMap(ph.querySelector('.fill'), 'neon', R, 260);
    ph.append($(`<div class="f" style="padding:58px 10px 24px"><div class="g" style="padding:14px 18px;display:flex;gap:14px;align-items:center;background:rgba(124,40,200,.72)">${arrow(44)}<div><div style="font:800 38px Inter;letter-spacing:-1px;line-height:1">150 m</div><div style="font:700 17px Inter">Am Bahnhof</div></div></div>
      <div class="chip" style="margin-top:8px;align-self:flex-start">${icon(I.gps, 15, '#ff9f1c')} Kein GPS · Position geschätzt</div>
      <div class="chip" style="margin-top:6px;align-self:flex-start">${icon(I.wifi, 15, '#ff9f1c')} Offline · Route bleibt gespeichert</div>
      <div class="grow"></div><div class="g" style="padding:12px 14px;display:flex;align-items:center;gap:12px"><div class="round" style="background:rgba(255,255,255,.08)"><div style="text-align:center;line-height:1"><b style="font:800 18px Inter">–</b><div style="font:500 9px Inter;color:#a9a9b2">km/h</div></div></div><div style="flex:1;text-align:center"><div style="font:800 24px Inter">9:47</div><div style="color:#a9a9b2;font:500 13px Inter">5 Min · 1,1 km</div></div><div class="round" style="background:#ff3b4e">${icon(I.x, 20)}</div></div></div>`));
  }],
  ['Standort aus', 'Wenn der Standort abgelehnt wurde: Karte geht trotzdem, Suche geht, „Los“ führt zu den iOS-Einstellungen.', ph => {
    mapInto(ph.querySelector('.fill'), 'neon', { center: [-500, 300], heading: 0, scale: 0.45, tilt: 0, anchor: [0.5, 0.45] }, (u, v) => drawBlips(u, v, scene, 'neon', {}));
    ph.append($(`<div class="f" style="padding:0"><div style="position:absolute;right:14px;top:62px;display:flex;flex-direction:column;gap:10px"><div class="g round">${icon(I.gear, 20)}</div></div><div class="grow"></div>
      <div class="sheet" style="margin:0 10px 22px"><div class="grab"></div><div style="display:flex;gap:12px;align-items:center"><div style="width:44px;height:44px;border-radius:14px;background:rgba(255,159,28,.25);display:grid;place-items:center">${icon(I.loc, 20, '#ff9f1c')}</div><div><b style="font:800 17px Inter">Standort ist aus</b><div style="color:#a9a9b2;font:500 13px Inter">Ohne Standort keine Navigation.</div></div></div>
      <div class="cta" style="height:50px;margin-top:12px;font-size:16px">In Einstellungen erlauben</div>
      <div style="display:flex;align-items:center;gap:10px;background:rgba(255,255,255,.08);border-radius:14px;padding:12px 14px;margin-top:10px">${icon(I.search, 20, '#c9c9d0')}<span style="font:600 17px Inter;color:#d0d0d6">Orte ansehen</span></div></div>${osm(250)}</div>`));
  }],
];

async function boot() {
  await loadAssets();
  scene = await (await fetch('data/idstein.json')).json();
  works = (await (await fetch('data/autobahn_a3_idstein.json')).json()).meldungen;
  router = new Router(scene.graph); R = router.route(scene.presets.start, scene.presets.hexenturm);
  for (const s of ['classic', 'neon', 'western', 'pixel', 'toy']) tex[s] = await renderTexture(scene, s);
  await document.fonts.ready;
  const s = $(`<section class="dsec"><h2>Glas · weitere Screens</h2><p>Shop, Stil testen, Freigeschaltet, Meine Fahrten, Favoriten, Parkplatz, Baustelle, Neuberechnung, Fehlerzustände.</p><div class="drow"></div></section>`); main.append(s);
  for (const [name, cap, fn] of SCREENS) fn(phone(s.lastElementChild, `<b>${name}</b> · ${cap}`));
  await new Promise(r => requestAnimationFrame(r)); placeAttribution();
  window.__ready = true;
}
boot().catch(e => { console.error(e); document.body.insertAdjacentHTML('beforeend', `<pre style="color:#f66">${e.stack}</pre>`); });
