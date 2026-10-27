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
