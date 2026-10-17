// GM-015: Kleiner Leser für Mapbox-Vektorkacheln (Protobuf) – ohne fremde Bibliothek.
// Liefert pro Ebene Objekte { type: 1 Punkt | 2 Linie | 3 Fläche, tags, rings: [[[x, y], …], …] } in Kachel-Einheiten (extent).

class Pbf {
  constructor(buf) { this.b = buf; this.p = 0; }
  varint() {
    let v = 0, s = 0, b;
    do { b = this.b[this.p++]; v += (b & 0x7f) * 2 ** s; s += 7; } while (b & 0x80);
    return v;
  }
  skip(w) {
    if (w === 0) this.varint(); else if (w === 1) this.p += 8; else if (w === 2) { const n = this.varint(); this.p += n; } else if (w === 5) this.p += 4;
    else throw new Error('pbf: wire ' + w);
  }
  bytes() { const n = this.varint(), s = this.p; this.p += n; return this.b.subarray(s, s + n); }
  fields(fn, end = this.b.length) { while (this.p < end) { const t = this.varint(); fn(t >> 3, t & 7); } }
}
const dec = new TextDecoder();
const zz = n => (n >>> 1) ^ -(n & 1);

function readValue(buf) {
  const r = new Pbf(buf); let v = null;
  r.fields((f, w) => {
    if (f === 1) v = dec.decode(r.bytes());
    else if (f === 2) { v = new DataView(buf.buffer, buf.byteOffset + r.p, 4).getFloat32(0, true); r.p += 4; }
    else if (f === 3) { v = new DataView(buf.buffer, buf.byteOffset + r.p, 8).getFloat64(0, true); r.p += 8; }
    else if (f === 4 || f === 5) v = r.varint();
    else if (f === 6) { const n = r.varint(); v = (n % 2 ? -(n + 1) : n) / 2; }
    else if (f === 7) v = !!r.varint();
    else r.skip(w);
  });
  return v;
}
function packed(r) { const b = r.bytes(), q = new Pbf(b), out = []; while (q.p < b.length) out.push(q.varint()); return out; }

function geometry(cmds) {
  const rings = []; let ring = null, x = 0, y = 0;
  for (let i = 0; i < cmds.length;) {
    const c = cmds[i++], id = c & 7, n = c >> 3;
    if (id === 7) { if (ring && ring.length) ring.push(ring[0]); continue; }
    for (let k = 0; k < n; k++) {
      x += zz(cmds[i++]); y += zz(cmds[i++]);
      if (id === 1) { ring = [[x, y]]; rings.push(ring); } else ring.push([x, y]);
    }
  }
  return rings;
}

export function decodeTile(arrayBuffer, wanted) {
  const r = new Pbf(new Uint8Array(arrayBuffer)), layers = {};
  r.fields((f, w) => {
    if (f !== 3) return r.skip(w);
    const lb = r.bytes(), l = new Pbf(lb), raw = []; let name = '', keys = [], vals = [], extent = 4096;
    l.fields((g, w2) => {
      if (g === 1) name = dec.decode(l.bytes());
      else if (g === 2) raw.push(l.bytes());
      else if (g === 3) keys.push(dec.decode(l.bytes()));
      else if (g === 4) vals.push(readValue(l.bytes()));
      else if (g === 5) extent = l.varint();
      else l.skip(w2);
    });
    if (wanted && !wanted.has(name)) return;
    layers[name] = { extent, features: raw.map(fb => {
      const q = new Pbf(fb), ft = { type: 0, tags: {}, rings: [] }; let geo = [];
      q.fields((h, w3) => {
        if (h === 2) { const t = packed(q); for (let i = 0; i < t.length; i += 2) ft.tags[keys[t[i]]] = vals[t[i + 1]]; }
        else if (h === 3) ft.type = q.varint();
        else if (h === 4) geo = packed(q);
        else q.skip(w3);
      });
      ft.rings = geometry(geo);
      return ft;
    }) };
  });
  return layers;
}
