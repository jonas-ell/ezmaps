// GM-052: Zielbilder je Stil (SVG). Gleiche Szene für alle Stile, jeder Stil nach den Referenzen des Nutzers gezeichnet.
'use strict';

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
  'wild-west': s => `<g transform="scale(${s})"><path d="M0 -15 C6 -6 10 -1 10 4 A10 10 0 1 1 -10 4 C-10 -1 -6 -6 0 -15 Z" fill="#f4ecd8" stroke="#1d140c" stroke-width="2.4"/><circle cy="4" r="4.5" fill="none" stroke="#1d140c" stroke-width="2.4"/></g>`,
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
const STYLES = {
  'neon-city': {
    title: 'Neon City', why: 'Nach deinen Pausenkarten-Bildern (Farben gemessen): Boden fast schwarz, Häuser dunkelgrau, Straßen flach mittelgrau ohne Rand, Wasser hellgrau, Symbole meist weiß mit schwarzem Rand. Route lila wie auf deinem Waypoint-Bild. Standort: schmaler hellgrauer Pfeil wie auf der Minikarte. Straßennamen klein und dunkel auf der Straße (zum Navigieren).',
    refs: ['neon-pause-1.png', 'neon-pause-2.png', 'neon-pause-3.png', 'neon-route.png', 'neon-minikarte.png', 'neon-uebersicht.webp'], missing: ['neon-pillbox.png (GTA Pillbox Hill)'],
    draw(o) {
      let s = `<rect width="800" height="480" fill="#181818"/><path d="${poly(PARK)}" fill="#1c1d1c"/>`;
      s += `<path d="${path(STREAM)}" stroke="#6a6a6a" stroke-width="9" fill="none" stroke-linecap="round"/>`;
      s += HOUSES.map(b => `<rect x="${b.x}" y="${b.y}" width="${b.w}" height="${b.h}" fill="#363636"/>`).join('');
      for (const r of roadsSorted()) s += `<path d="${path(r.p)}" stroke="#969696" stroke-width="${WIDTH[r.c]}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
      s += `<path d="${ringPath(RING.r)}" stroke="#969696" stroke-width="20" fill="none"/><circle cx="400" cy="240" r="17" fill="#181818"/>`;
      s += labels('Barlow Condensed', 11, '#141414', { upper: true, spacing: 1.6, id: 'n' });
      s += POIS.map(p => glyph(p.k, p.x, p.y, p.k === 'cross' ? '#ff5fa2' : '#f5f5f5', '#000')).join('');
      if (o.route) s += `<path d="${path(ROUTE)}" stroke="#a13df0" stroke-width="13" fill="none" stroke-linecap="round" stroke-linejoin="round"/>` + destNeon();
      s += marker('neon-city', ME.x, ME.y, ME.h, o.route ? 1.6 : 1.1);
      if (o.look) s += crosshair('rgba(255,255,255,.9)');
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
  'wild-west': {
    title: 'Wild West', why: 'Nach deinen Red-Dead-Bildern: Papierkarte mit Körnung, Straßen in der Stadt als dunkle Doppellinien, kleine Wege als feine Tintenlinien, Häuser hell mit Tintenrand, Wasser grau mit Wellen-Schraffur, Schrift wie Schreibmaschine/Western, Symbole als schwarze runde Knöpfe mit weißem Zeichen. Standort: Tropfen mit Ring wie „Dein Charakter“ in der Legende. Fadenkreuz rot, kurz.',
    refs: ['west-prototyp.png'], missing: ['west-legende.png (Legende)', 'west-stadt.png (Stadtkarte)', 'west-thieves-landing.png (Thieves’ Landing)'],
    draw(o) {
      let s = `<defs><filter id="paper"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="3"/><feColorMatrix values="0 0 0 0 0.25  0 0 0 0 0.18  0 0 0 0 0.1  0 0 0 0.18 0"/></filter>
        <pattern id="hatch" width="10" height="10" patternUnits="userSpaceOnUse"><path d="M0 10 L10 0" stroke="#7a6a48" stroke-width="1"/></pattern>
        <pattern id="wave" width="16" height="8" patternUnits="userSpaceOnUse"><path d="M0 4 Q4 0 8 4 T16 4" stroke="#5f6b66" stroke-width="1" fill="none"/></pattern></defs>`;
      s += `<rect width="800" height="480" fill="#dccba0"/><rect width="800" height="480" filter="url(#paper)"/>`;
      s += `<path d="${poly(PARK)}" fill="url(#hatch)" stroke="#5e4a2c" stroke-width="1" stroke-dasharray="6 4"/>`;
      s += `<path d="${path(STREAM)}" stroke="#3a2a1a" stroke-width="13" fill="none" stroke-linecap="round"/><path d="${path(STREAM)}" stroke="#a3aea6" stroke-width="10" fill="none" stroke-linecap="round"/><path d="${path(STREAM)}" stroke="url(#wave)" stroke-width="10" fill="none"/>`;
      s += HOUSES.map(b => `<rect x="${b.x}" y="${b.y}" width="${b.w}" height="${b.h}" fill="#e6d7b0" stroke="#2a1d12" stroke-width="1.4"/>`).join('');
      for (const r of roadsSorted()) {
        if (r.c >= 3) { s += `<path d="${path(r.p)}" stroke="#2a1d12" stroke-width="${r.c === 3 ? 2.2 : 1.4}" fill="none" stroke-linecap="round"/>`; continue; }
        s += `<path d="${path(r.p)}" stroke="#2a1d12" stroke-width="${WIDTH[r.c] - 6}" fill="none" stroke-linecap="round" stroke-linejoin="round"/><path d="${path(r.p)}" stroke="#ead9b0" stroke-width="${WIDTH[r.c] - 10}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
      }
      s += `<path d="${ringPath(RING.r)}" stroke="#2a1d12" stroke-width="15" fill="none"/><path d="${ringPath(RING.r)}" stroke="#ead9b0" stroke-width="11" fill="none"/>`;
      s += labels('Rye', 12, '#2a1d12', { id: 'w', halo: '#e3d3a8', haloW: 3 });
      s += POIS.map(p => `<g transform="translate(${p.x} ${p.y})"><circle r="13" fill="#1b140e" stroke="#f2e4bf" stroke-width="1.5"/></g>` + glyph(p.k, p.x, p.y, '#fafafa', '#1b140e', 2, 0.6)).join('');
      if (o.route) s += `<path d="${path(ROUTE)}" stroke="#4a0d0a" stroke-width="8" fill="none" stroke-linecap="round" stroke-linejoin="round"/><path d="${path(ROUTE)}" stroke="#c0261f" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>` + destWest();
      s += marker('wild-west', ME.x, ME.y, ME.h, o.route ? 1.4 : 1);
      if (o.look) s += crosshair('rgba(155,22,18,.9)');
      return s;
    },
  },
  'pixel-quest': {
    title: 'Pixel Quest', why: 'Nach deinen Blockwelt-Karten aus den Videos: Gras-Block-Textur, graue Steinstraßen mit dunkler Kante, Häuser als Blöcke (Holz, Fichte, Stein, Ziegel) mit dunkler Seite für den 3D-Eindruck, Blätter-Bäume, Wasser-Textur, weiße Pixelschrift mit schwarzem Schatten, rote Route mit dunklem Rand. Standort: weißer Pixel-Pfeil mit schwarzem Rand wie der Spieler-Marker auf einer Blockwelt-Karte.',
    refs: ['pixel-prototyp.png'], missing: ['pixel-video-1.png', 'pixel-video-2.png', 'pixel-video-3.png (Minecraft-Karten im Auto)'],
    draw(o) {
      const grass = pixelTile(16, (x, y) => { const h = h2(x, y, 1); return h < 0.18 ? '#4f8a2e' : h < 0.42 ? '#6aad3f' : h > 0.93 ? '#79bd4a' : '#5d9b37'; });
      const stone = pixelTile(8, (x, y) => { const h = h2(x, y, 7); return h < 0.25 ? '#767676' : h > 0.85 ? '#aaaaaa' : '#8f8f8f'; });
      const water = pixelTile(16, (x, y) => (y % 5 === 1 && (x + y) % 7 < 3) ? '#6ea0f5' : h2(x, y, 4) < 0.3 ? '#3868d6' : '#3f76e4');
      const roofs = [['#8b6a3e', '#5f4628'], ['#5c4226', '#3b2a17'], ['#7c7c7c', '#555'], ['#923c2c', '#62271c'], ['#8b6a3e', '#5f4628'], ['#5c4226', '#3b2a17']];
      let s = `<defs><pattern id="pg" width="64" height="64" patternUnits="userSpaceOnUse"><image href="${grass}" width="64" height="64" style="image-rendering:pixelated"/></pattern>
        <pattern id="ps" width="32" height="32" patternUnits="userSpaceOnUse"><image href="${stone}" width="32" height="32" style="image-rendering:pixelated"/></pattern>
        <pattern id="pw" width="64" height="64" patternUnits="userSpaceOnUse"><image href="${water}" width="64" height="64" style="image-rendering:pixelated"/></pattern></defs>`;
      s += `<rect width="800" height="480" fill="url(#pg)"/>`;
      s += `<path d="${path(STREAM)}" stroke="url(#pw)" stroke-width="12" fill="none" shape-rendering="crispEdges"/>`;
      // Bäume im Park: Blätterblöcke
      for (let y = 240; y < 380; y += 22) for (let x = 650; x < 780; x += 22) if (h2(x, y, 2) > 0.3) s += `<rect x="${x + 3}" y="${y + 3}" width="18" height="18" fill="#1e4a16"/><rect x="${x}" y="${y}" width="18" height="18" fill="#2f6b22"/><rect x="${x + 3}" y="${y + 3}" width="6" height="6" fill="#48903a"/>`;
      for (const r of roadsSorted()) s += `<path d="${path(r.p)}" stroke="#3c3c3c" stroke-width="${WIDTH[r.c] + 3}" fill="none" stroke-linejoin="round"/><path d="${path(r.p)}" stroke="url(#ps)" stroke-width="${WIDTH[r.c] - 1}" fill="none" stroke-linejoin="round"/>`;
      s += `<path d="${ringPath(RING.r)}" stroke="#3c3c3c" stroke-width="23" fill="none"/><path d="${ringPath(RING.r)}" stroke="url(#ps)" stroke-width="19" fill="none"/><circle cx="400" cy="240" r="18" fill="url(#pg)"/>`;
      s += HOUSES.map(b => { const [top, side] = roofs[b.k]; const d = b.tall ? 9 : 6;
        return `<rect x="${b.x}" y="${b.y + d}" width="${b.w}" height="${b.h}" fill="${side}" shape-rendering="crispEdges"/><rect x="${b.x}" y="${b.y}" width="${b.w}" height="${b.h}" fill="${top}" shape-rendering="crispEdges"/>` +
          `<path d="M${b.x} ${b.y + 4} H${b.x + b.w} M${b.x} ${b.y + 10} H${b.x + b.w} M${b.x} ${b.y + 16} H${b.x + b.w}" stroke="rgba(0,0,0,.18)" stroke-width="1.5"/>`; }).join('');
      s += labels('Press Start 2P', 8, '#fff', { id: 'p', halo: '#000', haloW: 3 });
      const C = { shop: '#d68c28', food: '#c84632', parking: '#2a5bd7', cross: '#dc2828', fuel: '#5a5a60' };
      s += POIS.map(p => `<g transform="translate(${p.x - 11} ${p.y - 11})"><rect width="22" height="22" fill="#000"/><rect x="2" y="2" width="18" height="18" fill="#fff"/><rect x="4" y="4" width="14" height="14" fill="${C[p.k]}"/></g>` + glyph(p.k, p.x, p.y, '#fff', C[p.k], 1.6, 0.42)).join('');
      if (o.route) s += `<path d="${path(ROUTE)}" stroke="#4a0d08" stroke-width="11" fill="none" stroke-linejoin="round"/><path d="${path(ROUTE)}" stroke="#e0362b" stroke-width="7" fill="none" stroke-linejoin="round"/>` + destPixel();
      s += marker('pixel-quest', ME.x, ME.y + 6, ME.h, o.route ? 1.5 : 1);
      return s;
    },
  },
  'toy-town': {
    title: 'Toy Town', why: 'Nach deinem abgenommenen Prototyp-Bild: heller Rasen mit Flecken, Häuser als Spielzeughäuser (bunte Wand, Dach rot/blau/orange/grau, Fenster, dunkler Rand), runde Bäume mit Schatten, dunkler Asphalt mit hellem Gehweg und weißer Mittellinie, Zebrastreifen am Kreisel, Wasser mit Sandrand, runde bunte Symbole, orange Route mit weißem Rand. Standort: rotes Spielzeugauto von oben.',
    refs: ['toy-prototyp.png'], missing: [],
    draw(o) {
      const walls = ['#f6d743', '#fdfdfd', '#ee5a4a', '#7cc3ee', '#f5b041', '#f4e2c4'], roofs = ['#e3412f', '#3d78c9', '#ef7d2d', '#e3412f', '#8b8f96', '#c8372a'];
      let s = `<rect width="800" height="480" fill="#8dc63f"/>`;
      for (let i = 0; i < 26; i++) s += `<ellipse cx="${h2(i, 1, 9) * 800}" cy="${h2(i, 2, 9) * 480}" rx="${20 + h2(i, 3, 9) * 30}" ry="${12 + h2(i, 4, 9) * 14}" fill="#a3d65a"/>`;
      s += `<path d="${poly(PARK)}" fill="#7cc142"/>`;
      s += `<path d="${path(STREAM)}" stroke="#f2d48b" stroke-width="15" fill="none" stroke-linecap="round"/><path d="${path(STREAM)}" stroke="#4ab0ea" stroke-width="10" fill="none" stroke-linecap="round"/>`;
      for (const r of roadsSorted()) s += `<path d="${path(r.p)}" stroke="#c9cbce" stroke-width="${WIDTH[r.c] + 6}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
      s += `<path d="${ringPath(RING.r)}" stroke="#c9cbce" stroke-width="26" fill="none"/>`;
      for (const r of roadsSorted()) s += `<path d="${path(r.p)}" stroke="#66686c" stroke-width="${WIDTH[r.c]}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
      s += `<path d="${ringPath(RING.r)}" stroke="#66686c" stroke-width="20" fill="none"/><circle cx="400" cy="240" r="17" fill="#7cc142" stroke="#c9cbce" stroke-width="3"/>`;
      for (const r of ROADS) if (r.c <= 3) s += `<path d="${path(r.p)}" stroke="#fff" stroke-width="1.6" stroke-dasharray="7 7" fill="none"/>`;
      s += `<g fill="#fff">${[0, 1, 2, 3, 4].map(i => `<rect x="${380 + i * 6}" y="282" width="3.5" height="12"/>`).join('')}</g>`;
      // Bäume im Park
      for (let y = 250; y < 385; y += 26) for (let x = 655; x < 785; x += 26) if (h2(x, y, 5) > 0.35) {
        const r = 8 + h2(x, y, 6) * 3; s += `<ellipse cx="${x + 3}" cy="${y + 4}" rx="${r}" ry="${r * 0.75}" fill="rgba(30,70,20,.35)"/><circle cx="${x}" cy="${y - 3}" r="${r}" fill="#3f9b2d" stroke="#2a6b1f"/><circle cx="${x - 3}" cy="${y - 6}" r="${r * 0.42}" fill="#6cc04a"/>`; }
      s += HOUSES.map(b => { const h = b.tall ? 12 : 7, wall = walls[b.k], roof = b.tall ? '#8b8f96' : roofs[b.k];
        let w = `<rect x="${b.x}" y="${b.y + b.h - h}" width="${b.w}" height="${h + 2}" fill="${wall}" stroke="#2f3640" stroke-width="1"/>`;
        for (let x = b.x + 4; x < b.x + b.w - 5; x += 8) w += `<rect x="${x}" y="${b.y + b.h - h + 2.5}" width="4" height="${h - 5}" fill="#3c8fe0" stroke="#fff" stroke-width=".6"/>`;
        return w + `<rect x="${b.x}" y="${b.y - h}" width="${b.w}" height="${b.h}" rx="2" fill="${roof}" stroke="#2f3640" stroke-width="1.2"/><path d="M${b.x + 2} ${b.y - h + b.h / 2} H${b.x + b.w - 2}" stroke="rgba(0,0,0,.25)"/>`; }).join('');
      s += labels('Fredoka', 12, '#fff', { id: 't', halo: '#2f3640', haloW: 3.5 });
      const C = { food: '#4caf50', parking: '#1f6fe0', shop: '#f5b800', cross: '#e8453c', fuel: '#ff7a00' };
      s += POIS.map(p => `<circle cx="${p.x}" cy="${p.y + 1.5}" r="15" fill="rgba(0,0,0,.25)"/><circle cx="${p.x}" cy="${p.y}" r="14" fill="${C[p.k]}" stroke="#fff" stroke-width="2.5"/>` + glyph(p.k, p.x, p.y, '#fff', C[p.k], 1.4, 0.62)).join('');
      if (o.route) s += `<path d="${path(ROUTE)}" stroke="#fff" stroke-width="12" fill="none" stroke-linecap="round" stroke-linejoin="round"/><path d="${path(ROUTE)}" stroke="#ff7a00" stroke-width="7" fill="none" stroke-linecap="round" stroke-linejoin="round"/>` + destToy();
      s += marker('toy-town', ME.x, ME.y, ME.h, o.route ? 1.25 : 0.95);
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
const destNeon = () => `<g transform="translate(${dx} ${dy}) rotate(45)"><rect x="-13" y="-13" width="26" height="26" rx="6" fill="#a13df0" stroke="#fff" stroke-width="3" style="filter:drop-shadow(0 0 6px #a13df0)"/></g><circle cx="${dx}" cy="${dy}" r="6" fill="none" stroke="#fff" stroke-width="3"/>`;
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
      <svg viewBox="-32 -32 64 64">${MARKER[base](1.8)}</svg> Navigation</div></section>`);
}
