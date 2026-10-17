// Lädt die Codex-Assets aus Assets/Generated (siehe docs/ASSETS_CODEX.md) für den Prototyp.
// Der Server muss das Repo-Wurzelverzeichnis ausliefern (serve.py tut das).
export const BASE = '../../Assets/Generated/';

// Unsere Icon-Namen -> Codex-Dateinamen
export const ICON_FILE = {
  search: 'ic-search', home: 'ic-home', work: 'ic-work', fuel: 'ic-fuel', parking: 'ic-parking', layers: 'ic-layers', friends: 'ic-friends',
  locate: 'ic-locate', map: 'ic-tab-map', explore: 'ic-tab-explore', style: 'ic-tab-styles', profile: 'ic-tab-profile', close: 'ic-close',
  reroute: 'ic-reroute', mic: 'ic-mic', volume: 'ic-volume-on', mute: 'ic-volume-off', share: 'ic-share', chevron: 'ic-chevron', back: 'ic-back',
  more: 'ic-more', plus: 'ic-zoom-in', minus: 'ic-zoom-out', clip: 'ic-clip', food: 'ic-food', star: 'ic-favorite', pin: 'ic-district',
  clock: 'ic-history', lock: 'ic-lock', flag: 'ic-end-route', charging: 'ic-charging', north: 'ic-north', settings: 'ic-settings',
  fog: 'ic-fog', badge: 'ic-badge', goal: 'ic-goal', stats: 'ic-stats', streak: 'ic-streak', eyeOff: 'ic-eye-off', contact: 'ic-contact',
};
export const CP_FILE = { search: 'cp-search', layers: 'cp-style', style: 'cp-style', friends: 'cp-friends', plus: 'cp-zoom-in', minus: 'cp-zoom-out', locate: 'cp-locate', home: 'cp-home', work: 'cp-work', fuel: 'cp-fuel', parking: 'cp-parking', star: 'cp-favorite', clock: 'cp-history', charging: 'cp-charging' };
export const MANEUVERS = ['straight', 'slight-left', 'left', 'sharp-left', 'slight-right', 'right', 'sharp-right', 'uturn-left', 'uturn-right', 'destination'];
const BLIPS = ['fuel', 'parking', 'food', 'shop', 'charging', 'hospital', 'friend', 'home', 'work', 'destination', 'waypoint'];
export const BADGES = ['first-drive', '10-km', '100-km', 'night-owl', 'early-bird', 'old-town', 'explorer-25', 'explorer-50', 'explorer-100', 'weekly-goal', 'streak-7', 'convoy'];

export const A = { icons: { Neon: {}, Western: {} }, cp: {}, man: { Neon: {}, Western: {} }, blips: { Neon: {}, Western: {}, Pixel: {} }, player: {}, ok: false };

const text = async url => { const r = await fetch(url); if (!r.ok) throw new Error(url); return r.text(); };
const img = url => new Promise(res => { const i = new Image(); i.onload = () => res(i); i.onerror = () => res(null); i.src = url; });
// SVG zum Einbetten: feste Größe raus, Farbe über currentColor steuerbar machen
const clean = svg => svg.replace(/<svg([^>]*?)\s(width|height)="[^"]*"/g, '<svg$1').replace(/<svg([^>]*?)\s(width|height)="[^"]*"/g, '<svg$1').replace(/#000000/g, 'currentColor');

export async function loadAssets() {
  try {
    const jobs = [];
    for (const set of ['Neon', 'Western']) {
      for (const f of new Set(Object.values(ICON_FILE))) jobs.push(text(`${BASE}Icons/${set}/${f}.svg`).then(t => A.icons[set][f] = clean(t)).catch(() => {}));
      for (const m of MANEUVERS) jobs.push(text(`${BASE}Maneuvers/${set}/maneuver-${m}.svg`).then(t => A.man[set][m] = clean(t)).catch(() => {}));
    }
    for (const f of new Set(Object.values(CP_FILE))) jobs.push(text(`${BASE}CarPlay/${f}.svg`).then(t => A.cp[f] = clean(t)).catch(() => {}));
    for (const b of BLIPS) {
      jobs.push(img(`${BASE}Blips/Neon/blip-${b}.svg`).then(i => A.blips.Neon[b] = i));
      jobs.push(img(`${BASE}Blips/Western/blip-${b}.svg`).then(i => A.blips.Western[b] = i));
      jobs.push(img(`${BASE}Blips/Pixel/blip-${b}.png`).then(i => A.blips.Pixel[b] = i));
    }
    for (const p of ['player-neon.svg', 'player-western.svg']) jobs.push(img(`${BASE}Player/${p}`).then(i => A.player[p.split('.')[0].split('-')[1]] = i));
    await Promise.all(jobs);
    A.ok = Object.keys(A.icons.Neon).length > 10;
  } catch (e) { console.warn('Assets fehlen – Platzhalter werden genutzt', e); }
  return A.ok;
}
export const iconSet = style => style === 'western' ? 'Western' : style === 'pixel' ? 'Pixel' : 'Neon'; // Toy Town: noch keine eigenen Assets
export const pixelIconUrl = f => `${BASE}Icons/Pixel/${f}@4x.png`;
export const pixelManeuverUrl = m => `${BASE}Maneuvers/Pixel/maneuver-${m}.png`;
export const badgeUrl = (name, tier) => `${BASE}Badges/badge-${name}-${tier}.svg`;
export const appIconUrl = `${BASE}AppIcon/appicon-1024.png`;
