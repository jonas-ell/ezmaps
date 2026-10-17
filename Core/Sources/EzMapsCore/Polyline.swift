import Foundation

/// Kodierte Polylinie (Google-Format). Valhalla liefert Genauigkeit 6.
/// Mirror in tools/prototype/js/valhalla.js (decode6) – change both.
public enum Polyline {
    public static func decode(_ string: String, precision: Int = 6) -> [Coordinate] {
        let factor: Double = pow(10, Double(precision))
        let bytes = Array(string.utf8)
        var index = 0
        var lat = 0
        var lon = 0
        var result: [Coordinate] = []
        while index < bytes.count {
            guard let dLat = nextValue(bytes, &index), let dLon = nextValue(bytes, &index) else { break }
            lat += dLat
            lon += dLon
            result.append(Coordinate(latitude: Double(lat) / factor, longitude: Double(lon) / factor))
        }
        return result
    }

    public static func encode(_ coordinates: [Coordinate], precision: Int = 6) -> String {
        let factor: Double = pow(10, Double(precision))
        var lastLat = 0
        var lastLon = 0
        var out = ""
        for c in coordinates {
            let lat = Int((c.latitude * factor).rounded())
            let lon = Int((c.longitude * factor).rounded())
            out += encodeValue(lat - lastLat)
            out += encodeValue(lon - lastLon)
            lastLat = lat
            lastLon = lon
        }
        return out
    }

    private static func nextValue(_ bytes: [UInt8], _ index: inout Int) -> Int? {
        var shift = 0
        var value = 0
        while true {
            guard index < bytes.count else { return nil }
            let b = Int(bytes[index]) - 63
            index += 1
            value |= (b & 0x1f) << shift
            shift += 5
            if b < 0x20 { break }
        }
        return (value & 1) != 0 ? ~(value >> 1) : (value >> 1)
    }

    private static func encodeValue(_ v: Int) -> String {
        var value = v < 0 ? ~(v << 1) : (v << 1)
        var out = ""
        while value >= 0x20 {
            out.append(Character(UnicodeScalar(UInt8((0x20 | (value & 0x1f)) + 63))))
            value >>= 5
        }
        out.append(Character(UnicodeScalar(UInt8(value + 63))))
        return out
    }
}
