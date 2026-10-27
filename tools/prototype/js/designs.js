// GM-030: UI-Entwürfe – vier Richtungen auf der echten Neon-Karte (map.js). Nur zum Zeigen.
import { MapView, renderTexture, renderRegion, drawRoute, drawBlips, drawPlayer, drawDestination } from './map.js';
import { placeAttribution } from './glasfix.js';
import { Router, pointAt, smoothHeading } from './route.js';
import { loadAssets } from './assets.js';

const $ = h => { const t = document.createElement('template'); t.innerHTML = h.trim(); return t.content.firstElementChild; };
const main = document.getElementById('dz');
let scene, router, tex, R, D;

function phone(row, cls, cap, time = '9:41') {
  const ph = $(`<div><div class="dph ${cls}"><div class="fill"></div><div class="isl"></div><div class="sb">${time}</div><div class="hbar"></div></div><div class="cap">${cap}</div></div>`);
  row.append(ph); return ph.firstElementChild;
}
function map(ph, mode) {
  const el = ph.querySelector('.fill'), v = new MapView(el); v.setTexture(tex, 'neon');
  if (mode === 'browse') { const u = v.apply({ center: [-700, 420], heading: 0, scale: 0.55, tilt: 0, anchor: [0.5, 0.5] }); drawBlips(u, v, scene, 'neon', {}); drawPlayer(u, v, R.pts[0], 0, 'neon', 12); }
  if (mode === 'preview') {
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity; for (const [x, y] of R.pts) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
    const s = Math.min(330 / (x1 - x0), 360 / (y1 - y0));
    const u = v.apply({ center: [(x0 + x1) / 2, (y0 + y1) / 2], heading: 0, scale: s, tilt: 0, anchor: [0.5, 0.3] });
    drawRoute(u, v, R, 0, 'neon', { width: 7 }); drawPlayer(u, v, R.pts[0], 0, 'neon', 11); drawDestination(u, v, R.pts[R.pts.length - 1], 'neon', 8);
  }
  if (mode === 'nav') {
    const at = pointAt(R.pts, R.cum, D).p, hd = smoothHeading(R, D), cam = { center: at, heading: hd, scale: 3.2, tilt: 58, anchor: [0.5, 0.66] };
    const g = { x0: at[0] - 550, y0: at[1] - 800, w: 1100, h: 1100 }; v.setDetail(renderRegion(scene, 'neon', g, 4), g, 4, 'neon');
    const u = v.apply(cam); drawRoute(u, v, R, D, 'neon'); drawBlips(u, v, scene, 'neon', { size: 11 }); drawPlayer(u, v, at, hd, 'neon', 16);
  }
}
const arrow = (s = 44, c = '#fff') => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="${c}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M7 21V10a4 4 0 0 1 4-4h8"/><path d="m15 2 4 4-4 4"/></svg>`;
const icon = (d, s = 20, c = '#fff', w = 2.2) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="${c}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
const I = { search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>', loc: '<path d="M12 2 19 21 12 17 5 21z"/>', gear: '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9 7 7M17 17l2.1 2.1M4.9 19.1 7 17M17 7l2.1-2.1"/>', home: '<path d="M3 11 12 4l9 7v9h-6v-6H9v6H3z"/>', work: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V4h8v3"/>', fuel: '<path d="M4 21V4h9v17M4 11h9M13 8l4 3v7a2 2 0 0 0 4 0V9"/>', p: '<path d="M7 21V3h6a5 5 0 0 1 0 10H7"/>', x: '<path d="M6 6l12 12M18 6 6 18"/>', back: '<path d="m15 6-6 6 6 6"/>', mic: '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>', vol: '<path d="M4 9v6h4l5 4V5L8 9z"/><path d="M16 8a5 5 0 0 1 0 8"/>' };
const limit = (n, size = 58) => `<div style="width:${size}px;height:${size}px;border-radius:50%;background:#fff;border:${size * 0.11}px solid #e30613;color:#000;display:grid;place-items:center;font:800 ${size * 0.38}px Inter">${n}</div>`;

// ------------------------------------------------------------ A · HUD
function designA(row) {
  let ph = phone(row, 'A', 'Start: schlanke HUD-Leiste, Ecken-Markierungen, Ziele als Kürzel.'); map(ph, 'browse');
  ph.insertAdjacentHTML('beforeend', `
    <div class="abs p" style="left:14px;right:14px;top:58px;height:56px;display:flex;align-items:center;gap:12px;padding:0 16px">${icon(I.search, 20, '#c27bff')}<span style="font:700 22px 'Barlow Condensed';letter-spacing:2px;text-transform:uppercase">Ziel eingeben</span><span style="margin-left:auto">${icon(I.mic, 20, '#9d9da6')}</span></div>
    <div class="abs" style="left:14px;top:124px;display:flex;gap:8px">${[['home', 'Zuhause', '14 MIN'], ['work', 'Arbeit', '22 MIN']].map(([i, t, m]) => `<div class="p" style="padding:7px 12px;display:flex;gap:8px;align-items:center">${icon(I[i], 16, '#c27bff')}<span style="font:700 15px 'Barlow Condensed';text-transform:uppercase;letter-spacing:1px">${t}</span><span class="mono acc" style="font-size:12px">${m}</span></div>`).join('')}</div>
    <div class="abs" style="right:14px;top:180px;display:flex;flex-direction:column;gap:8px">${[I.loc, I.gear].map(d => `<div class="p" style="width:46px;height:46px;display:grid;place-items:center">${icon(d, 20)}</div>`).join('')}</div>
    <div class="abs p" style="left:14px;right:14px;bottom:30px;padding:12px 16px"><div class="lbl">Standort</div><div style="display:flex;justify-content:space-between;align-items:baseline"><span style="font:800 26px 'Barlow Condensed';text-transform:uppercase;letter-spacing:1px">Idstein · Am Bahnhof</span><span class="mono acc" style="font-size:13px">50.22N 8.27E</span></div><div class="tick" style="margin-top:8px;width:62%"></div></div>
    <div class="osm" style="right:16px;bottom:112px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`);

  ph = phone(row, 'A', 'Vorschau: Routen als Liste mit Akzent-Kante, „Los“ schräg.'); map(ph, 'preview');
  ph.insertAdjacentHTML('beforeend', `
    <div class="abs p" style="left:14px;right:14px;top:58px;height:50px;display:flex;align-items:center;gap:10px;padding:0 14px">${icon(I.back, 20, '#c27bff')}<span style="font:700 20px 'Barlow Condensed';text-transform:uppercase;letter-spacing:1px">Zum Hexenturm</span></div>
    <div class="abs p" style="left:14px;right:14px;bottom:30px;padding:14px 14px 16px">
      <div class="lbl">Ziel</div><div style="font:800 32px 'Barlow Condensed';text-transform:uppercase;letter-spacing:1px;line-height:1">Hexenturm</div><div style="color:#9d9da6;font:500 13px Inter;margin:4px 0 10px">Altstadt · Idstein</div>
      <div class="opt on"><span>Schnellste<small>1,9 km · Ankunft 9:47</small></span><span class="mono" style="font-size:22px">6<span style="font-size:13px"> MIN</span></span></div>
      <div class="opt"><span>Kürzeste<small>1,7 km</small></span><span class="mono" style="font-size:18px;color:#c9c9d0">7<span style="font-size:12px"> MIN</span></span></div>
      <div class="opt"><span>Neues entdecken<small>+38 % neue Straßen</small></span><span class="mono" style="font-size:18px;color:#c9c9d0">9<span style="font-size:12px"> MIN</span></span></div>
      <div class="btn" style="height:54px;margin-top:12px">Los</div></div>
    <div class="osm" style="right:16px;bottom:372px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`);

  ph = phone(row, 'A', 'Navigation: Entfernung als große Zahl, Fortschritt als Strichleiste, Tempo und Limit gekoppelt.'); map(ph, 'nav');
  ph.insertAdjacentHTML('beforeend', `
    <div class="abs p" style="left:14px;right:14px;top:58px;padding:14px 16px;display:flex;gap:14px;align-items:center">${arrow(46, '#c27bff')}<div><div style="display:flex;align-items:baseline;gap:6px"><span class="mono" style="font-size:42px;font-weight:800;line-height:1">150</span><span class="mono acc" style="font-size:16px">M</span></div><div style="font:800 21px 'Barlow Condensed';text-transform:uppercase;letter-spacing:1.5px">Am Bahnhof</div><div class="lbl" style="letter-spacing:1px">danach links · Wiesbadener Str</div></div></div>
    <div class="abs" style="right:14px;top:200px;display:flex;flex-direction:column;align-items:center;gap:6px">${limit(50, 54)}<div class="p" style="padding:5px 10px;text-align:center"><div class="mono" style="font-size:22px;font-weight:800">46</div><div class="lbl" style="font-size:10px">km/h</div></div></div>
    <div class="abs p" style="left:14px;right:14px;bottom:30px;padding:12px 16px"><div style="display:flex;justify-content:space-between;align-items:center"><div><div class="lbl">Ankunft</div><div class="mono" style="font-size:28px;font-weight:800">9:47</div></div><div style="text-align:right"><div class="lbl">Rest</div><div class="mono" style="font-size:18px">5 MIN · 1,1 KM</div></div><div class="btn" style="background:#ff3b4e;width:90px;height:44px;font-size:18px">Ende</div></div><div class="tick" style="margin-top:10px;width:38%"></div></div>
    <div class="osm" style="right:16px;bottom:126px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`);
}

// ------------------------------------------------------------ B · Glas
function designB(row) {
  let ph = phone(row, 'B', 'Start: schwebende Glas-Suchleiste unten (Daumen), Schnellziele als Chips.'); map(ph, 'browse');
  ph.insertAdjacentHTML('beforeend', `
    <div class="abs" style="right:14px;top:62px;display:flex;flex-direction:column;gap:10px">${[I.loc, I.gear].map(d => `<div class="g round">${icon(d, 20)}</div>`).join('')}</div>
    <div class="abs g" style="left:12px;right:12px;bottom:26px;padding:12px 14px 14px"><div class="grab"></div>
      <div style="display:flex;align-items:center;gap:10px;background:rgba(255,255,255,.08);border-radius:14px;padding:12px 14px">${icon(I.search, 20, '#c9c9d0')}<span style="font:600 18px Inter;color:#d0d0d6">Wohin?</span><span style="margin-left:auto">${icon(I.mic, 20, '#c9c9d0')}</span></div>
      <div style="display:flex;gap:8px;margin-top:10px;flex-wrap:wrap">${[['home', 'Zuhause · 14 Min'], ['work', 'Arbeit · 22 Min'], ['fuel', 'Tanken'], ['p', 'Parken']].map(([i, t]) => `<span class="chip">${icon(I[i], 15, '#c27bff')}${t}</span>`).join('')}</div></div>
    <div class="osm" style="right:16px;bottom:176px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`);

  ph = phone(row, 'B', 'Vorschau: Blatt mit Griff, Routen als weiche Karten, Ankunftszeit statt nur Minuten.'); map(ph, 'preview');
  ph.insertAdjacentHTML('beforeend', `
    <div class="abs g round" style="left:16px;top:60px">${icon(I.back, 22)}</div>
    <div class="abs g" style="left:10px;right:10px;bottom:22px;padding:12px 16px 16px"><div class="grab"></div>
      <div style="display:flex;justify-content:space-between;align-items:flex-start"><div><div style="font:800 28px Inter;letter-spacing:-.6px">Hexenturm</div><div style="color:#a9a9b2;font:500 14px Inter">Altstadt · Idstein</div></div><div class="g round" style="width:36px;height:36px;border-radius:18px">${icon(I.x, 16)}</div></div>
      <div class="ropt on"><span><b style="font:700 16px Inter">6 Min</b><small>Schnellste · 1,9 km · an 9:47</small></span><span class="chip" style="padding:4px 9px;font-size:12px">Empfohlen</span></div>
      <div class="ropt"><span><b style="font:700 16px Inter">7 Min</b><small>Kürzeste · 1,7 km</small></span></div>
      <div class="ropt"><span><b style="font:700 16px Inter">9 Min</b><small>Neues entdecken · +38 % neue Straßen</small></span></div>
      <div class="cta" style="height:56px;margin-top:12px">Los</div></div>
    <div class="osm" style="right:16px;bottom:372px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`);

  ph = phone(row, 'B', 'Navigation: Abbiegekarte als Glas, unten kompakte Zeile, Ende als runder Knopf.'); map(ph, 'nav');
  ph.insertAdjacentHTML('beforeend', `
    <div class="abs g" style="left:10px;right:10px;top:58px;padding:14px 18px;display:flex;gap:14px;align-items:center;background:rgba(124,40,200,.72)">${arrow(46)}<div><div style="font:800 40px Inter;letter-spacing:-1px;line-height:1">150 m</div><div style="font:700 18px Inter">Am Bahnhof</div></div></div>
    <div class="abs chip" style="left:14px;top:178px">danach links · Wiesbadener Str.</div>
    <div class="abs" style="right:16px;top:178px">${limit(50, 56)}</div>
    <div class="abs g" style="left:10px;right:10px;bottom:24px;padding:12px 14px;display:flex;align-items:center;gap:12px">
      <div class="round" style="background:rgba(255,255,255,.08)"><div style="text-align:center;line-height:1"><b style="font:800 18px Inter">46</b><div style="font:500 9px Inter;color:#a9a9b2">km/h</div></div></div>
      <div style="flex:1;text-align:center"><div style="font:800 24px Inter">9:47</div><div style="color:#a9a9b2;font:500 13px Inter">5 Min · 1,1 km</div></div>
      <div class="round" style="background:#ff3b4e">${icon(I.x, 20)}</div></div>
    <div class="osm" style="right:16px;bottom:104px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`);
}

// ------------------------------------------------------------ C · Minimal
function designC(row) {
  let ph = phone(row, 'C', 'Start: fast nur Karte, eine Pille unten, alles andere ausgeblendet.'); map(ph, 'browse');
  ph.insertAdjacentHTML('beforeend', `
    <div class="abs pill" style="right:16px;top:62px;width:42px;height:42px;display:grid;place-items:center">${icon(I.gear, 18)}</div>
    <div class="abs" style="left:16px;right:16px;bottom:34px;display:flex;gap:8px">
      <div class="pill" style="flex:1;height:54px;display:flex;align-items:center;gap:10px;padding:0 18px">${icon(I.search, 19, '#b44dff', 2.6)}<span style="font:600 17px Inter">Wohin?</span></div>
      <div class="pill" style="width:54px;height:54px;display:grid;place-items:center">${icon(I.home, 20)}</div>
      <div class="pill" style="width:54px;height:54px;display:grid;place-items:center">${icon(I.loc, 20)}</div></div>
    <div class="osm" style="right:16px;bottom:96px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`);

  ph = phone(row, 'C', 'Vorschau: Routen als Segmente nebeneinander, ein großer Knopf.'); map(ph, 'preview');
  ph.insertAdjacentHTML('beforeend', `
    <div class="abs pill" style="left:16px;top:60px;height:40px;display:flex;align-items:center;gap:8px;padding:0 14px 0 10px">${icon(I.back, 18)}<span style="font:600 15px Inter">Hexenturm</span></div>
    <div class="abs sheet" style="left:0;right:0;bottom:0;padding:18px 16px 36px">
      <div style="display:flex;justify-content:space-between;align-items:baseline"><span style="font:800 30px Inter;letter-spacing:-.8px">6 Min</span><span style="color:#9a9aa2;font:500 14px Inter">1,9 km · an 9:47</span></div>
      <div style="color:#9a9aa2;font:500 14px Inter;margin:2px 0 14px">Hexenturm · Altstadt</div>
      <div class="seg"><span class="on">Schnell<small>6 Min</small></span><span>Kurz<small>7 Min</small></span><span>Entdecken<small>9 Min</small></span></div>
      <div style="height:54px;margin-top:14px;border-radius:14px;background:#b44dff;display:grid;place-items:center;font:800 18px Inter">Los</div></div>
    <div class="osm" style="right:16px;bottom:262px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`);

  ph = phone(row, 'C', 'Navigation: Abbiegen als Pille oben, unten eine Zeile. Maximal viel Karte.'); map(ph, 'nav');
  ph.insertAdjacentHTML('beforeend', `
    <div class="abs pill" style="left:16px;right:16px;top:58px;height:68px;display:flex;align-items:center;gap:14px;padding:0 20px">${arrow(34, '#b44dff')}<span style="font:800 28px Inter">150 m</span><span style="font:600 16px Inter;color:#d0d0d6;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">Am Bahnhof</span></div>
    <div class="abs" style="right:18px;top:140px">${limit(50, 48)}</div>
    <div class="abs pill" style="left:16px;right:16px;bottom:30px;height:56px;display:flex;align-items:center;padding:0 8px 0 20px;gap:12px"><span class="dot"></span><b style="font:800 18px Inter">9:47</b><span style="color:#9a9aa2;font:500 14px Inter">5 Min · 1,1 km</span><span style="margin-left:auto;font:700 14px Inter;color:#9a9aa2">46 km/h</span><div style="width:42px;height:42px;border-radius:21px;background:#ff3b4e;display:grid;place-items:center">${icon(I.x, 18)}</div></div>
    <div class="osm" style="right:16px;bottom:92px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`);
}

// ------------------------------------------------------------ D · Sticker
function designD(row) {
  let ph = phone(row, 'D', 'Start: dicke Konturen, harter Schatten, Gelb als Zweitfarbe. Laut und eigen.'); map(ph, 'browse');
  ph.insertAdjacentHTML('beforeend', `
    <div class="abs st tilt" style="left:16px;right:16px;top:62px;height:60px;display:flex;align-items:center;gap:10px;padding:0 16px">${icon(I.search, 22, '#111', 3)}<span style="font:900 24px Inter;letter-spacing:-.6px">Wohin geht's?</span></div>
    <div class="abs" style="left:16px;top:138px;display:flex;gap:8px"><span class="st y" style="padding:6px 10px;font:800 14px Inter;border-radius:10px">⌂ Zuhause 14'</span><span class="st" style="padding:6px 10px;font:800 14px Inter;border-radius:10px">Arbeit 22'</span></div>
    <div class="abs" style="right:16px;top:190px;display:flex;flex-direction:column;gap:10px">${[I.loc, I.gear].map(d => `<div class="st" style="width:48px;height:48px;display:grid;place-items:center">${icon(d, 22, '#111', 2.6)}</div>`).join('')}</div>
    <div class="abs st v" style="left:16px;right:16px;bottom:34px;padding:12px 16px;display:flex;justify-content:space-between;align-items:center"><div><div style="font:800 12px Inter;opacity:.85">DU BIST IN</div><div style="font:900 24px Inter;letter-spacing:-.5px">Idstein West</div></div><span class="tag">31 % entdeckt</span></div>
    <div class="osm" style="right:16px;bottom:118px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`);

  ph = phone(row, 'D', 'Vorschau: Ziel als Sticker, Routen als dicke Knöpfe.'); map(ph, 'preview');
  ph.insertAdjacentHTML('beforeend', `
    <div class="abs st" style="left:16px;top:60px;width:46px;height:46px;display:grid;place-items:center">${icon(I.back, 22, '#111', 3)}</div>
    <div class="abs st" style="left:12px;right:12px;bottom:26px;padding:14px">
      <span class="tag">ZIEL</span><div class="big" style="margin-top:4px">Hexenturm</div><div style="font:600 14px Inter;opacity:.6;margin-bottom:6px">Altstadt · Idstein</div>
      <div class="row3 on"><span>Schnellste<small>1,9 km · an 9:47</small></span><span style="font:900 22px Inter">6'</span></div>
      <div class="row3"><span>Kürzeste<small>1,7 km</small></span><span style="font:900 20px Inter">7'</span></div>
      <div class="row3"><span>Neues entdecken<small>+38 % neue Straßen</small></span><span style="font:900 20px Inter">9'</span></div>
      <div class="st y" style="height:56px;margin-top:12px;display:grid;place-items:center;font:900 22px Inter;box-shadow:3px 3px 0 #111">LOS!</div></div>
    <div class="osm" style="right:16px;bottom:400px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`);

  ph = phone(row, 'D', 'Navigation: Abbiegen als großer Sticker, Ankunft und Ende unten als Block.'); map(ph, 'nav');
  ph.insertAdjacentHTML('beforeend', `
    <div class="abs st v tilt" style="left:16px;right:16px;top:60px;padding:12px 16px;display:flex;gap:14px;align-items:center">${arrow(48)}<div><div class="big" style="line-height:1">150 m</div><div style="font:800 18px Inter">Am Bahnhof</div></div></div>
    <div class="abs st y" style="left:16px;top:196px;padding:6px 10px;font:800 13px Inter;border-radius:10px">danach links · Wiesbadener Str.</div>
    <div class="abs" style="right:16px;top:186px">${limit(50, 56)}</div>
    <div class="abs" style="left:12px;right:12px;bottom:28px;display:flex;gap:8px">
      <div class="st" style="flex:1;padding:10px 14px"><div style="font:900 28px Inter;letter-spacing:-.8px">9:47</div><div style="font:700 13px Inter;opacity:.6">5 Min · 1,1 km · 46 km/h</div></div>
      <div class="st" style="width:84px;background:#ff3b4e;color:#fff;display:grid;place-items:center;font:900 18px Inter">ENDE</div></div>
    <div class="osm" style="right:16px;bottom:118px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`);
}

async function boot() {
  await loadAssets();
  scene = await (await fetch('data/idstein.json')).json();
  router = new Router(scene.graph);
  R = router.route(scene.presets.start, scene.presets.hexenturm); D = 260;
  tex = await renderTexture(scene, 'neon');
  await document.fonts.ready;
  const sec = (t, p) => { const s = $(`<section class="dsec"><h2>${t}</h2><p>${p}</p><div class="drow"></div></section>`); main.append(s); return s.lastElementChild; };
  designA(sec('A · HUD', 'Spiel-Overlay: schmale Fettschrift (Barlow Condensed, frei lizenziert), Zahlen in Monospace, abgeschrägte Ecken, Lila nur als Akzent. Wirkt am stärksten nach Spiel, ohne ein bestimmtes Spiel zu kopieren.'));
  designB(sec('B · Glas', 'Nah an iOS: weiche Glasflächen, runde Ecken, Bedienung unten im Daumenbereich. Am leichtesten zu bedienen, wirkt hochwertig und ruhig.'));
  designC(sec('C · Minimal', 'Karte zuerst: nur Pillen oben und unten, sehr wenig Text. Die Karte ist der Star, gut für CarPlay-ähnliche Ruhe.'));
  designD(sec('D · Sticker', 'Kräftig und verspielt: dicke schwarze Konturen, harter Schatten, Gelb als Zweitfarbe, leicht schräge Elemente. Sehr eigenständig, fällt in Screenshots auf.'));
  await new Promise(r => requestAnimationFrame(r)); placeAttribution();
  window.__ready = true;
}
boot().catch(e => { console.error(e); document.body.insertAdjacentHTML('beforeend', `<pre style="color:#f66">${e.stack}</pre>`); });
