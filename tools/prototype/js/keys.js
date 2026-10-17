// Tastatur-Bedienung wie ein Dreh-Drück-Knopf / Pfeiltasten im Auto (CarPlay-Fokus-Steuerung):
// Pfeile = zum nächsten Element in der Richtung, Enter = auswählen, Esc = zurück, Tab = iPhone ↔ CarPlay.
// Im Verschiebe-Modus der Karte (CarPlay) bewegen die Pfeile die Karte.
import { app, set } from './app.js';

let target = 'phone';            // welches Gerät die Tasten bekommt
const focusKey = { phone: null, car: null };
const rootOf = t => document.getElementById(t === 'car' ? 'cui' : 'pui');

const keyOf = el => el.dataset.act + '|' + el.textContent.trim().slice(0, 24);
function candidates(t) {
  const root = rootOf(t);
  // Liegt ein Dialog/Blatt oben, nur dessen Elemente (wie bei iOS)
  const modal = root.querySelector('.ios-sheet-bg .sheet, .ios-alert, .cp-alert');
  return [...(modal || root).querySelectorAll('[data-act]')].filter(el => {
    if (el.classList.contains('ios-sheet-bg')) return false;
    const r = el.getBoundingClientRect(); return r.width > 4 && r.height > 4 && getComputedStyle(el).visibility !== 'hidden';
  });
}
function current(t) { return candidates(t).find(el => keyOf(el) === focusKey[t]) || null; }
function mark() {
  document.querySelectorAll('.kfocus').forEach(el => el.classList.remove('kfocus'));
  const el = current(target); if (el) { el.classList.add('kfocus'); el.scrollIntoView({ block: 'nearest' }); }
  document.getElementById('phone').classList.toggle('ktarget', target === 'phone');
  document.getElementById('car').classList.toggle('ktarget', target === 'car');
}
export const restoreFocus = () => mark();

function move(dir) {
  const list = candidates(target); if (!list.length) return;
  const cur = current(target);
  if (!cur) { focusKey[target] = keyOf(list[0]); return mark(); }
  const c = cur.getBoundingClientRect(), cx = c.left + c.width / 2, cy = c.top + c.height / 2;
  let best = null, bs = Infinity;
  for (const el of list) {
    if (el === cur) continue;
    const r = el.getBoundingClientRect(), x = r.left + r.width / 2, y = r.top + r.height / 2;
    const dx = x - cx, dy = y - cy;
    const main = dir === 'ArrowRight' ? dx : dir === 'ArrowLeft' ? -dx : dir === 'ArrowDown' ? dy : -dy;
    const side = dir === 'ArrowRight' || dir === 'ArrowLeft' ? Math.abs(dy) : Math.abs(dx);
    if (main <= 2) continue;
    const score = main + side * 2.2;
    if (score < bs) { bs = score; best = el; }
  }
  if (best) { focusKey[target] = keyOf(best); mark(); }
}
function back() {
  const root = rootOf(target);
  const el = root.querySelector('.ios-sheet-bg [data-act="sheet:"], [data-act^="close:"], .cp-lhead [data-act], .cp-navbar .back, [data-act="pan:off"], .topbar [data-act]');
  if (el) el.click();
  else if (target === 'phone' && app.state.phone.tab !== 'map' && !app.state.phone.overlay) set({ phone: { tab: 'map' } });
}
export function panBy(key, dx, dy) {
  const b = app.state.browse[key], v = app.views[key], [W, H] = v.size();
  b.center = [b.center[0] + dx * W * 0.25 / b.scale, b.center[1] + dy * H * 0.25 / b.scale];
}

document.addEventListener('pointerdown', e => { if (e.target.closest('#car')) target = 'car'; else if (e.target.closest('#phone')) target = 'phone'; mark(); }, true);
// Bildschirm-Tastatur darf dem Suchfeld den Fokus nicht wegnehmen (GM-007: sonst ging Tippen danach nicht mehr)
document.addEventListener('mousedown', e => { if (e.target.closest('.kbd')) e.preventDefault(); });

document.addEventListener('keydown', e => {
  const inInput = e.target.id === 'q';
  if (e.key === 'Tab') { e.preventDefault(); target = target === 'phone' ? 'car' : 'phone'; return mark(); }
  if (e.key.startsWith('Arrow')) {
    if (inInput && (e.key === 'ArrowLeft' || e.key === 'ArrowRight')) return; // Cursor im Textfeld
    e.preventDefault();
    if (target === 'car' && app.state.car.pan) {
      const d = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] }[e.key];
      return panBy('car', ...d);
    }
    return move(e.key);
  }
  if (e.key === 'Enter') {
    const el = current(target);
    if (el) { e.preventDefault(); el.click(); }
    return;
  }
  if (e.key === 'Escape' || (e.key === 'Backspace' && !inInput)) { e.preventDefault(); back(); }
  if (!inInput && (e.key === '+' || e.key === '-')) { const k = target; app.state.browse[k].scale = Math.max(0.16, Math.min(1.6, app.state.browse[k].scale * (e.key === '+' ? 1.3 : 1 / 1.3))); }
});
