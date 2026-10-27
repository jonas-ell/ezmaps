// GM-038: Kartenhinweis „© OpenStreetMap-Mitwirkende“ immer direkt über dem unteren Blatt / der unteren Leiste,
// statt mit festen Abständen (die bei jeder Blatthöhe anders überlappten).
export function placeAttribution(root = document) {
  for (const ph of root.querySelectorAll('.dph.B')) {
    const pr = ph.getBoundingClientRect();
    let top = Infinity;
    for (const el of ph.querySelectorAll('.sheet, .g, .card')) {
      const r = el.getBoundingClientRect();
      if (r.bottom > pr.bottom - 60 && r.width > pr.width * 0.6) top = Math.min(top, r.top);
    }
    if (top === Infinity) continue;
    for (const o of ph.querySelectorAll('.osm')) { o.style.top = 'auto'; o.style.bottom = `${Math.round(pr.bottom - top + 6)}px`; }
  }
}
