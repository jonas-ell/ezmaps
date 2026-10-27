// GM-041: Design-Konzept „Stadt aufdecken“ im Glas-Look (Richtung B) auf der echten Karte.
// Zeigt: Meine Stadt (Nebel), Ortsteil, Fahrt iPhone + CarPlay (ruhig), Ankunft mit Aufleuchten, Stufe/Abzeichen,
// Wochenmission, Fahrt-Replay (läuft als Animation), Stil-Test in CarPlay und „Test vorbei“.
// Logik: explore.js (Zellen, Stufen) und replay.js (Kamera) – beide gespiegelt in Core/.
import { MapView, renderTexture, renderRegion, drawRoute, drawBlips, drawPlayer, drawDestination, drawFog } from './map.js';
import { Router, pointAt, smoothHeading, edgeKey } from './route.js';
import { loadAssets } from './assets.js';
import { levelFor } from './explore.js';
import { planReplay } from './replay.js';
import { placeAttribution } from './glasfix.js';

const $ = h => { const t = document.createElement('template'); t.innerHTML = h.trim(); return t.content.firstElementChild; };
const main = document.getElementById('dz');
const tex = {};
let scene, router, R, info, districts, explored, before;

const icon = (d, s = 20, c = 'currentColor', w = 2.2) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="${c}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
const I = { back: '<path d="m15 6-6 6 6 6"/>', x: '<path d="M6 6l12 12M18 6 6 18"/>', share: '<path d="M12 3v13M7 8l5-5 5 5"/><path d="M5 13v7h14v-7"/>', play: '<path d="M7 4v16l13-8z"/>', save: '<path d="M12 3v12M7 10l5 5 5-5"/><path d="M5 20h14"/>', compass: '<circle cx="12" cy="12" r="9"/><path d="m15.5 8.5-2 5-5 2 2-5z"/>', flag: '<path d="M5 21V4h11l-2 4 2 4H5"/>', target: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3"/>', clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>' };
const osm = `<div class="osm" style="right:16px;bottom:0">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div>`;
const pct = x => `${Math.round(x * 100)} %`;

function phone(row, cap) {
  const w = $(`<div><div class="dph B"><div class="fill"></div><div class="isl"></div><div class="sb">9:41</div><div class="hbar"></div></div><div class="cap">${cap}</div></div>`);
  row.append(w); return w.firstElementChild;
}
function car(row, cap) {
  const w = $(`<div><div class="dcar B"><div class="fill"></div></div><div class="cap">${cap}</div></div>`);
  row.append(w); return w.firstElementChild;
}
function mapInto(el, style, cam, draw) { const v = new MapView(el); v.setTexture(tex[style], style); const u = v.apply(cam); draw && draw(u, v); return v; }
function fit(pts, padW, padH, ay = 0.35) {
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity; for (const [x, y] of pts) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  return { center: [(x0 + x1) / 2, (y0 + y1) / 2], heading: 0, scale: Math.min(padW / Math.max(80, x1 - x0), padH / Math.max(80, y1 - y0)), tilt: 0, anchor: [0.5, ay] };
}

// ------------------------------------------------------------ Daten: Ortsteile + schon gefahrene Straßen (wie app.js)
function setup() {
  const { nodes, edges } = scene.graph, hexen = scene.presets.hexenturm, villages = scene.places.filter(p => p.kind !== 'town');
  const districtOf = p => {
    if (Math.hypot(p[0] - hexen[0], p[1] - hexen[1]) < 420) return 'Altstadt';
    for (const v of villages) if (Math.hypot(p[0] - v.p[0], p[1] - v.p[1]) < 650) return v.name;
    const a = Math.atan2(p[0] - hexen[0], -(p[1] - hexen[1])) * 180 / Math.PI;
    return 'Idstein ' + (a > -45 && a <= 45 ? 'Nord' : a > 45 && a <= 135 ? 'Ost' : a > -135 && a <= -45 ? 'West' : 'Süd');
  };
  info = new Map(); districts = {};
  for (const [a, b, len, , , , rank] of edges) {
    const mid = [(nodes[a][0] + nodes[b][0]) / 2, (nodes[a][1] + nodes[b][1]) / 2];
    if (Math.abs(mid[0]) > 1800 || Math.abs(mid[1]) > 1500 || rank > 6) continue;
    const d = districtOf(mid); info.set(edgeKey(a, b), { a, b, len, d, mid });
    (districts[d] ??= { total: 0, done: 0, pts: [] }).total += len; districts[d].pts.push(mid);
  }
  explored = new Set();
  const mark = k => { const e = info.get(k); if (e && !explored.has(k)) { explored.add(k); districts[e.d].done += e.len; } };
  for (const [f, t] of [[scene.presets.start, scene.presets.home], [scene.presets.start, scene.presets.work], [scene.presets.home, scene.presets.hexenturm]]) router.route(f, t)?.edges.forEach(mark);
  let i = 0; for (const [a, b, , , , , rank] of edges) if (rank <= 3 && (i++ % 2 === 0)) mark(edgeKey(a, b));
  // Altstadt fast fertig (für Abzeichen-Screen)
  for (const [k, e] of info) if (e.d === 'Altstadt' && (i++ % 7)) mark(k);
  // die heutige Fahrt: erstes Drittel kennt man schon, der Rest ist neu
  const unmark = k => { const e = info.get(k); if (e && explored.has(k)) { explored.delete(k); districts[e.d].done -= e.len; } };
  R.edges.forEach((k, j) => { if (j > R.edges.length / 3) unmark(k); else mark(k); });
  before = new Set(explored);
  R.edges.forEach(mark);
}
const lines = set => [...set].map(k => info.get(k)).filter(Boolean).map(e => [scene.graph.nodes[e.a], scene.graph.nodes[e.b]]);
const cityShare = set => { let t = 0, d = 0; for (const [k, e] of info) { t += e.len; if (set.has(k)) d += e.len; } return d / t; };
const newOnTrip = () => R.edges.filter(k => info.has(k) && !before.has(k));

/** Aufgedeckte Straßen leuchten (Neon-Lila mit weichem Schein); strength 0…1 */
function glow(u, v, ls, color = [196, 120, 255], strength = 1, width = 3) {
  u.save(); u.lineCap = 'round'; u.lineJoin = 'round';
  for (const [w, a, blur] of [[width * 4, 0.18, 18], [width * 2, 0.45, 8], [width, 1, 0]]) {
    u.strokeStyle = `rgba(${color},${a * strength})`; u.lineWidth = w; u.shadowColor = `rgba(${color},${0.9 * strength})`; u.shadowBlur = blur;
    u.beginPath(); for (const pts of ls) { let on = false; for (const p of pts) { const q = v.project(p); if (q[2] <= 0) { on = false; continue; } on ? u.lineTo(q[0], q[1]) : u.moveTo(q[0], q[1]); on = true; } } u.stroke(); // Punkte hinter der Kamera auslassen
  }
  u.restore();
}
/** Umriss eines Ortsteils (konvexe Hülle der Straßenmitten), gestrichelt oder gold */
function hull(pts) {
  const p = [...pts].sort((a, b) => a[0] - b[0] || a[1] - b[1]), cr = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
  const lo = [], up = []; for (const q of p) { while (lo.length >= 2 && cr(lo.at(-2), lo.at(-1), q) <= 0) lo.pop(); lo.push(q); }
  for (const q of p.reverse()) { while (up.length >= 2 && cr(up.at(-2), up.at(-1), q) <= 0) up.pop(); up.push(q); }
  return lo.slice(0, -1).concat(up.slice(0, -1));
}
function outline(u, v, pts, color, dash = []) {
  const h = hull(pts); u.save(); u.setLineDash(dash); u.strokeStyle = color; u.lineWidth = 2.5; u.fillStyle = color.replace(/[\d.]+\)$/, '0.08)');
  u.beginPath(); h.forEach((p, i) => { const q = v.project(p); i ? u.lineTo(q[0], q[1]) : u.moveTo(q[0], q[1]); }); u.closePath(); u.fill(); u.stroke(); u.restore();
}
function navMap(el, style, d, extra) {
  const at = pointAt(R.pts, R.cum, d).p, hd = smoothHeading(R, d), cam = { center: at, heading: hd, scale: 3.2, tilt: 58, anchor: [0.5, 0.66] };
  const v = new MapView(el); v.setTexture(tex[style], style);
  const g = { x0: at[0] - 550, y0: at[1] - 800, w: 1100, h: 1100 }; v.setDetail(renderRegion(scene, style, g, 4), g, 4, style);
  const u = v.apply(cam); extra && extra(u, v); drawRoute(u, v, R, d, style); drawBlips(u, v, scene, style, { size: 11 }); drawPlayer(u, v, at, hd, style, 16); return { u, v };
}
/** Strecke bis d als Linien (für „gerade gefahren, neu“) */
function drivenUntil(d) { const out = []; for (let i = 1; i < R.pts.length && R.cum[i - 1] < d; i++) if (!before.has(R.edges[i - 1])) out.push([R.pts[i - 1], R.pts[i]]); return out; }
const navBar = (a, b, c, extra = '') => `<div class="g" style="padding:12px 14px;display:flex;align-items:center;gap:12px"><div class="round" style="background:rgba(255,255,255,.08)"><div style="text-align:center;line-height:1"><b style="font:800 18px Inter">${a}</b><div style="font:500 9px Inter;color:#a9a9b2">km/h</div></div></div><div style="flex:1;text-align:center"><div style="font:800 24px Inter">${b}</div><div style="color:#a9a9b2;font:500 13px Inter">${c}</div></div>${extra}<div class="round" style="background:#ff3b4e">${icon(I.x, 20)}</div></div>`;
const turnCard = (m, s) => `<div class="g" style="padding:14px 18px;display:flex;gap:14px;align-items:center;background:rgba(124,40,200,.72)"><svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M7 21V10a4 4 0 0 1 4-4h8"/><path d="m15 2 4 4-4 4"/></svg><div><div style="font:800 38px Inter;letter-spacing:-1px;line-height:1">${m}</div><div style="font:700 17px Inter">${s}</div></div></div>`;

// ------------------------------------------------------------ Screens
const SCREENS = [
  ['Meine Stadt', 'Tab „Entdecken“: Nebel über allem, was du noch nicht gefahren bist. Gefahrene Straßen leuchten im Stil. Oben Stufe und Fortschritt, unten Ortsteile. Tippen auf einen Ortsteil öffnet ihn.', ph => {
    const el = ph.querySelector('.fill'), share = cityShare(explored), lv = levelFor(share);
    mapInto(el, 'neon', { center: [-150, 120], heading: 0, scale: 0.13, tilt: 0, anchor: [0.5, 0.36] }, (u, v) => { drawFog(u, v, scene, lines(explored)); glow(u, v, lines(explored), [196, 120, 255], 0.55, 1.6); drawPlayer(u, v, scene.presets.start, 0, 'neon', 9); });
    const ds = Object.entries(districts).filter(([, d]) => d.total > 1500).sort((a, b) => b[1].done / b[1].total - a[1].done / a[1].total).slice(0, 4);
    const next = lv.next ? `noch ${Math.max(1, Math.round((lv.next - share) * 100))} % bis Stufe ${lv.number + 1}` : 'höchste Stufe';
    ph.append($(`<div class="f" style="padding:58px 10px 22px">
      <div class="g" style="padding:14px 16px"><div style="display:flex;justify-content:space-between;align-items:flex-end"><div><div class="ekick">Idstein</div><div style="font:900 40px Inter;letter-spacing:-1.5px;line-height:1">${pct(share)}</div></div><div style="text-align:right"><div class="lvl">Stufe ${lv.number}</div><div style="font:800 17px Inter;margin-top:4px">Idstein-${lv.title === 'Kenner' ? 'Kenner' : lv.title}</div></div></div>
        <div class="xbar" style="margin-top:10px"><i style="width:${Math.min(100, share / (lv.next ?? 1) * 100)}%"></i></div><div style="font:500 12px Inter;color:#a9a9b2;margin-top:6px">${next} · diese Woche +2,1 %</div></div>
      <div class="grow"></div>
      <div class="sheet"><div class="grab"></div><div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px"><b style="font:800 19px Inter">Ortsteile</b><span class="chip" style="padding:5px 10px;font-size:12px">${icon(I.target, 13, '#c27bff')} Mission 1 / 3</span></div>
        ${ds.map(([n, d]) => { const s = d.done / d.total; return `<div class="drow2"><span>${n}${s > 0.9 ? ' <span class="gold">★</span>' : ''}</span><div class="xbar sm"><i style="width:${s * 100}%;${s > 0.9 ? 'background:linear-gradient(90deg,#ffd23f,#ffb000)' : ''}"></i></div><b>${pct(s)}</b></div>`; }).join('')}</div>${osm}</div>`));
  }],
  ['Ortsteil', 'Ein Ortsteil groß: Umriss gestrichelt, gefahrene Straßen hell, fehlende dunkel. Knopf „Neues entdecken“ plant eine Route über möglichst viele fehlende Straßen.', ph => {
    const el = ph.querySelector('.fill'), d = districts['Idstein Ost'] ?? Object.values(districts)[0], s = d.done / d.total;
    const mine = [...info].filter(([, e]) => e.d === 'Idstein Ost'), miss = mine.filter(([k]) => !explored.has(k)).map(([, e]) => [scene.graph.nodes[e.a], scene.graph.nodes[e.b]]);
    mapInto(el, 'neon', fit(d.pts, 330, 380, 0.36), (u, v) => {
      u.fillStyle = 'rgba(10,10,12,.55)'; u.fillRect(0, 0, v.W, v.H);
      outline(u, v, d.pts, 'rgba(196,120,255,.9)', [8, 6]);
      u.save(); u.strokeStyle = 'rgba(255,255,255,.18)'; u.lineWidth = 2; u.setLineDash([3, 5]); u.beginPath(); for (const [a, b] of miss) { const p = v.project(a), q = v.project(b); u.moveTo(p[0], p[1]); u.lineTo(q[0], q[1]); } u.stroke(); u.restore();
      glow(u, v, mine.filter(([k]) => explored.has(k)).map(([, e]) => [scene.graph.nodes[e.a], scene.graph.nodes[e.b]]), [196, 120, 255], 1, 2.4);
    });
    ph.append($(`<div class="f" style="padding:0"><div class="g round" style="position:absolute;left:16px;top:58px;width:40px;height:40px">${icon(I.back, 20)}</div><div class="grow"></div>
      <div class="sheet" style="margin:0 10px 22px"><div class="grab"></div><div style="display:flex;justify-content:space-between;align-items:flex-end"><div><div class="ekick">Ortsteil</div><div style="font:800 28px Inter;letter-spacing:-.6px">Idstein Ost</div></div><div style="font:900 34px Inter;letter-spacing:-1px">${pct(s)}</div></div>
        <div class="xbar" style="margin-top:10px"><i style="width:${s * 100}%"></i></div>
        <div style="display:flex;gap:8px;margin-top:12px"><div class="mini"><b>${(mine.filter(([k]) => !explored.has(k)).reduce((t, [, e]) => t + e.len, 0) / 1000).toFixed(1).replace('.', ',')} km</b><small>fehlen noch</small></div><div class="mini"><b>12 Min</b><small>bis 100 %</small></div><div class="mini"><b style="color:#ffd23f">★</b><small>Abzeichen</small></div></div>
        <div class="cta" style="height:54px;margin-top:12px">${icon(I.compass, 20)} Neues entdecken</div></div>${osm}</div>`));
  }],
  ['Fahrt (iPhone)', 'Während der Fahrt nichts, was ablenkt: keine Meldungen. Nur die frisch gefahrene, neue Strecke leuchtet dünn hinter dir, und unten steht leise „+3 neu“.', ph => {
    const d = R.length * 0.62; navMap(ph.querySelector('.fill'), 'neon', d, (u, v) => glow(u, v, drivenUntil(d), [196, 120, 255], 0.9, 5));
    ph.append($(`<div class="f" style="padding:58px 10px 24px">${turnCard('150 m', 'Am Bahnhof')}<div class="grow"></div>${navBar(46, '9:47', '5 Min · 1,1 km', '<span class="newpill">+3 neu</span>')}${osm}</div>`));
  }],
  ['Ankunft · Aufleuchten', 'Erst im Stand: Karte zoomt heraus, die heute neuen Straßen leuchten nacheinander auf (0,8 s), Zähler läuft hoch, Stufenbalken füllt sich. Darunter Replay ansehen.', ph => {
    const el = ph.querySelector('.fill'), nw = newOnTrip(), share = cityShare(explored), lv = levelFor(share), was = cityShare(before);
    mapInto(el, 'neon', fit(R.pts, 300, 300, 0.27), (u, v) => {
      drawFog(u, v, scene, lines(explored)); glow(u, v, lines(before), [196, 120, 255], 0.35, 1.5);
      glow(u, v, nw.map(k => info.get(k)).map(e => [scene.graph.nodes[e.a], scene.graph.nodes[e.b]]), [235, 200, 255], 1, 4.5);
      drawDestination(u, v, R.pts.at(-1), 'neon', 8);
    });
    const newPct = Math.round(nw.reduce((s, k) => s + info.get(k).len, 0) / R.length * 100);
    ph.append($(`<div class="f" style="padding:0"><div class="grow"></div><div class="sheet" style="margin:0 10px 22px"><div class="grab"></div>
      <div class="ekick">Angekommen · 9:47</div><div style="font:800 28px Inter;letter-spacing:-.6px">Hexenturm</div>
      <div style="display:flex;gap:8px;margin-top:12px"><div class="mini hot"><b>+${newPct} %</b><small>neue Straßen</small></div><div class="mini"><b>${nw.length}</b><small>Abschnitte neu</small></div><div class="mini"><b>+${(share - was) * 100 < 0.1 ? '0,1' : ((share - was) * 100).toFixed(1).replace('.', ',')} %</b><small>Idstein</small></div></div>
      <div style="display:flex;justify-content:space-between;font:700 13px Inter;margin-top:14px"><span>Idstein-${lv.title} · Stufe ${lv.number}</span><span style="opacity:.6">${pct(share)}</span></div>
      <div class="xbar" style="margin-top:6px"><i style="width:${Math.min(100, share / (lv.next ?? 1) * 100)}%"></i><s style="left:${was / (lv.next ?? 1) * 100}%"></s></div>
      <div class="pair"><div class="cta">${icon(I.play, 18, '#fff')} Replay</div><div class="btn2">Fertig</div></div></div>${osm}</div>`));
  }],
  ['Abzeichen', 'Neues Abzeichen oder neue Stufe: kurzer Moment im Stand, Ortsteil bekommt goldenen Rand auf der Karte. Eigene Namen, keine Spielinhalte.', ph => {
    const el = ph.querySelector('.fill'), d = districts['Altstadt'];
    mapInto(el, 'neon', fit(d.pts, 250, 250, 0.34), (u, v) => { drawFog(u, v, scene, lines(explored)); glow(u, v, lines(explored), [196, 120, 255], 0.6, 2); outline(u, v, d.pts, 'rgba(255,210,63,.95)'); });
    ph.append($(`<div class="f" style="padding:0"><div class="grow"></div><div class="sheet" style="margin:0 10px 22px;text-align:center"><div class="grab"></div>
      <div class="medal">${icon(I.flag, 34, '#1a1000', 2.4)}</div>
      <div class="ekick" style="margin-top:12px">Neues Abzeichen</div><div style="font:800 26px Inter;letter-spacing:-.5px">Altstadt komplett</div>
      <div class="sub" style="margin-top:6px">Alle Straßen in der Altstadt gefahren. Goldener Rand auf deiner Karte.</div>
      <div class="pair"><div class="cta">${icon(I.share, 18)} Teilen</div><div class="btn2">Weiter</div></div></div>${osm}</div>`));
  }],
  ['Wochenmission', 'Auf der Startkarte im Suchblatt: eine Mission pro Woche, ohne Druck. „Neues entdecken“ als Route führt direkt hin.', ph => {
    mapInto(ph.querySelector('.fill'), 'neon', { center: [-500, 300], heading: 0, scale: 0.6, tilt: 0, anchor: [0.5, 0.42] }, (u, v) => { drawFog(u, v, scene, lines(explored)); glow(u, v, lines(explored), [196, 120, 255], 0.55, 2); drawBlips(u, v, scene, 'neon', {}); drawPlayer(u, v, scene.presets.start, 0, 'neon', 12); });
    ph.append($(`<div class="f" style="padding:0"><div class="grow"></div><div class="sheet" style="margin:0 10px 22px"><div class="grab"></div>
      <div class="mission"><div class="mi">${icon(I.target, 22, '#fff')}</div><div style="flex:1"><b>Diese Woche</b><small>Fahre 3 neue Straßen in Idstein Ost</small><div class="xbar sm" style="margin-top:7px"><i style="width:33%"></i></div></div><b style="font:800 16px Inter">1 / 3</b></div>
      <div style="display:flex;align-items:center;gap:10px;background:rgba(255,255,255,.08);border-radius:14px;padding:12px 14px;margin-top:10px">${icon('<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>', 20, '#c9c9d0')}<span style="font:600 18px Inter;color:#d0d0d6">Wohin?</span></div>
      <div style="display:flex;gap:8px;margin-top:10px"><span class="chip">${icon(I.compass, 15, '#c27bff')}Neues entdecken</span><span class="chip">Zuhause · 14 Min</span></div></div>${osm}</div>`));
  }],
  ['Fahrt-Replay', 'Nach der Ankunft: 10 Sekunden, Hochformat 9:16, Kamera fliegt die Strecke nach, neue Straßen leuchten, am Ende Überblick mit Prozent. Wasserzeichen „EzMaps“. Hier läuft es als echte Animation (Kamera aus replay.js).', ph => {
    ph.querySelector('.fill').style.background = '#0b0b0d';
    const f = $(`<div class="f" style="padding:56px 18px 24px"><div style="display:flex;justify-content:space-between;align-items:center"><div class="g round" style="width:38px;height:38px">${icon(I.x, 16)}</div><b style="font:800 17px Inter">Replay</b><div style="width:38px"></div></div>
      <div class="player"><div class="m"></div><div class="wm">EzMaps</div><div class="pos">© OpenStreetMap-Mitwirkende</div><div class="ov"><b>+${Math.round(newOnTrip().reduce((s, k) => s + info.get(k).len, 0) / R.length * 100)} % neue Straßen</b><small>Hexenturm · 1,9 km · 6 Min</small></div><div class="pbar"><i></i></div></div>
      <div style="display:flex;gap:8px;margin-top:14px"><div class="cta" style="flex:1;height:52px">${icon(I.share, 18)} Teilen</div><div class="g round" style="width:52px;height:52px;border-radius:18px">${icon(I.save, 20)}</div></div>
      <div class="fine">Video bleibt auf dem iPhone, bis du es teilst. Start und Ziel lassen sich ausblenden.</div></div>`);
    ph.append(f);
    requestAnimationFrame(() => {
      const m = f.querySelector('.player .m'), v = new MapView(m); v.setTexture(tex.neon, 'neon');
      const frames = planReplay(R.pts, { W: m.clientWidth, H: m.clientHeight, followScale: 1.4 }), nw = new Set(newOnTrip()), bar = f.querySelector('.pbar i');
      const draw = i => {
        const fr = frames[i], u = v.apply({ center: fr.center, heading: fr.heading, scale: fr.scale, tilt: fr.tilt, anchor: [0.5, 0.62] });
        drawFog(u, v, scene, lines(explored)); glow(u, v, lines(before), [196, 120, 255], 0.35, 1.4);
        const upto = fr.progress * R.length, seg = [];
        for (let k = 1; k < R.pts.length && R.cum[k - 1] < upto; k++) seg.push([R.pts[k - 1], R.pts[k], nw.has(R.edges[k - 1])]);
        glow(u, v, seg.filter(s => s[2]).map(s => [s[0], s[1]]), [235, 200, 255], 1, 4);
        glow(u, v, seg.filter(s => !s[2]).map(s => [s[0], s[1]]), [196, 120, 255], 0.8, 3);
        const at = pointAt(R.pts, R.cum, upto).p; drawPlayer(u, v, at, fr.heading, 'neon', 10);
        bar.style.width = `${i / (frames.length - 1) * 100}%`;
        f.querySelector('.player .ov').style.opacity = fr.progress >= 1 ? 1 : 0;
      };
      draw(Math.round(frames.length * 0.45)); // Standbild für Screenshots
      let i = 0; const loop = () => { if (!window.__still) { draw(i); i = (i + 1) % frames.length; } setTimeout(loop, 33); }; setTimeout(loop, 1500);
    });
  }],
  ['Stil-Test vorbei', 'Die 10 Test-Minuten sind einmal je Stil und zählen auf iPhone und CarPlay zusammen. Nach Ankunft zurück zu Klassik. Kein neuer Test nach Löschen und Neuinstallieren (Schlüsselbund und iCloud).', ph => {
    mapInto(ph.querySelector('.fill'), 'classic', { center: [-500, 300], heading: 0, scale: 0.6, tilt: 0, anchor: [0.5, 0.4] }, (u, v) => { drawBlips(u, v, scene, 'classic', {}); drawPlayer(u, v, scene.presets.start, 0, 'classic', 12); });
    ph.append($(`<div class="f" style="padding:0"><div class="grow"></div><div class="sheet" style="margin:0 10px 22px"><div class="grab"></div>
      <div style="display:flex;gap:12px;align-items:center"><div class="thumbx"><div class="m"></div></div><div><div class="ekick">Test vorbei</div><b style="font:800 20px Inter"><span class="nname">Neon City</span> behalten?</b><div style="color:#a9a9b2;font:500 13px Inter">Du bist jetzt wieder in Klassik.</div></div></div>
      <div class="plan on" style="margin-top:18px"><span class="tag">Alle Stile</span><span><b>Mit Plus</b><small>29,99 € im Jahr</small></span><span class="pp"><b>2,50 €</b><small>pro Monat</small></span></div>
      <div class="btn" style="margin-top:12px">Plus holen</div><div class="btn2" style="margin-top:8px"><span>Nur <span class="nname">Neon City</span> · 39,99 €</span></div><div class="link">Später</div></div>${osm}</div>`));
    requestAnimationFrame(() => { const m = ph.querySelector('.thumbx .m'); mapInto(m, 'neon', { center: [40, -20], heading: 0.4, scale: 0.7, tilt: 45, anchor: [0.5, 0.6] }, (u, v) => drawRoute(u, v, R, 0, 'neon', { width: 6 })); });
  }],
];

const CAR = [
  ['CarPlay · Fahrt mit Stil-Test', 'Auch in CarPlay: die frisch gefahrene neue Strecke leuchtet dünn, sonst nichts. Der Stil-Test zeigt nur eine kleine Uhr („Test 4:12“) und zählt mit; er endet nie während der Fahrt.', el => {
    const d = R.length * 0.62;
    const at = pointAt(R.pts, R.cum, d).p, hd = smoothHeading(R, d), v = new MapView(el.querySelector('.fill')); v.setTexture(tex.neon, 'neon');
    const g = { x0: at[0] - 700, y0: at[1] - 800, w: 1400, h: 1100 }; v.setDetail(renderRegion(scene, 'neon', g, 4), g, 4, 'neon');
    const u = v.apply({ center: at, heading: hd, scale: 2.6, tilt: 55, anchor: [0.62, 0.68] }); glow(u, v, drivenUntil(d), [196, 120, 255], 0.9, 5); drawRoute(u, v, R, d, 'neon'); drawBlips(u, v, scene, 'neon', { size: 10 }); drawPlayer(u, v, at, hd, 'neon', 14);
    el.append($(`<div class="cpui"><div class="cpturn"><svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M7 21V10a4 4 0 0 1 4-4h8"/><path d="m15 2 4 4-4 4"/></svg><div><b>150 m</b><small>Am Bahnhof</small></div></div>
      <div class="cpeta"><b>9:47</b><small>5 Min · 1,1 km</small></div><div class="cptest">${icon(I.clock, 13)} Test 4:12</div><div class="osm" style="right:12px;bottom:8px">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div></div>`));
  }],
];

/** Nebel fürs Video: dunkler Schleier, gefahrene Straßen schmal ausgeschnitten (bleibt auch schräg ruhig) */
function fogLite(u, v, ls) {
  u.save(); u.fillStyle = 'rgba(8,8,10,.62)'; u.fillRect(0, 0, v.W, v.H);
  u.globalCompositeOperation = 'destination-out'; u.lineCap = 'round'; u.lineJoin = 'round';
  for (const [w, a] of [[40, 0.35], [22, 1]]) { u.strokeStyle = `rgba(0,0,0,${a})`; u.lineWidth = w * v.cam.scale; u.beginPath(); for (const pts of ls) { let on = false; for (const p of pts) { const q = v.project(p); if (q[2] <= 0) { on = false; continue; } on ? u.lineTo(q[0], q[1]) : u.moveTo(q[0], q[1]); on = true; } } u.stroke(); }
  u.restore();
}

/** GM-041/044: Replay-Video in voller Größe (16:9 wie der CarPlay-Bildschirm) – Bild für Bild über window.__rvDraw(i), für den Export mit ffmpeg */
function videoPlayer() {
  document.body.style.background = '#000';
  const nw = new Set(newOnTrip()), newPct = Math.round(newOnTrip().reduce((t, k) => t + info.get(k).len, 0) / R.length * 100);
  const share = cityShare(explored), lv = levelFor(share), was = cityShare(before);
  const el = $(`<div id="rv" class="dph B" style="width:960px;height:540px;border-radius:0;box-shadow:none;margin:0"><div class="fill"></div>
    <div class="rvtop"><b>EzMaps</b></div>
    <div class="rvtitle"><small>Fahrt zum</small><b>Hexenturm</b><span>1,9 km · 6 Min</span></div>
    <div class="rvend"><div class="rvbig">+${newPct} %</div><div class="rvsub">neue Straßen</div><div class="rvlv"><span>Idstein-${lv.title} · Stufe ${lv.number}</span><div class="rvbar"><i style="width:${share / (lv.next ?? 1) * 100}%"></i><s style="left:${was / (lv.next ?? 1) * 100}%"></s></div></div></div>
    <div class="rvosm">© OpenMapTiles · © OpenStreetMap-Mitwirkende</div></div>`);
  main.replaceWith(el);
  const v = new MapView(el.querySelector('.fill')); v.setTexture(tex.neon, 'neon');
  const frames = planReplay(R.pts, { W: 560, H: 540, followScale: 1.6, duration: 10, fps: 30 }) // W: Kartenfläche rechts der Tafeln;
  const title = el.querySelector('.rvtitle'), end = el.querySelector('.rvend');
  window.__rvCount = frames.length;
  window.__rvDraw = i => {
    const fr = frames[i], t = i / (frames.length - 1), u = v.apply({ center: fr.center, heading: fr.heading, scale: fr.scale, tilt: fr.tilt, anchor: [0.62, 0.66] }); // GM-044: wie CarPlay, Auto rechts der Infotafel
    fogLite(u, v, lines(before)); glow(u, v, lines(before), [196, 120, 255], 0.45, 1.6);
    const upto = fr.progress * R.length, seg = [];
    for (let k = 1; k < R.pts.length && R.cum[k - 1] < upto; k++) seg.push([R.pts[k - 1], R.pts[k], nw.has(R.edges[k - 1])]);
    if (seg.length) seg.push([seg.at(-1)[1], pointAt(R.pts, R.cum, upto).p, seg.at(-1)[2]]);
    glow(u, v, seg.filter(x => !x[2]).map(x => [x[0], x[1]]), [170, 80, 240], 1, 6);
    glow(u, v, seg.filter(x => x[2]).map(x => [x[0], x[1]]), [214, 140, 255], 1, 7);
    if (fr.progress >= 1) drawDestination(u, v, R.pts.at(-1), 'neon', 9);
    else drawPlayer(u, v, pointAt(R.pts, R.cum, upto).p, fr.heading, 'neon', 13);
    const a = t < 0.12 ? 1 : Math.max(0, 1 - (t - 0.12) / 0.06);
    title.style.opacity = a; title.style.transform = `translateY(${(1 - a) * -12}px)`;
    const b = Math.min(1, Math.max(0, (t - 0.8) / 0.1));
    end.style.opacity = b; end.style.transform = `scale(${0.92 + 0.08 * b})`;
  };
  window.__rvDraw(0);
}

async function boot() {
  await loadAssets();
  scene = await (await fetch('data/idstein.json')).json();
  router = new Router(scene.graph); R = router.route(scene.presets.start, scene.presets.hexenturm);
  for (const s of ['neon', 'classic']) tex[s] = await renderTexture(scene, s);
  setup();
  await document.fonts.ready;
  if (location.search.includes('video')) { videoPlayer(); window.__ready = true; return; }
  const s = $(`<section class="dsec"><h2>Stadt aufdecken · Design-Konzept</h2><p>Grundregel: Belohnung nur im Stand, während der Fahrt (iPhone und CarPlay) nur ein dünnes Leuchten hinter dir. Logik in js/explore.js und Core/Exploration.swift (Straßenzellen ~24 m, ganz Deutschland, ohne eigene Server).</p><div class="drow"></div></section>`); main.append(s);
  for (const [name, cap, fn] of SCREENS) fn(phone(s.lastElementChild, `<b>${name}</b> · ${cap}`));
  const c = $(`<section class="dsec"><h2>CarPlay</h2><p>Gleiche Regeln im Auto: nichts Neues aufploppen lassen.</p><div class="drow"></div></section>`); main.append(c);
  for (const [name, cap, fn] of CAR) fn(car(c.lastElementChild, `<b>${name}</b> · ${cap}`));
  await new Promise(r => requestAnimationFrame(r)); placeAttribution();
  window.__ready = true;
}
boot().catch(e => { console.error(e); document.body.insertAdjacentHTML('beforeend', `<pre style="color:#f66">${e.stack}</pre>`); });
