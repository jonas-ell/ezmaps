// Zeichnet scharfe Detail-Kacheln im Hintergrund (blockiert die Oberfläche nicht).
import { renderRegion } from './map.js';
let scene = null;
self.onmessage = e => {
  const m = e.data;
  if (m.type === 'scene') { scene = m.scene; return; }
  if (m.type === 'tile' && scene) {
    const c = renderRegion(scene, m.style, m.region, m.S);
    const bitmap = c.transferToImageBitmap();
    self.postMessage({ id: m.id, style: m.style, region: m.region, S: m.S, bitmap }, [bitmap]);
  }
};
