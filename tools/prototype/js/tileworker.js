// Zeichnet Kacheln im Hintergrund (blockiert die Oberfläche nicht).
// 'tile': scharfe Detail-Kachel aus der Idstein-Szene (GM-006). 'vtile': Vektorkachel aus dem Netz für ganz Deutschland (GM-015).
// GM-016: Ohne OffscreenCanvas meldet der Worker das, und der Haupt-Thread übernimmt (js/tilejob.js).
import { runTile, runVtile } from './tilejob.js';
let scene = null;
const noOffscreen = typeof OffscreenCanvas === 'undefined';
self.onmessage = async e => {
  const m = e.data;
  if (m.type === 'scene') { scene = m.scene; return; }
  if (noOffscreen) return self.postMessage({ ...m, scene: undefined, nooffscreen: true, error: 'nooffscreen' });
  if (m.type === 'tile' && scene) { const { msg, transfer } = await runTile(m, scene); self.postMessage(msg, transfer); }
  if (m.type === 'vtile') self.postMessage(await runVtile(m));
};
