// GM-049: Kartensymbole für live.html und stylepreview.html (App: SF Symbols in RouteOverlay.poiImages)
'use strict';
const POI_COLORS = { shop: '#f5f5f5', cross: '#ff5fa2', fuel: '#f5f5f5', parking: '#f5f5f5', food: '#f5f5f5', charge: '#5fd068' }; // GM-048
function drawPoi(kind, color) {
  const s = 44, c = document.createElement('canvas'); c.width = c.height = s; const g = c.getContext('2d');
  const path = () => {
    g.beginPath();
    if (kind === 'parking') { g.font = '900 34px Inter, Arial'; g.textAlign = 'center'; g.textBaseline = 'middle'; return 'text'; }
    if (kind === 'cross') { g.rect(17, 7, 10, 30); g.rect(7, 17, 30, 10); }
    if (kind === 'shop') { g.moveTo(6, 18); g.lineTo(38, 18); g.lineTo(33, 37); g.lineTo(11, 37); g.closePath(); g.moveTo(13, 18); g.lineTo(19, 8); g.lineTo(21, 9); g.lineTo(16, 18); g.moveTo(31, 18); g.lineTo(25, 8); g.lineTo(23, 9); g.lineTo(28, 18); }
    if (kind === 'fuel') { g.rect(9, 8, 18, 29); g.rect(27, 15, 7, 4); g.rect(31, 15, 3, 18); }
    if (kind === 'food') { g.rect(11, 7, 3, 30); g.rect(7, 7, 2.5, 12); g.rect(15.5, 7, 2.5, 12); g.rect(7, 17, 11, 3); g.moveTo(28, 37); g.lineTo(31, 37); g.lineTo(31, 7); g.quadraticCurveTo(24, 12, 26, 24); g.lineTo(28, 24); g.closePath(); }
    if (kind === 'charge') { g.moveTo(25, 4); g.lineTo(10, 25); g.lineTo(21, 25); g.lineTo(18, 40); g.lineTo(34, 18); g.lineTo(23, 18); g.closePath(); }
    return 'path';
  };
  g.lineJoin = 'round'; g.lineWidth = 6; g.strokeStyle = '#000'; g.fillStyle = color;
  if (path() === 'text') { g.strokeText('P', 22, 24); g.fillText('P', 22, 24); } else { g.stroke(); g.fill(); }
  return g.getImageData(0, 0, s, s);
}


// GM-049: Wild West – schwarzer runder Knopf mit weißem Zeichen (wie RouteOverlay.poiImages „-west“)
function drawPoiBadge(kind) {
  const glyph = drawPoi(kind, '#f8f8f8');
  const c = document.createElement('canvas'); c.width = c.height = 40; const g = c.getContext('2d');
  g.beginPath(); g.arc(20, 20, 18, 0, Math.PI * 2); g.fillStyle = '#1b140e'; g.fill(); g.lineWidth = 1.5; g.strokeStyle = '#f2e4bf'; g.stroke();
  const t = document.createElement('canvas'); t.width = t.height = 44; t.getContext('2d').putImageData(glyph, 0, 0);
  g.drawImage(t, 9, 9, 22, 22);
  return g.getImageData(0, 0, 40, 40);
}
function poiImage(id) {
  const m = /^ez-poi-([a-z]+)(-neon|-west)?$/.exec(id); if (!m) return null;
  return m[2] === '-west' ? drawPoiBadge(m[1]) : drawPoi(m[1], m[2] ? POI_COLORS[m[1]] : '#f5f5f5');
}

// GM-050: Ziel-Symbol je Stil (RouteOverlay.destinationImage) – 48 pt, doppelt gezeichnet
const DEST_STANDS = { classic: true, 'pixel-quest': true, 'toy-town': true };
function drawDest(style) {
  const c = document.createElement('canvas'); c.width = c.height = 96; const g = c.getContext('2d'); g.scale(2, 2);
  g.lineJoin = 'round'; g.lineCap = 'round';
  if (style === 'classic') {
    g.beginPath(); g.moveTo(24, 46); g.bezierCurveTo(18, 36, 11, 28, 11, 18); g.arc(24, 18, 13, Math.PI, 0); g.bezierCurveTo(37, 28, 30, 36, 24, 46);
    g.shadowColor = 'rgba(0,0,0,.4)'; g.shadowBlur = 3; g.shadowOffsetY = 2; g.fillStyle = '#e8453c'; g.fill();
    g.shadowColor = 'transparent'; g.strokeStyle = '#fff'; g.lineWidth = 2.5; g.stroke();
    g.beginPath(); g.arc(24, 18, 5, 0, Math.PI * 2); g.fillStyle = '#fff'; g.fill();
  } else if (style === 'neon-city') {
    g.save(); g.translate(24, 24); g.rotate(Math.PI / 4); g.beginPath(); g.roundRect(-13, -13, 26, 26, 6);
    g.shadowColor = 'rgba(161,61,240,.9)'; g.shadowBlur = 9; g.fillStyle = '#a13df0'; g.fill();
    g.shadowColor = 'transparent'; g.strokeStyle = '#fff'; g.lineWidth = 3; g.stroke(); g.restore();
    g.beginPath(); g.arc(24, 24, 6, 0, Math.PI * 2); g.strokeStyle = '#fff'; g.lineWidth = 3; g.stroke();
  } else if (style === 'wild-west') {
    g.strokeStyle = '#3a2414'; g.lineWidth = 2.2; g.beginPath(); g.arc(24, 24, 18, 0.3, 2 * Math.PI - 0.2); g.stroke();
    g.lineWidth = 1.2; g.beginPath(); g.arc(24.8, 23.4, 17.2, 1.2, 2 * Math.PI + 0.6); g.stroke();
    g.strokeStyle = '#c0261f'; g.lineWidth = 6; g.beginPath(); g.moveTo(14, 14); g.lineTo(34, 34); g.moveTo(34.5, 13.5); g.lineTo(13.5, 34.5); g.stroke();
  } else if (style === 'pixel-quest') {
    const px = (x, y, w, h, col) => { g.fillStyle = col; g.fillRect(6 + x * 3, y * 3, w * 3, h * 3); };
    px(2, 1, 2, 15, '#1b1206'); px(3, 1, 1, 14, '#8a5a2b'); px(4, 1, 9, 7, '#1b1206'); px(4, 2, 8, 5, '#e8453c'); px(5, 3, 3, 2, '#ffcc33'); px(0, 15, 7, 1, '#1b1206');
  } else {
    g.fillStyle = '#2f3640'; g.beginPath(); g.roundRect(12, 8, 4, 38, 2); g.fill();
    g.fillStyle = '#ff7a00'; g.beginPath(); g.roundRect(16, 8, 24, 16, 3); g.fill();
    g.fillStyle = '#fff'; for (let r = 0; r < 2; r++) for (let k = 0; k < 3; k++) if ((r + k) % 2 === 0) g.fillRect(16 + k * 8, 8 + r * 8, 8, 8);
    g.strokeStyle = '#2f3640'; g.lineWidth = 2.5; g.beginPath(); g.roundRect(16, 8, 24, 16, 3); g.stroke();
    g.fillStyle = '#2f3640'; g.beginPath(); g.arc(14, 7, 4, 0, Math.PI * 2); g.fill();
  }
  return g.getImageData(0, 0, 96, 96);
}

// GM-050: Muster und Symbole für Pixel Quest (Blockwelt) und Toy Town – Abbild von StylePatterns in App/NeonMapView.swift
function patHash(x, y, seed) {
  let h = (Math.imul(x, 374761393) + Math.imul(y, 668265263) + Math.imul(seed, 2147483647)) >>> 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177) >>> 0;
  return ((h ^ (h >>> 16)) & 0xffff) / 65535;
}
const rgbS = (r, g, b) => `rgb(${r},${g},${b})`;
function pixelTile(cells, color) {   // Kunstpixel je 2 pt, doppelt gezeichnet → pixelRatio 2
  const c = document.createElement('canvas'); c.width = c.height = cells * 4; const g = c.getContext('2d');
  for (let y = 0; y < cells; y++) for (let x = 0; x < cells; x++) { g.fillStyle = color(x, y); g.fillRect(x * 4, y * 4, 4, 4); }
  return g.getImageData(0, 0, c.width, c.height);
}
function toyTreeJS(g, x, y, r) {
  g.fillStyle = 'rgba(30,70,20,0.35)'; g.beginPath(); g.ellipse(x + r * 0.35, y + r * 0.45, r, r * 0.75, 0, 0, 7); g.fill();
  g.fillStyle = rgbS(63, 155, 45); g.strokeStyle = rgbS(42, 107, 31); g.lineWidth = 1; g.beginPath(); g.arc(x, y - r * 0.4, r, 0, 7); g.fill(); g.stroke();
  g.fillStyle = rgbS(108, 192, 74); g.beginPath(); g.arc(x - r * 0.3, y - r * 0.75, r * 0.42, 0, 7); g.fill();
}
function canvasTile(size, draw) {
  const c = document.createElement('canvas'); c.width = c.height = size * 2; const g = c.getContext('2d'); g.scale(2, 2); draw(g);
  return g.getImageData(0, 0, c.width, c.height);
}
const PATTERNS = {
  'ez-pat-grass-px': () => pixelTile(16, (x, y) => { const h = patHash(x, y, 1); return h < 0.18 ? rgbS(79, 138, 46) : h < 0.42 ? rgbS(106, 173, 63) : h > 0.93 ? rgbS(121, 189, 74) : rgbS(93, 155, 55); }),
  'ez-pat-leaves-px': () => pixelTile(16, (x, y) => { const h = patHash(x, y, 3); return h < 0.25 ? rgbS(30, 74, 22) : h < 0.55 ? rgbS(47, 107, 34) : h > 0.9 ? rgbS(72, 140, 50) : rgbS(38, 92, 28); }),
  'ez-pat-water-px': () => pixelTile(16, (x, y) => { const h = patHash(x, y, 4); return (y % 5 === 1 && (x + y) % 7 < 3) ? rgbS(110, 160, 245) : h < 0.3 ? rgbS(56, 104, 214) : rgbS(63, 118, 228); }),
  'ez-pat-farm-px': () => pixelTile(16, (x, y) => y % 4 === 3 ? rgbS(110, 72, 40) : patHash(x, y, 5) < 0.3 ? rgbS(214, 190, 80) : rgbS(181, 154, 69)),
  'ez-pat-stone-px': () => pixelTile(16, (x, y) => { const h = patHash(x, y, 6); return h < 0.2 ? rgbS(110, 110, 110) : h > 0.85 ? rgbS(160, 160, 160) : rgbS(138, 138, 138); }),
  'ez-pat-road-px': () => pixelTile(8, (x, y) => { const h = patHash(x, y, 7); return h < 0.25 ? rgbS(118, 118, 118) : h > 0.85 ? rgbS(170, 170, 170) : rgbS(143, 143, 143); }),
  'ez-pat-oak-px': () => pixelTile(16, (x, y) => (x === 15 || y === 15) ? rgbS(70, 50, 26) : y % 4 === 3 ? rgbS(84, 62, 34) : (x + Math.floor(y / 4) * 5) % 8 === 0 ? rgbS(98, 72, 40) : patHash(x, y, 8) < 0.25 ? rgbS(150, 116, 66) : rgbS(139, 106, 62)),
  'ez-pat-spruce-px': () => pixelTile(16, (x, y) => (x === 15 || y === 15) ? rgbS(40, 27, 14) : y % 4 === 3 ? rgbS(52, 36, 20) : patHash(x, y, 9) < 0.25 ? rgbS(104, 76, 46) : rgbS(92, 66, 38)),
  'ez-pat-cobble-px': () => pixelTile(16, (x, y) => ((x + (Math.floor(y / 4) % 2) * 2) % 4 === 0 || y % 4 === 0) ? rgbS(80, 80, 80) : patHash(x, y, 10) < 0.3 ? rgbS(150, 150, 150) : rgbS(124, 124, 124)),
  'ez-pat-brick-px': () => pixelTile(16, (x, y) => (y % 4 === 3 || (x + (Math.floor(y / 4) % 2) * 4) % 8 === 7) ? rgbS(196, 180, 170) : patHash(x, y, 11) < 0.3 ? rgbS(160, 70, 52) : rgbS(146, 60, 44)),
  'ez-pat-lawn-toy': () => canvasTile(64, g => { g.fillStyle = rgbS(141, 198, 63); g.fillRect(0, 0, 64, 64); g.fillStyle = rgbS(163, 214, 90);
    g.beginPath(); g.ellipse(17, 16.5, 11, 6.5, 0, 0, 7); g.fill(); g.beginPath(); g.ellipse(47, 45.5, 9, 5.5, 0, 0, 7); g.fill(); }),
  'ez-pat-trees-toy': () => canvasTile(32, g => { g.fillStyle = rgbS(98, 178, 53); g.fillRect(0, 0, 32, 32); toyTreeJS(g, 9, 11, 6); toyTreeJS(g, 25, 27, 5.5); }),
  'ez-pat-park-toy': () => canvasTile(48, g => { g.fillStyle = rgbS(124, 193, 66); g.fillRect(0, 0, 48, 48); toyTreeJS(g, 16, 20, 6); }),
};
const PIXEL_GLYPHS = {
  parking: ['#####..', '#....#.', '#....#.', '#####..', '#......', '#......', '#......'],
  shop: ['#......', '.######', '.#....#', '.#....#', '.######', '..#..#.', '.......'],
  food: ['#.#.#.#', '#.#.#.#', '#####.#', '..#..##', '..#...#', '..#...#', '..#...#'],
  cross: ['..###..', '..###..', '#######', '#######', '#######', '..###..', '..###..'],
  fuel: ['####...', '#..#.#.', '#..#..#', '####..#', '####..#', '####.#.', '####...'],
  charge: ['...##..', '..##...', '.##....', '######.', '...##..', '..##...', '.##....'],
};
const PIXEL_COLORS = { parking: rgbS(42, 91, 215), shop: rgbS(214, 140, 40), food: rgbS(200, 70, 50), cross: rgbS(220, 40, 40), fuel: rgbS(90, 90, 96), charge: rgbS(50, 160, 70) };
function pixelSign(kind) {
  const rows = PIXEL_GLYPHS[kind] || [];
  return pixelTile(13, (x, y) => {
    if (x === 0 || y === 0 || x === 12 || y === 12) return '#000';
    if (x === 1 || y === 1 || x === 11 || y === 11) return '#fff';
    const gx = x - 3, gy = y - 3;
    if (gx >= 0 && gy >= 0 && gy < rows.length && gx < 7 && rows[gy][gx] === '#') return '#fff';
    return PIXEL_COLORS[kind] || '#888';
  });
}
const TOY_COLORS = { food: rgbS(76, 175, 80), parking: rgbS(31, 111, 224), shop: rgbS(245, 184, 0), cross: rgbS(232, 69, 60), fuel: rgbS(255, 122, 0), charge: rgbS(43, 181, 160) };
function toyBadge(kind) {
  const glyph = drawPoi(kind, '#ffffff');
  const t = document.createElement('canvas'); t.width = t.height = 44; t.getContext('2d').putImageData(glyph, 0, 0);
  return canvasTile(40, g => {
    g.shadowColor = 'rgba(0,0,0,.35)'; g.shadowBlur = 2; g.shadowOffsetY = 1.5;
    g.fillStyle = TOY_COLORS[kind] || '#888'; g.beginPath(); g.arc(20, 20, 17, 0, 7); g.fill();
    g.shadowColor = 'transparent'; g.strokeStyle = '#fff'; g.lineWidth = 2.5; g.stroke();
    g.drawImage(t, 9, 9, 22, 22);
  });
}
// GM-067: Haus-Bilder wie in der App aus dem Asset-Katalog (Toy Town: Spielzeughäuser, Pixel Quest: Villager-Häuser) – vor der Karte laden
const ASSET_IMAGES = {};
async function preloadAssetImages(base) {
  const sets = { ToyTown: ['toy-house-1', 'toy-house-2', 'toy-house-3', 'toy-house-4', 'toy-house-5', 'toy-house-6', 'toy-shop', 'toy-school', 'toy-police', 'toy-apartment'],
    PixelQuest: ['px-house-1', 'px-house-2', 'px-house-3', 'px-house-4'] };
  const jobs = [];
  for (const [dir, names] of Object.entries(sets)) for (const n of names) {
    jobs.push(new Promise(ok => { const im = new Image(); im.onload = () => { ASSET_IMAGES[n] = im; ok(); }; im.onerror = ok;
      im.src = `${base}App/Assets.xcassets/${dir}/${n}.imageset/${n}@2x.png`; }));
  }
  await Promise.all(jobs);
}

// Bild für einen fehlenden Namen (styleimagemissing): Symbole und Muster aller Stile; pixelRatio dazu
function styleImage(id) {
  if (ASSET_IMAGES[id]) return { data: ASSET_IMAGES[id], pixelRatio: 2 };
  if (PATTERNS[id]) return { data: PATTERNS[id](), pixelRatio: 2 };
  const m = /^ez-poi-([a-z]+)(-neon|-west|-px|-toy)?$/.exec(id); if (!m) return null;
  if (m[2] === '-px') return { data: pixelSign(m[1]), pixelRatio: 2 };
  if (m[2] === '-toy') return { data: toyBadge(m[1]), pixelRatio: 2 };
  return { data: poiImage(id), pixelRatio: 1 };
}
