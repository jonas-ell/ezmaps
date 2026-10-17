// Icons: zuerst die Codex-Assets (Assets/Generated), sonst Platzhalter (24er Raster, Linien).
import { A, ICON_FILE, CP_FILE, iconSet, pixelIconUrl, pixelManeuverUrl } from './assets.js';
let STYLE = 'neon';
export const setIconStyle = s => { STYLE = s; };
const I = {
  search: '<circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5 21 21"/>',
  home: '<path d="M3 11 12 4l9 7"/><path d="M5.5 9.5V20h13V9.5"/><path d="M10 20v-5h4v5"/>',
  work: '<rect x="3" y="7.5" width="18" height="12" rx="2"/><path d="M9 7.5V5h6v2.5M3 12.5h18"/>',
  fuel: '<path d="M5 20V5.5A1.5 1.5 0 0 1 6.5 4h6A1.5 1.5 0 0 1 14 5.5V20M3.5 20h12M5 10h9"/><path d="M14 8.5l3.5 2.5v6a1.5 1.5 0 0 0 3 0V8l-2.5-2.5"/>',
  parking: '<rect x="3.5" y="3.5" width="17" height="17" rx="3"/><path d="M9.5 17V7.5h3.5a2.75 2.75 0 0 1 0 5.5H9.5"/>',
  layers: '<path d="m12 3.5 9 4.75-9 4.75-9-4.75z"/><path d="m3 12.5 9 4.75 9-4.75"/><path d="m3 16.5 9 4.75 9-4.75" opacity=".5"/>',
  friends: '<circle cx="9" cy="8.5" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><circle cx="17" cy="9.5" r="2.6"/><path d="M16.5 14.2A5.4 5.4 0 0 1 22 19.5"/>',
  locate: '<path d="M20.5 3.5 3.5 11l7 2.5 2.5 7z"/>',
  map: '<path d="M9 4.5 3.5 6.5v13l5.5-2 6 2 5.5-2v-13l-5.5 2z"/><path d="M9 4.5v13M15 6.5v13"/>',
  explore: '<circle cx="12" cy="12" r="8.5"/><path d="m15.5 8.5-2 5-5 2 2-5z"/>',
  style: '<path d="M12 3.5 20 12l-8 8.5L4 12z"/><path d="M12 3.5v17M4 12h16" opacity=".55"/>',
  profile: '<circle cx="12" cy="8.5" r="4"/><path d="M4.5 20.5a7.5 7.5 0 0 1 15 0"/>',
  close: '<path d="M6 6l12 12M18 6 6 18"/>',
  reroute: '<path d="M4 12a8 8 0 0 1 14-5.3M20 12a8 8 0 0 1-14 5.3"/><path d="M18 3v4h-4M6 21v-4h4"/>',
  mic: '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21"/>',
  volume: '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M15.5 9a4 4 0 0 1 0 6M18 6.5a7.5 7.5 0 0 1 0 11"/>',
  mute: '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="m16 9.5 5 5M21 9.5l-5 5"/>',
  share: '<path d="M12 14V3.5M8 7l4-3.5L16 7"/><path d="M6 11v8.5h12V11"/>',
  chevron: '<path d="m9.5 5.5 6.5 6.5-6.5 6.5"/>', back: '<path d="m14.5 5.5-6.5 6.5 6.5 6.5"/>',
  more: '<circle cx="5.5" cy="12" r="1.3" fill="currentColor"/><circle cx="12" cy="12" r="1.3" fill="currentColor"/><circle cx="18.5" cy="12" r="1.3" fill="currentColor"/>',
  plus: '<path d="M12 5v14M5 12h14"/>', minus: '<path d="M5 12h14"/>',
  clip: '<rect x="3.5" y="5.5" width="17" height="13" rx="2.5"/><path d="m10 9.5 5 2.5-5 2.5z" fill="currentColor"/>',
  food: '<path d="M7 3.5v17M4.5 3.5v5a2.5 2.5 0 0 0 5 0v-5M17 20.5V3.5c-2.5 1-3.5 4-3.5 7.5h3.5"/>',
  star: '<path d="m12 3.5 2.6 5.4 5.9.8-4.3 4.1 1 5.8-5.2-2.8-5.2 2.8 1-5.8L3.5 9.7l5.9-.8z"/>',
  pin: '<path d="M12 21s-6.5-6-6.5-11a6.5 6.5 0 0 1 13 0c0 5-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.3"/>',
  clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
  check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
  lock: '<rect x="5" y="10.5" width="14" height="10" rx="2"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
  shield: '<path d="M12 3.5 19.5 6v5.5c0 4.5-3.2 7.8-7.5 9-4.3-1.2-7.5-4.5-7.5-9V6z"/>',
  info: '<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5.5M12 7.8v.2"/>',
  flag: '<path d="M5.5 21V4M5.5 4.5h11l-2 4 2 4h-11"/>',
  turnLeft: '<path d="M15 21V12a4 4 0 0 0-4-4H5"/><path d="m9 4-4 4 4 4"/>',
  turnRight: '<path d="M9 21V12a4 4 0 0 1 4-4h6"/><path d="m15 4 4 4-4 4"/>',
  slightLeft: '<path d="M14 21v-7.5L8 7.5"/><path d="M7.5 12.5v-5h5"/>',
  slightRight: '<path d="M10 21v-7.5l6-6"/><path d="M16.5 12.5v-5h-5"/>',
  straight: '<path d="M12 21V4"/><path d="m7 9 5-5 5 5"/>',
  uturn: '<path d="M8 21V9a4.5 4.5 0 0 1 9 0v6"/><path d="m13.5 12 3.5 3.5 3.5-3.5"/>',
  dest: '<path d="M6.5 21V4M6.5 4.5h11l-2 4 2 4h-11"/>',
};
const sized = (svg, size, extra) => svg.replace('<svg', `<svg class="ic" width="${size}" height="${size}" style="${extra}"`);
export function ic(name, size = 22, extra = '') {
  const f = ICON_FILE[name], set = iconSet(STYLE);
  if (A.ok && f) {
    if (set === 'Pixel') return `<img class="ic pix" src="${pixelIconUrl(f)}" width="${size}" height="${size}" alt="">`;
    if (A.icons[set][f]) return sized(A.icons[set][f], size, extra);
  }
  return placeholder(name, size, extra);
}
// CarPlay-Systemknöpfe: einfarbige Vorlagen (iOS färbt sie), unabhängig vom Stil
export function cpic(name, size = 22, extra = '') {
  const f = CP_FILE[name];
  if (A.ok && f && A.cp[f]) return sized(A.cp[f], size, extra);
  if (A.ok && ICON_FILE[name] && A.icons.Neon[ICON_FILE[name]]) return sized(A.icons.Neon[ICON_FILE[name]], size, extra);
  return placeholder(name, size, extra);
}
// Abbiegepfeile je Stil (CarPlay: Systemkarte, immer neutral)
export function manIc(kind, size = 60, cp = false) {
  const set = cp ? 'Neon' : iconSet(STYLE);
  if (A.ok && set === 'Pixel') return `<img class="ic pix" src="${pixelManeuverUrl(kind)}" width="${size}" height="${size}" alt="">`;
  if (A.ok && A.man[set][kind]) return sized(A.man[set][kind], size, '');
  return placeholder(maneuverIcon(kind), size, 'stroke-width:2.6');
}
const placeholder = (name, size = 22, extra = '') =>
  `<svg class="ic" viewBox="0 0 24 24" width="${size}" height="${size}" style="${extra}" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">${I[name] || ''}</svg>`;
export const maneuverIcon = kind => ({ left: 'turnLeft', right: 'turnRight', 'sharp-left': 'turnLeft', 'sharp-right': 'turnRight', 'slight-left': 'slightLeft', 'slight-right': 'slightRight', 'uturn-left': 'uturn', 'uturn-right': 'uturn', destination: 'dest' })[kind] || 'straight';
