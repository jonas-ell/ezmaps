// GM-015: Umrechnung Grad ↔ Meter um den Ursprung (wie prep.py) und Kachel-Mathematik (Web-Mercator, z/x/y).
// Später in der App: CLLocationCoordinate2D + MapLibre übernehmen das.
export const ORIGIN = { lat: 50.2215, lon: 8.268 };
const KX = Math.cos(ORIGIN.lat * Math.PI / 180) * 111320, KY = 110540;

export const toLocal = (lat, lon) => [(lon - ORIGIN.lon) * KX, -(lat - ORIGIN.lat) * KY];
export const toLatLon = p => [ORIGIN.lat - p[1] / KY, ORIGIN.lon + p[0] / KX];

export const lon2x = (lon, z) => (lon + 180) / 360 * 2 ** z;
export const lat2y = (lat, z) => { const r = lat * Math.PI / 180; return (1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2 * 2 ** z; };
export const x2lon = (x, z) => x / 2 ** z * 360 - 180;
export const y2lat = (y, z) => { const n = Math.PI - 2 * Math.PI * y / 2 ** z; return 180 / Math.PI * Math.atan(Math.sinh(n)); };

// Kachel (bzw. Teilkachel bei div > 1) als Rechteck in Metern
export function tileRegion(z, x, y, div = 1, sx = 0, sy = 0) {
  const fx = x + sx / div, fy = y + sy / div, s = 1 / div;
  const [la0, lo0] = [y2lat(fy, z), x2lon(fx, z)], [la1, lo1] = [y2lat(fy + s, z), x2lon(fx + s, z)];
  const a = toLocal(la0, lo0), b = toLocal(la1, lo1);
  return { x0: a[0], y0: a[1], w: b[0] - a[0], h: b[1] - a[1] };
}
// Meter pro Kachel in Ost-West-Richtung bei Breite lat
export const tileMeters = (z, lat) => 40075016 * Math.cos(lat * Math.PI / 180) / 2 ** z;
