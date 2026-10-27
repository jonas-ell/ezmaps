// GM-052: Zielbilder je Stil (SVG). Gleiche Szene für alle Stile, jeder Stil nach den Referenzen des Nutzers gezeichnet.
'use strict';
const MC = '../../Assets/Generated/minecraft/';   // Pixel-Quest-Grafiken des Nutzers (nachgepixelt)

// ---------- Szene (800 × 480, wie der CarPlay-Bildschirm) ----------
let seed = 7;
const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
const ROADS = [
  { c: 1, p: [[-20, 334], [200, 302], [372, 250]], name: 'Bahnhofstraße' },
  { c: 1, p: [[428, 232], [600, 214], [820, 190]] },
  { c: 2, p: [[386, 500], [390, 330], [397, 270]], name: 'Wiesbadener Straße' },
  { c: 2, p: [[404, 210], [420, 100], [440, -20]] },
  { c: 3, p: [[-20, 122], [200, 116], [418, 104], [620, 94], [820, 88]], name: 'Am Eichert' },
  { c: 3, p: [[-20, 422], [386, 413], [600, 406], [820, 400]], name: 'Im Lagersboden' },
  { c: 3, p: [[150, -20], [158, 118], [186, 308]] },
  { c: 3, p: [[622, -20], [614, 94], [600, 214], [610, 406], [622, 500]] },
  { c: 4, p: [[158, 118], [250, 64], [300, 44]] },
  { c: 4, p: [[386, 413], [306, 470]] },
];
const RING = { x: 400, y: 240, r: 30 };
const STREAM = [[-10, 468], [140, 440], [250, 456], [330, 500]];
const PARK = [[642, 236], [792, 228], [796, 388], [648, 392]];
const BLOCKS = [[12, 136, 136, 286], [176, 128, 368, 236], [432, 112, 596, 204], [12, 348, 372, 400], [414, 244, 588, 392], [12, 8, 138, 104], [176, 8, 300, 34], [456, 8, 600, 80], [640, 104, 792, 200], [412, 424, 596, 472], [640, 410, 792, 472]];
const HOUSES = [];
for (const [x0, y0, x1, y1] of BLOCKS) {
  for (let y = y0; y < y1 - 14; y += 30) for (let x = x0; x < x1 - 18; x += 0) {
    const w = 22 + rnd() * 18, h = Math.min(y1 - y, 18 + rnd() * 9);
    if (x + w > x1) break;
    if (rnd() > 0.14) HOUSES.push({ x, y, w, h, k: Math.floor(rnd() * 6), tall: rnd() > 0.8 });
    x += w + 6 + rnd() * 6;
  }
}
const POIS = [{ k: 'shop', x: 300, y: 178 }, { k: 'food', x: 520, y: 156 }, { k: 'parking', x: 476, y: 300 }, { k: 'cross', x: 84, y: 204 },
  { k: 'fuel', x: 702, y: 150 }, { k: 'shop', x: 252, y: 380 }];
const ROUTE = [[388, 404], [390, 330], [397, 270], [416, 262], [428, 240], [600, 214], [614, 94]];
const DEST = [612, 120];
const ME = { x: 388, y: 404, h: 0 };
const WIDTH = { 1: 26, 2: 21, 3: 14, 4: 9 };

const path = p => 'M' + p.map(q => q[0].toFixed(1) + ' ' + q[1].toFixed(1)).join(' L');
const poly = p => path(p) + 'Z';
const roadsSorted = () => ROADS.slice().sort((a, b) => b.c - a.c);
const ringPath = r => `M${RING.x - r} ${RING.y} a${r} ${r} 0 1 0 ${2 * r} 0 a${r} ${r} 0 1 0 ${-2 * r} 0`;

// Pixel-Kachel (für Pixel Quest), als Bild-Muster
function pixelTile(n, color, cell = 4) {
  const c = document.createElement('canvas'); c.width = c.height = n * cell; const g = c.getContext('2d');
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) { g.fillStyle = color(x, y); g.fillRect(x * cell, y * cell, cell, cell); }
  return c.toDataURL();
}
function h2(x, y, s) { let h = (Math.imul(x, 374761393) + Math.imul(y, 668265263) + Math.imul(s, 2147483647)) >>> 0; h = Math.imul(h ^ (h >>> 13), 1274126177) >>> 0; return ((h ^ (h >>> 16)) & 0xffff) / 65535; }

// ---------- Symbole ----------
const GLYPH = { // einfache Formen, Mittelpunkt 0,0, Größe ~16
  shop: 'M-8 -2 H8 L6 7 H-6 Z M-5 -2 L-1 -8 M5 -2 L1 -8',
  food: 'M-5 -8 V8 M-8 -8 V-2 Q-5 1 -2 -2 V-8 M5 8 V-8 Q1 -4 3 2 H5',
  parking: 'M-4 8 V-8 H2 Q7 -8 7 -3 Q7 2 2 2 H-4',
  cross: 'M-2.5 -8 H2.5 V-2.5 H8 V2.5 H2.5 V8 H-2.5 V2.5 H-8 V-2.5 H-2.5 Z',
  fuel: 'M-7 8 V-8 H3 V8 Z M3 -3 H6 V5 Q6 7 8 7',
};
const glyph = (k, x, y, fill, stroke, sw = 3, s = 1) =>
  `<g transform="translate(${x} ${y}) scale(${s})"><path d="${GLYPH[k]}" fill="${k === 'cross' || k === 'fuel' || k === 'shop' ? fill : 'none'}" stroke="${stroke}" stroke-width="${sw + 2}" stroke-linejoin="round" stroke-linecap="round"/>` +
  `<path d="${GLYPH[k]}" fill="${k === 'cross' || k === 'fuel' || k === 'shop' ? fill : 'none'}" stroke="${fill}" stroke-width="${sw - 0.5}" stroke-linejoin="round" stroke-linecap="round"/></g>`;

// ---------- Standort-Pfeile je Stil ----------
const MARKER = {
  // GTA-Minikarte: schmaler hellgrauer Pfeil mit dunklem Rand
  'neon-city': s => `<path d="M0 -14 L10 11 L0 6 L-10 11 Z" transform="scale(${s})" fill="#ececec" stroke="#141414" stroke-width="${2.2 / s}" stroke-linejoin="round"/>`,
  // RDR-Legende „Dein Charakter“: Tropfen mit Ring, Spitze in Fahrtrichtung
  'wild-west': s => `<path d="M0 -13 L9 10 L0 5 L-9 10 Z" transform="scale(${s})" fill="#f6ead6" stroke="#2b231b" stroke-width="${2.2 / s}" stroke-linejoin="round"/>`,
  // Blockwelt-Karte: weißer Pixel-Pfeil mit schwarzem Rand
  'pixel-quest': s => { // Pfeilspitze mit Kerbe aus Kunstpixeln
    const rows = { '-5': [0, 0], '-4': [-1, 1], '-3': [-1, 1], '-2': [-2, 2], '-1': [-2, 2], '0': [-3, 3], '1': [-3, 3], '2': [-4, 4] };
    const px = []; for (const [y, [a, b]] of Object.entries(rows)) for (let x = a; x <= b; x++) px.push([x, +y]);
    for (const x of [-4, -3, 3, 4]) px.push([x, 3]); // Kerbe: nur die äußeren Spitzen unten
    const u = 2.6 * s;
    return px.map(([x, y]) => `<rect x="${x * u - u / 2 - 1.2}" y="${y * u - 1.2}" width="${u + 2.4}" height="${u + 2.4}" fill="#000"/>`).join('') +
      px.map(([x, y]) => `<rect x="${x * u - u / 2}" y="${y * u}" width="${u}" height="${u}" fill="#fff"/>`).join(''); },
  // Spielteppich: rotes Spielzeugauto von oben
  'toy-town': s => `<g transform="scale(${s})"><rect x="-9" y="-15" width="18" height="30" rx="6" fill="#e23b2e" stroke="#2f3640" stroke-width="2"/><rect x="-6" y="-9" width="12" height="7" rx="2" fill="#a8dcff" stroke="#2f3640" stroke-width="1.2"/><rect x="-6" y="4" width="12" height="5" rx="2" fill="#a8dcff" stroke="#2f3640" stroke-width="1.2"/><rect x="-11.5" y="-11" width="3" height="6" rx="1" fill="#2f3640"/><rect x="8.5" y="-11" width="3" height="6" rx="1" fill="#2f3640"/><rect x="-11.5" y="5" width="3" height="6" rx="1" fill="#2f3640"/><rect x="8.5" y="5" width="3" height="6" rx="1" fill="#2f3640"/></g>`,
  // Stadtplan: blauer Navi-Pfeil im weißen Kreis
  'classic': s => `<g transform="scale(${s})"><circle r="13" fill="#fff" stroke="rgba(0,0,0,.2)" stroke-width="1"/><path d="M0 -8 L7 7 L0 3 L-7 7 Z" fill="#1a73e8"/></g>`,
};
MARKER['pixel-quest'] = s => `<image href="${MC}Player_(texture)_BE2.webp" x="${-14 * s}" y="${-14 * s}" width="${28 * s}" height="${28 * s}" style="image-rendering:pixelated"/>`;
const marker = (style, x, y, h, s) => `<g transform="translate(${x} ${y}) rotate(${h})">${MARKER[style](s)}</g>`;

// Fadenkreuz wie CrosshairView (kurze Arme mit Lücke, nach außen ausgeblendet)
function crosshair(color, x = 400, y = 240) {
  const g = (id, x1, y1, x2, y2) => `<linearGradient id="${id}" gradientUnits="userSpaceOnUse" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}"><stop offset="0" stop-color="${color}"/><stop offset="1" stop-color="${color}" stop-opacity="0"/></linearGradient>`;
  return `<defs>${g('xr', x + 9, y, x + 119, y)}${g('xl', x - 9, y, x - 119, y)}${g('xd', x, y + 9, x, y + 119)}${g('xu', x, y - 9, x, y - 119)}</defs>
  <g stroke-width="1.6"><line x1="${x + 9}" y1="${y}" x2="${x + 119}" y2="${y}" stroke="url(#xr)"/><line x1="${x - 9}" y1="${y}" x2="${x - 119}" y2="${y}" stroke="url(#xl)"/>
  <line x1="${x}" y1="${y + 9}" x2="${x}" y2="${y + 119}" stroke="url(#xd)"/><line x1="${x}" y1="${y - 9}" x2="${x}" y2="${y - 119}" stroke="url(#xu)"/></g>`;
}

// Straßennamen auf der Straße
function labels(font, size, fill, opts = {}) {
  let out = '';
  ROADS.forEach((r, i) => {
    if (!r.name) return;
    const name = opts.upper ? r.name.toUpperCase() : r.name;
    out += `<path id="lp${i}${opts.id || ''}" d="${path(r.p[0][0] > r.p[r.p.length - 1][0] ? r.p.slice().reverse() : r.p)}" fill="none"/>
      <text font-family="${font}" font-size="${size}" fill="${fill}" letter-spacing="${opts.spacing || 0}" ${opts.halo ? `stroke="${opts.halo}" stroke-width="${opts.haloW || 3}" paint-order="stroke" stroke-linejoin="round"` : ''} dy="${size * 0.35}">
      <textPath href="#lp${i}${opts.id || ''}" startOffset="${r.c === 2 ? 22 : 30}%">${name}</textPath></text>`;
  });
  return out;
}

// ---------- Stile ----------
// weitere Kartensymbole (Neon City, Toy Town)
const POIS_MORE = [{ k: 'coffee', x: 560, y: 340 }, { k: 'shirt', x: 230, y: 64 }, { k: 'cash', x: 700, y: 60 }, { k: 'carwash', x: 106, y: 380 },
  { k: 'cinema', x: 520, y: 448 }, { k: 'barber', x: 330, y: 300 }, { k: 'charge', x: 742, y: 446 }];
const G2 = {
  coffee: 'M-7 -3 H5 V4 Q5 8 1 8 H-3 Q-7 8 -7 4 Z M5 -1 Q9 -1 9 2 Q9 5 5 5 M-4 -9 Q-2 -7 -4 -5 M0 -9 Q2 -7 0 -5',
  shirt: 'M-4 -8 L-9 -5 L-7 0 L-5 -1 V8 H5 V-1 L7 0 L9 -5 L4 -8 Q0 -5 -4 -8 Z',
  cash: 'M-9 -6 H9 V6 H-9 Z M0 -3 V3 M-2 -2 Q0 -4 2 -2 Q-2 0 2 2 Q0 4 -2 2',
  carwash: 'M-8 4 V0 L-5 -4 H5 L8 0 V4 Z M-6 6 V4 M6 6 V4 M-6 -9 V-7 M0 -10 V-8 M6 -9 V-7',
  cinema: 'M-8 -5 H4 V5 H-8 Z M4 -2 L9 -5 V5 L4 2',
  barber: 'M-6 -8 L6 8 M6 -8 L-6 8 M-8 -9 A2 2 0 1 0 -8 -5 M8 -9 A2 2 0 1 1 8 -5',
  charge: 'M2 -10 L-6 1 H0 L-2 10 L6 -2 H0 Z',
};
Object.assign(GLYPH, G2);
const FILLED = new Set(['cross', 'fuel', 'shop', 'shirt', 'cinema', 'charge', 'carwash']);
const blip = (k, x, y, fill, s = 1) => `<g transform="translate(${x} ${y}) scale(${s})"><path d="${GLYPH[k]}" fill="${FILLED.has(k) ? fill : 'none'}" stroke="#000" stroke-width="4.5" stroke-linejoin="round" stroke-linecap="round"/><path d="${GLYPH[k]}" fill="${FILLED.has(k) ? fill : 'none'}" stroke="${fill}" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/></g>`;
const NEON_COL = { cross: '#ff5fa2', coffee: '#4fd4e8', cash: '#f2c94c', charge: '#5fd068', cinema: '#f5f5f5' };

// Wackel-Filter für handgezeichnete Tintenlinien (Wild West)
const INK = `<filter id="ink"><feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="5"/><feDisplacementMap in="SourceGraphic" scale="3.2"/></filter>`;

const STYLES = {
  'neon-city': {
    title: 'Neon City', why: 'Nach deinen Pausenkarten (Farben gemessen). Neu: flacher lila Waypoint ohne Leuchten am Routenende mit dem Fadenkreuz darüber wie auf deinem Bild, breite flache lila Route, viel mehr Symbole im gleichen Look (weiße Silhouetten mit schwarzem Rand, einzelne farbig). Waypoint und Symbole sind eigene Zeichnungen im gleichen Stil.',
    refs: ['neon-route.png', 'neon-pause-1.png', 'neon-pause-2.png', 'neon-pause-3.png', 'neon-minikarte.png', 'neon-uebersicht.webp'], missing: [],
    draw(o) {
      let s = `<rect width="800" height="480" fill="#181818"/><path d="${poly(PARK)}" fill="#1c1d1c"/>`;
      s += `<path d="${path(STREAM)}" stroke="#6a6a6a" stroke-width="9" fill="none" stroke-linecap="round"/>`;
      s += HOUSES.map(b => `<rect x="${b.x}" y="${b.y}" width="${b.w}" height="${b.h}" fill="#363636"/>`).join('');
      for (const r of roadsSorted()) s += `<path d="${path(r.p)}" stroke="#969696" stroke-width="${WIDTH[r.c]}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
      s += `<path d="${ringPath(RING.r)}" stroke="#969696" stroke-width="20" fill="none"/><circle cx="400" cy="240" r="17" fill="#181818"/>`;
      s += labels('Barlow Condensed', 11, '#141414', { upper: true, spacing: 1.6, id: 'n' });
      s += [...POIS, ...POIS_MORE].map(p => blip(p.k, p.x, p.y, NEON_COL[p.k] || '#f5f5f5')).join('');
      if (o.route) s += `<path d="${path(ROUTE)}" stroke="#a13df0" stroke-width="16" fill="none" stroke-linecap="butt" stroke-linejoin="round"/>` + destNeon() + crosshair('rgba(255,255,255,.85)', DEST[0], DEST[1]);
      s += marker('neon-city', ME.x, ME.y, ME.h, o.route ? 1.6 : 1.1);
      if (o.look) s += crosshair('rgba(255,255,255,.9)');
      return s;
    },
  },
  'wild-west': {
    title: 'Wild West (Runde 3, nach deinen Red-Dead-Karten)', why: 'Farben aus deinen Bildern gemessen: helles Pfirsich-Papier (#e4c9a8) fast ohne Struktur, nur ganz weiche hellere/dunklere Flecken. Straßen sind nur dünne dunkelbraune Linien (Hauptstraßen etwas dicker, Feldwege dünner), Bahn als Linie mit Querstrichen, Gemeindegrenzen gestrichelt. Wasser graugrün (#aaa392) ohne Rand, mit weichem Übergang ins Papier. Häuser nur angedeutet: hellere Blöcke mit feinem Rand. Ortsnamen fett in Großbuchstaben, Gebiete in weit gesperrten Großbuchstaben, kleine Namen winzig in Großbuchstaben. Symbole: dunkle runde Knöpfe mit weißem Zeichen. Fadenkreuz: vier dünne durchgehende rote Striche mit Lücke (ohne Ausblenden). Route rot, Ziel rotes X, Standort heller Pfeil mit dunklem Rand.',
    refs: ['west-karte-1.png', 'west-karte-2.png', 'west-karte-3.png'], missing: [],
    draw(o) {
      const ink = '#4a3b2c';
      let s = `<defs><filter id="blot"><feTurbulence type="fractalNoise" baseFrequency="0.006" numOctaves="3" seed="11"/><feColorMatrix values="0 0 0 0 0.55  0 0 0 0 0.42  0 0 0 0 0.3  0 0 0 0.22 0"/></filter>
        <filter id="soft"><feGaussianBlur stdDeviation="3"/></filter></defs>`;
      s += `<rect width="800" height="480" fill="#e4c9a8"/><rect width="800" height="480" filter="url(#blot)"/>`;
      // Gebietsname weit gesperrt (wie AMBARINO, NEW HANOVER)
      s += `<text x="440" y="455" font-family="Libre Baskerville, Georgia, serif" font-size="20" letter-spacing="26" fill="#8a7458" opacity=".7">TAUNUS</text>`;
      // Wasser: Teich rund + Bach, weich
      s += `<g filter="url(#soft)"><ellipse cx="735" cy="335" rx="40" ry="26" fill="#aaa392"/><path d="${path(STREAM)}" stroke="#aaa392" stroke-width="16" fill="none" stroke-linecap="round"/></g>`;
      s += `<ellipse cx="735" cy="335" rx="38" ry="24" fill="#aaa392" opacity=".75"/><path d="${path(STREAM)}" stroke="#aaa392" stroke-width="11" fill="none" stroke-linecap="round" opacity=".85"/>`;
      s += `<text x="735" y="338" text-anchor="middle" font-family="Libre Baskerville, Georgia, serif" font-style="italic" font-size="9" fill="#5e5648">Weiher</text>`;
      // Gemeindegrenze gestrichelt
      s += `<path d="M-10 70 C120 60 220 20 300 -10" stroke="${ink}" stroke-width="1.6" fill="none" stroke-dasharray="7 3 2 3" opacity=".8"/>`;
      // Häuser angedeutet
      s += HOUSES.map(b => `<rect x="${b.x + 2}" y="${b.y + 2}" width="${b.w - 4}" height="${b.h - 4}" fill="#e9d1b2" stroke="#a48c6c" stroke-width=".6"/>`).join('');
      // Straßen: dünne Linien
      for (const r of roadsSorted()) s += `<path d="${path(r.p)}" stroke="${ink}" stroke-width="${{ 1: 2.6, 2: 2.2, 3: 1.4, 4: 1 }[r.c]}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
      s += `<path d="${ringPath(RING.r - 6)}" stroke="${ink}" stroke-width="2.2" fill="none"/>`;
      // Bahn mit Querstrichen
      s += `<path d="M-10 455 L330 470 L810 448" stroke="${ink}" stroke-width="1.6" fill="none"/><path d="M-10 455 L330 470 L810 448" stroke="${ink}" stroke-width="6" fill="none" stroke-dasharray="1.4 7"/>`;
      // Namen: Ort fett, Straßen winzig in Großbuchstaben
      s += `<text x="214" y="68" font-family="Roboto Slab, Georgia, serif" font-weight="800" font-size="17" letter-spacing="1" fill="#3a2d20" stroke="#e4c9a8" stroke-width="3" paint-order="stroke">IDSTEIN</text>`;
      s += labels('Libre Baskerville, Georgia, serif', 7.5, '#4a3b2c', { upper: true, spacing: 1.4, id: 'w', halo: '#e4c9a8', haloW: 2.5 });
      s += POIS.map(p => `<g transform="translate(${p.x} ${p.y})"><circle r="11" fill="#2b231b" stroke="#e9d5b6" stroke-width="1.5"/></g>` + glyph(p.k, p.x, p.y, '#fafafa', '#2b231b', 2, 0.5)).join('');
      if (o.route) s += `<path d="${path(ROUTE)}" stroke="#a8261f" stroke-width="4.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>` +
        `<g transform="translate(${DEST[0]} ${DEST[1]})"><path d="M-9 -9 L9 9 M9 -9 L-9 9" stroke="#a8261f" stroke-width="5" stroke-linecap="round"/></g>`;
      s += marker('wild-west', ME.x, ME.y, ME.h, o.route ? 1.5 : 1.1);
      if (o.look) { const c = '#a8261f', x = 400, y = 240; s += `<g stroke="${c}" stroke-width="2"><path d="M${x - 70} ${y} H${x - 12} M${x + 12} ${y} H${x + 70} M${x} ${y - 70} V${y - 12} M${x} ${y + 12} V${y + 70}"/></g>`; }
      return s;
    },
  },
  'pixel-quest': {
    title: 'Pixel Quest (Runde 3)', why: 'Mit deinen Grafiken: Gras, Bruchstein-Straßen, animiertes Wasser (Water_Item_Animated.gif). Häuser jetzt ordentlich: in Reihen entlang der Straßen, alle gleich ausgerichtet, von oben gesehen (Holzdach mit First, Bruchstein-Sockel, Schatten). Symbole einheitlich 16 × 16 Pixel, doppelt groß: Hähnchen = Essen, Steak = Imbiss, Heiltrank = Krankenhaus, Smaragd = Laden, Holzschild mit P = Parken, Kanister = Tankstelle. Standort: weißer Marker (Standard); grüner Marker als Alternative zum Aussuchen in der App.',
    refs: [], missing: ['pixel-video-*.png (Minecraft-Karten im Auto)'],
    draw(o) {
      const planks = pixelTile(16, (x, y) => { if (y % 4 === 3) return '#5f4628'; if ((x + Math.floor(y / 4) * 6) % 16 === 0) return '#6c5430'; const h = h2(x, y, 21); return h < 0.2 ? '#9c7848' : h > 0.85 ? '#a88454' : '#907848'; }, 2);
      const planksDark = pixelTile(16, (x, y) => { if (y % 4 === 3) return '#3c3018'; const h = h2(x, y, 22); return h < 0.25 ? '#6c5430' : '#604824'; }, 2);
      let s = `<defs><pattern id="mg" width="64" height="64" patternUnits="userSpaceOnUse"><image href="${MC}anothergrasstexture.jpg" width="64" height="64" style="image-rendering:pixelated"/></pattern>
        <pattern id="mc" width="32" height="32" patternUnits="userSpaceOnUse"><image href="${MC}cobblestonetexture.webp" width="32" height="32" style="image-rendering:pixelated"/></pattern>
        <pattern id="mw" width="48" height="48" patternUnits="userSpaceOnUse"><image href="${MC}Water_Item_Animated.gif" width="48" height="48" style="image-rendering:pixelated"/></pattern>
        <pattern id="pl" width="32" height="32" patternUnits="userSpaceOnUse"><image href="${planks}" width="32" height="32" style="image-rendering:pixelated"/></pattern>
        <pattern id="pd" width="32" height="32" patternUnits="userSpaceOnUse"><image href="${planksDark}" width="32" height="32" style="image-rendering:pixelated"/></pattern></defs>`;
      s += `<rect width="800" height="480" fill="url(#mg)"/>`;
      // Teich im Park + Bach, animiert
      s += `<path d="${path(STREAM)}" stroke="#2a3f8a" stroke-width="18" fill="none"/><path d="${path(STREAM)}" stroke="url(#mw)" stroke-width="14" fill="none"/>`;
      s += `<ellipse cx="736" cy="328" rx="38" ry="28" fill="#2a3f8a"/><ellipse cx="736" cy="328" rx="35" ry="25" fill="url(#mw)"/>`;
      // Bäume: Laub-Blöcke mit Stamm-Schatten
      const tree = (x, y) => `<rect x="${x + 5}" y="${y + 5}" width="22" height="22" fill="rgba(0,0,0,.35)"/><rect x="${x}" y="${y}" width="22" height="22" fill="#2e5212"/><rect x="${x + 2}" y="${y + 2}" width="8" height="8" fill="#3c6c18"/><rect x="${x + 12}" y="${y + 6}" width="6" height="6" fill="#487824"/><rect x="${x + 6}" y="${y + 13}" width="7" height="6" fill="#3c6018"/>`;
      for (const [x, y] of [[652, 244], [680, 250], [744, 246], [654, 290], [656, 360], [690, 366], [770, 250]]) s += tree(x, y);
      for (const r of roadsSorted()) s += `<path d="${path(r.p)}" stroke="#2e2e2e" stroke-width="${WIDTH[r.c] + 3}" fill="none" stroke-linejoin="round"/><path d="${path(r.p)}" stroke="url(#mc)" stroke-width="${WIDTH[r.c] - 1}" fill="none" stroke-linejoin="round"/>`;
      s += `<path d="${ringPath(RING.r)}" stroke="#2e2e2e" stroke-width="23" fill="none"/><path d="${ringPath(RING.r)}" stroke="url(#mc)" stroke-width="19" fill="none"/><circle cx="400" cy="240" r="18" fill="url(#mg)"/>`;
      // Häuser: Reihen entlang der Straßen, gleich groß, Satteldach von oben (helle/dunkle Dachhälfte), Bruchstein-Sockel
      const house = (x, y, w, h) => `<rect x="${x + 4}" y="${y + 5}" width="${w}" height="${h}" fill="rgba(0,0,0,.4)"/><rect x="${x}" y="${y}" width="${w}" height="${h}" fill="url(#mc)"/>` +
        `<rect x="${x + 2}" y="${y + 2}" width="${w - 4}" height="${(h - 4) / 2}" fill="url(#pl)"/><rect x="${x + 2}" y="${y + 2 + (h - 4) / 2}" width="${w - 4}" height="${(h - 4) / 2}" fill="url(#pd)"/>` +
        `<rect x="${x + 2}" y="${y + h / 2 - 1}" width="${w - 4}" height="2" fill="#3c3018"/>`;
      const rows = [ // [x0, x1, y] – Häuserreihen parallel zu den Straßen
        [20, 130, 140], [20, 130, 176], [20, 130, 212], [20, 130, 248], [190, 360, 134], [190, 360, 170], [440, 590, 116], [440, 590, 152],
        [20, 360, 352], [430, 590, 252], [430, 590, 290], [430, 590, 330], [430, 590, 366], [650, 790, 112], [650, 790, 150], [420, 590, 430], [650, 790, 418], [20, 130, 20], [20, 130, 56], [470, 590, 20], [190, 290, 14]];
      for (const [x0, x1, y] of rows) for (let x = x0; x + 28 <= x1; x += 36) { if (h2(x, y, 31) < 0.12) continue; s += house(x, y, 28, 22); }
      s += labels('Press Start 2P', 8, '#fff', { id: 'p', halo: '#000', haloW: 3 });
      // Symbole: 16 × 16 Pixel, je 2 px
      const spr = (rows, pal) => pixelTile(16, (x, y) => { const c = (rows[y] || '')[x] || '.'; return pal[c] || 'rgba(0,0,0,0)'; }, 2);
      const potion = spr(['......kk........', '.....kbbk.......', '......kk........', '.....kwwk.......', '.....kwwk.......', '....kwwwwk......', '...kwrrrrwk.....', '..kwrrRrrrrk....', '..krrRRrrrrk....', '..krrrrrrrrk....', '..krrrrrrrrk....', '...krrrrrrk.....', '....kkkkkk......'].map(r => '  ' + r), { k: '#1b1b1b', b: '#8a5a2b', w: '#cfe8ff', r: '#d42a3a', R: '#ff8a9a' });
      const emerald = spr(['', '.....kkkkk......', '....kgGGGgk.....', '...kgGWGGGgk....', '..kgGGWGGGGgk...', '..kgGGGGGGGgk...', '..kggGGGGGggk...', '...kggGGGggk....', '....kggggggk....', '.....kgggk......', '......kgk.......', '.......k........'].map(r => ' ' + r), { k: '#0b3d1a', g: '#17a34a', G: '#41d978', W: '#c8ffd9' });
      const signP = spr(['', '.kkkkkkkkkkkkk..', '.kwwwwwwwwwwwk..', '.kwwkkkkkwwwwk..', '.kwwkwwwwkwwwk..', '.kwwkwwwwkwwwk..', '.kwwkkkkkwwwwk..', '.kwwkwwwwwwwwk..', '.kwwkwwwwwwwwk..', '.kwwwwwwwwwwwk..', '.kkkkkkkkkkkkk..', '......kbk.......', '......kbk.......', '......kbk.......', '.....kkkkk......'], { k: '#2a1c0e', w: '#b8945c', b: '#6c5430' });
      const can = spr(['', '.....kkkk.......', '....kyyyk.......', '..kkkkkkkkk.....', '..krrrrrrrk.....', '..krwwrrrrk.....', '..krrrrrrrk.....', '..krrwwrrrk.....', '..krrrrrrrk.....', '..krrrrrwwk.....', '..krrrrrrrk.....', '..kkkkkkkkk.....'].map(r => ' ' + r), { k: '#1b1b1b', y: '#f2c230', r: '#c23a2a', w: '#e86a50' });
      const ic = { cross: potion, shop: emerald, parking: signP, fuel: can };
      const icon = (href, x, y) => `<g transform="translate(${x - 16} ${y - 16})"><image href="${href}" width="32" height="32" style="image-rendering:pixelated;filter:drop-shadow(1.5px 1.5px 0 rgba(0,0,0,.6))"/></g>`;
      s += POIS.map(p => icon(p.k === 'food' ? MC + 'Cooked_Chicken_JE2_BE2.webp' : ic[p.k], p.x, p.y)).join('');
      s += icon(MC + 'Steak_JE4_BE3.webp', 706, 450);
      if (o.route) s += `<path d="${path(ROUTE)}" stroke="#4a0d08" stroke-width="11" fill="none" stroke-linejoin="round"/><path d="${path(ROUTE)}" stroke="#e0362b" stroke-width="7" fill="none" stroke-linejoin="round"/>` +
        `<rect x="${DEST[0] - 3}" y="${DEST[1] - 34}" width="6" height="34" fill="#2a1c0e"/><rect x="${DEST[0] + 3}" y="${DEST[1] - 34}" width="24" height="16" fill="#2a1c0e"/><rect x="${DEST[0] + 5}" y="${DEST[1] - 32}" width="20" height="12" fill="#d42a3a"/>`;
      const sz = o.route ? 34 : 26;
      s += `<image href="${MC}Player_(texture)_BE2.webp" x="${ME.x - sz / 2}" y="${ME.y - sz / 2}" width="${sz}" height="${sz}" style="image-rendering:pixelated"/>`;
      return s;
    },
  },
  'toy-town': {
    title: 'Toy Town (neu, wie der Spielteppich)', why: 'Neu nach deinen drei Teppich-Bildern: knallgrüner Rasen, graue Straßen mit gelber Randlinie und weißer gestrichelter Mitte, Zebrastreifen, Kreisverkehr mit Teich in der Mitte, Parkplätze mit blauem P, Fußballfeld, Häuser von schräg vorne (Wand, Fenster, Tür, rotes/blaues/gelbes Dach), runde Büsche und Bäume, alles mit dunklem Umriss. Standort: rotes Spielzeugauto. Eigene Zeichnungen im Teppich-Stil.',
    refs: ['toy-teppich-1.png', 'toy-teppich-2.png', 'toy-teppich-3.png', 'toy-prototyp.png'], missing: [],
    draw(o) {
      let s = `<defs><filter id="felt"><feTurbulence type="fractalNoise" baseFrequency="1.4" seed="4"/><feColorMatrix values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 .12 0"/></filter></defs>`;
      s += `<rect width="800" height="480" fill="#3eb34a"/>`;
      // Fußballfeld im Park
      s += `<rect x="652" y="240" width="140" height="146" fill="#2f9e3c" stroke="#fff" stroke-width="2.5"/><path d="M652 313 H792" stroke="#fff" stroke-width="2"/><circle cx="722" cy="313" r="16" fill="none" stroke="#fff" stroke-width="2"/><rect x="694" y="240" width="56" height="20" fill="none" stroke="#fff" stroke-width="2"/><rect x="694" y="366" width="56" height="20" fill="none" stroke="#fff" stroke-width="2"/>`;
      s += `<path d="${path(STREAM)}" stroke="#1d5a8c" stroke-width="15" fill="none" stroke-linecap="round"/><path d="${path(STREAM)}" stroke="#3aa0e8" stroke-width="11" fill="none" stroke-linecap="round"/>`;
      for (const r of roadsSorted()) s += `<path d="${path(r.p)}" stroke="#3a3a3a" stroke-width="${WIDTH[r.c] + 9}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
      s += `<path d="${ringPath(RING.r)}" stroke="#3a3a3a" stroke-width="29" fill="none"/>`;
      for (const r of roadsSorted()) s += `<path d="${path(r.p)}" stroke="#9a9a9a" stroke-width="${WIDTH[r.c] + 7}" fill="none" stroke-linecap="round" stroke-linejoin="round"/><path d="${path(r.p)}" stroke="#f2c230" stroke-width="${WIDTH[r.c] + 3}" fill="none" stroke-linecap="round" stroke-linejoin="round"/><path d="${path(r.p)}" stroke="#9a9a9a" stroke-width="${WIDTH[r.c] + 1}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
      s += `<path d="${ringPath(RING.r)}" stroke="#9a9a9a" stroke-width="27" fill="none"/><path d="${ringPath(RING.r - 12)}" stroke="#f2c230" stroke-width="2"/><path d="${ringPath(RING.r + 12)}" stroke="#f2c230" stroke-width="2" fill="none"/>`;
      s += `<circle cx="400" cy="240" r="16" fill="#3eb34a" stroke="#3a3a3a" stroke-width="2"/><circle cx="400" cy="240" r="10" fill="#3aa0e8" stroke="#fff" stroke-width="2.5"/>`;
      for (const r of ROADS) if (r.c <= 3) s += `<path d="${path(r.p)}" stroke="#fff" stroke-width="2" stroke-dasharray="9 8" fill="none"/>`;
      s += `<g fill="#fff">${[0, 1, 2, 3, 4, 5].map(i => `<rect x="${378 + i * 7}" y="284" width="4" height="14"/>`).join('')}</g>`;
      // Parkplätze
      s += `<rect x="440" y="250" width="70" height="40" fill="#9a9a9a" stroke="#fff" stroke-width="2"/>${[0, 1, 2].map(i => `<path d="M${463 + i * 23} 250 V290" stroke="#fff" stroke-width="2"/>`).join('')}${[0, 1, 2].map(i => `<rect x="${445 + i * 23}" y="262" width="14" height="14" rx="2" fill="#1f6fe0"/><text x="${452 + i * 23}" y="274" font-family="Fredoka" font-weight="700" font-size="11" fill="#fff" text-anchor="middle">P</text>`).join('')}`;
      // Bäume/Büsche
      const bush = (x, y, r) => `<circle cx="${x + 2}" cy="${y + 3}" r="${r}" fill="#155a1e"/><circle cx="${x}" cy="${y}" r="${r}" fill="#1e7a2a" stroke="#0f3d15" stroke-width="1.2"/><circle cx="${x - r * 0.3}" cy="${y - r * 0.3}" r="${r * 0.45}" fill="#38a845"/>`;
      for (let i = 0; i < 40; i++) { const x = h2(i, 3, 3) * 800, y = h2(i, 4, 3) * 480; if (!HOUSES.some(b => x > b.x - 8 && x < b.x + b.w + 8 && y > b.y - 14 && y < b.y + b.h + 8)) s += bush(x, y, 6 + h2(i, 5, 3) * 3); }
      // Häuser schräg von vorne
      const walls = ['#f6e6b4', '#ffffff', '#f2b8a0', '#cfe6f5', '#f5d76e'], roofs = ['#d9342b', '#2f6fd0', '#f0b400', '#d9342b', '#2f6fd0', '#7a7f87'];
      s += HOUSES.map(b => { if (b.w < 22) return ''; const roof = roofs[b.k], wall = walls[b.k % walls.length], wh = Math.min(12, b.h * 0.5), rh = b.h - wh;
        let w = `<rect x="${b.x}" y="${b.y + rh}" width="${b.w}" height="${wh + 2}" fill="${wall}" stroke="#2b2b2b" stroke-width="1.2"/>`;
        for (let x = b.x + 3; x < b.x + b.w - 6; x += 9) w += `<rect x="${x}" y="${b.y + rh + 2.5}" width="5" height="${wh - 5}" fill="#4aa8e8" stroke="#2b2b2b" stroke-width=".7"/>`;
        w += `<rect x="${b.x + b.w / 2 - 2.5}" y="${b.y + b.h - 6}" width="5" height="8" fill="#8a4b22" stroke="#2b2b2b" stroke-width=".7"/>`;
        return w + `<path d="M${b.x - 2} ${b.y + rh} L${b.x + 4} ${b.y} H${b.x + b.w - 4} L${b.x + b.w + 2} ${b.y + rh} Z" fill="${roof}" stroke="#2b2b2b" stroke-width="1.2" stroke-linejoin="round"/><path d="M${b.x + 4} ${b.y + rh * 0.45} H${b.x + b.w - 4}" stroke="rgba(0,0,0,.2)"/>`; }).join('');
      s += labels('Fredoka', 12, '#fff', { id: 't', halo: '#2b2b2b', haloW: 3.5 });
      const C = { food: '#4caf50', parking: '#1f6fe0', shop: '#f5b800', cross: '#e8453c', fuel: '#ff7a00' };
      s += POIS.map(p => `<circle cx="${p.x}" cy="${p.y + 1.5}" r="15" fill="rgba(0,0,0,.3)"/><circle cx="${p.x}" cy="${p.y}" r="14" fill="${C[p.k]}" stroke="#fff" stroke-width="2.5"/>` + glyph(p.k, p.x, p.y, '#fff', C[p.k], 1.4, 0.62)).join('');
      if (o.route) s += `<path d="${path(ROUTE)}" stroke="#fff" stroke-width="12" fill="none" stroke-linecap="round" stroke-linejoin="round"/><path d="${path(ROUTE)}" stroke="#ff7a00" stroke-width="7" fill="none" stroke-linecap="round" stroke-linejoin="round"/>` + destToy();
      s += `<rect width="800" height="480" filter="url(#felt)"/>`;
      s += marker('toy-town', ME.x, ME.y, ME.h, o.route ? 1.25 : 0.95);
      return s;
    },
  },
  'neon-foto': {
    title: 'Neon City · Variante „Auto-Foto“', why: 'Zum Vergleich: der hellere Look von deinem ersten CarPlay-Foto (mittelgrauer Boden, weiße Straßen mit dunklem Rand). Sag mir, ob Neon City so (Foto) oder wie oben (Pausenkarte) sein soll, oder nah wie Foto und weit weg wie Pausenkarte.',
    refs: ['neon-auto-foto.png'], missing: [],
    draw(o) {
      let s = `<rect width="800" height="480" fill="#3b3c3e"/><path d="${poly(PARK)}" fill="#36383a"/>`;
      s += `<path d="${path(STREAM)}" stroke="#5d6870" stroke-width="9" fill="none" stroke-linecap="round"/>`;
      s += HOUSES.map(b => `<rect x="${b.x}" y="${b.y}" width="${b.w}" height="${b.h}" fill="#5b5c5f" stroke="#4a4b4e"/>`).join('');
      for (const r of roadsSorted()) s += `<path d="${path(r.p)}" stroke="#151617" stroke-width="${WIDTH[r.c] + 4}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
      s += `<path d="${ringPath(RING.r)}" stroke="#151617" stroke-width="24" fill="none"/>`;
      for (const r of roadsSorted()) s += `<path d="${path(r.p)}" stroke="#ececec" stroke-width="${WIDTH[r.c]}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
      s += `<path d="${ringPath(RING.r)}" stroke="#ececec" stroke-width="20" fill="none"/><circle cx="400" cy="240" r="17" fill="#3b3c3e" stroke="#151617" stroke-width="2"/>`;
      s += labels('Barlow Condensed', 12, '#1d1e20', { upper: true, spacing: 1.6, id: 'f' });
      s += POIS.map(p => glyph(p.k, p.x, p.y, '#f5f5f5', '#000')).join('');
      if (o.route) s += `<path d="${path(ROUTE)}" stroke="#4b1a73" stroke-width="12" fill="none" stroke-linecap="round" stroke-linejoin="round"/><path d="${path(ROUTE)}" stroke="#a13df0" stroke-width="8" fill="none" stroke-linecap="round" stroke-linejoin="round"/>` + destNeon();
      s += marker('neon-city', ME.x, ME.y, ME.h, o.route ? 1.6 : 1.1);
      return s;
    },
  },
  'classic': {
    title: 'Klassik (gratis)', why: 'Keine Referenz von dir: ruhiger heller Stadtplan (bewusst schlicht, damit sich die Spiel-Stile lohnen). Standort: blauer Navi-Pfeil im weißen Kreis.',
    refs: [], missing: [],
    draw(o) {
      let s = `<rect width="800" height="480" fill="#f2efe9"/><path d="${poly(PARK)}" fill="#d4ebc8"/>`;
      s += `<path d="${path(STREAM)}" stroke="#aad3df" stroke-width="9" fill="none" stroke-linecap="round"/>`;
      s += HOUSES.map(b => `<rect x="${b.x}" y="${b.y}" width="${b.w}" height="${b.h}" fill="#ddd5cc" stroke="#cbc0b5"/>`).join('');
      for (const r of roadsSorted()) s += `<path d="${path(r.p)}" stroke="#c9c1b6" stroke-width="${WIDTH[r.c] * 0.75 + 3}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
      s += `<path d="${ringPath(RING.r)}" stroke="#c9c1b6" stroke-width="17" fill="none"/>`;
      for (const r of roadsSorted()) s += `<path d="${path(r.p)}" stroke="${r.c === 1 ? '#fde7a6' : '#fff'}" stroke-width="${WIDTH[r.c] * 0.75}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
      s += `<path d="${ringPath(RING.r)}" stroke="#fff" stroke-width="14" fill="none"/>`;
      s += labels('Barlow Condensed', 11, '#4a4a4a', { upper: true, spacing: 1.2, id: 'c', halo: '#fff', haloW: 2.5 });
      s += POIS.map(p => glyph(p.k, p.x, p.y, '#f5f5f5', '#000')).join('');
      if (o.route) s += `<path d="${path(ROUTE)}" stroke="#0b3d91" stroke-width="10" fill="none" stroke-linecap="round" stroke-linejoin="round"/><path d="${path(ROUTE)}" stroke="#1a73e8" stroke-width="7" fill="none" stroke-linecap="round" stroke-linejoin="round"/>` + destClassic();
      s += marker('classic', ME.x, ME.y, ME.h, o.route ? 1.4 : 1);
      return s;
    },
  },
};
// Ziel-Symbole (wie RouteOverlay.destinationImage)
const [dx, dy] = DEST;
const destNeon = () => `<path transform="translate(${dx} ${dy})" d="M0 -15 C4 -6 6 -4 15 0 C6 4 4 6 0 15 C-4 6 -6 4 -15 0 C-6 -4 -4 -6 0 -15 Z" fill="#a13df0" stroke="#5a1d8c" stroke-width="1.5"/>`;
const destWest = () => `<g transform="translate(${dx - 24} ${dy - 24})"><path d="M42 24 A18 18 0 1 1 41 19" fill="none" stroke="#3a2414" stroke-width="2.2"/><path d="M14 14 L34 34 M34.5 13.5 L13.5 34.5" stroke="#c0261f" stroke-width="6" stroke-linecap="round"/></g>`;
const destPixel = () => `<g transform="translate(${dx - 18} ${dy - 48})" shape-rendering="crispEdges"><rect x="12" y="3" width="6" height="45" fill="#1b1206"/><rect x="15" y="3" width="3" height="42" fill="#8a5a2b"/><rect x="18" y="3" width="27" height="21" fill="#1b1206"/><rect x="18" y="6" width="24" height="15" fill="#e8453c"/><rect x="21" y="9" width="9" height="6" fill="#ffcc33"/></g>`;
const destToy = () => `<g transform="translate(${dx - 14} ${dy - 46})"><rect x="12" y="8" width="4" height="38" rx="2" fill="#2f3640"/><rect x="16" y="8" width="24" height="16" rx="3" fill="#ff7a00"/><g fill="#fff"><rect x="16" y="8" width="8" height="8"/><rect x="32" y="8" width="8" height="8"/><rect x="24" y="16" width="8" height="8"/></g><rect x="16" y="8" width="24" height="16" rx="3" fill="none" stroke="#2f3640" stroke-width="2.5"/><circle cx="14" cy="7" r="4" fill="#2f3640"/></g>`;
const destClassic = () => `<g transform="translate(${dx - 24} ${dy - 46})"><path d="M24 46 C18 36 11 28 11 18 A13 13 0 0 1 37 18 C37 28 30 36 24 46 Z" fill="#e8453c" stroke="#fff" stroke-width="2.5"/><circle cx="24" cy="18" r="5" fill="#fff"/></g>`;

// ---------- Seite ----------
const svg = (inner, w = 800) => `<svg class="scene" viewBox="0 0 800 480" style="width:${w}px">${inner}</svg>`;
const main = document.getElementById('main');
for (const [key, st] of Object.entries(STYLES)) {
  const base = key === 'neon-foto' ? 'neon-city' : key;
  const refs = st.refs.map(f => `<figure><img src="referenzen/${f}" alt="" onerror="this.parentNode.outerHTML='<div class=missing>${f}<br>fehlt</div>'"><figcaption>${f}</figcaption></figure>`).join('') +
    st.missing.map(f => `<div class="missing">${f}<br>fehlt noch</div>`).join('');
  const look = STYLES[key].draw({ look: true }).includes('linearGradient');
  main.insertAdjacentHTML('beforeend', `<section><h2>${st.title}</h2><p class="why">${st.why}</p><div class="row">
    <div class="refs">${refs || '<div class="missing">keine Referenz</div>'}</div>
    <figure>${svg(st.draw({ route: true }))}<figcaption>Zielbild Navigation (Route, Ziel, großer Standort-Pfeil)</figcaption></figure>
    <figure>${svg(st.draw({}), 392)}<figcaption>Zielbild frei fahren (kleiner Standort-Pfeil)</figcaption></figure>
    ${look ? `<figure>${svg(st.draw({ look: true }), 392)}<figcaption>Zielbild beim Umschauen (Fadenkreuz)</figcaption></figure>` : ''}
    </div>
    <div class="markers">Standort-Pfeil:
      <svg viewBox="-32 -32 64 64">${MARKER[base](1.2)}</svg> frei
      <svg viewBox="-32 -32 64 64">${MARKER[base](1.8)}</svg> Navigation${key === 'pixel-quest' ? ` <svg viewBox="-32 -32 64 64"><image href="${MC}Green_Marker_(texture)_BE2.webp" x="-25" y="-25" width="50" height="50" style="image-rendering:pixelated"/></svg> Alternative (in der App wählbar)` : ''}</div></section>`);
}
