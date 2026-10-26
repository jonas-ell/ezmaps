import Foundation

/// Anzeige- und Ansagetexte für Entfernungen und Zeiten.
/// Mirror in tools/prototype/js/route.js (fmtDist, fmtMin) – change both.
public enum Formatting {
    /// „850 m“, „1,2 km“, „12 km“ (Komma, wie im Prototyp)
    public static func distance(_ meters: Double) -> String {
        if meters >= 1000 {
            let km: Double = meters / 1000
            let text = meters >= 10_000 ? String(Int(km.rounded())) : String(format: "%.1f", km).replacingOccurrences(of: ".", with: ",")
            return text + " km"
        }
        if meters >= 100 { return String(Int((meters / 50).rounded()) * 50) + " m" }
        return String(max(0, Int((meters / 10).rounded()) * 10)) + " m"
    }

    /// „3 Min“, mindestens 1; ab 60 Minuten „1 Std 5 Min“
    public static func minutes(_ seconds: TimeInterval) -> String {
        let total = max(1, Int((seconds / 60).rounded()))
        if total < 60 { return "\(total) Min" }
        let h = total / 60
        let m = total % 60
        return m == 0 ? "\(h) Std" : "\(h) Std \(m) Min"
    }

    /// Für Sprachansagen: „300 Metern“, „1,5 Kilometern“
    public static func spokenDistance(_ meters: Double) -> String {
        distance(meters).replacingOccurrences(of: " km", with: " Kilometern").replacingOccurrences(of: " m", with: " Metern")
    }

    /// Ankunftszeit „17:49“ (24-Stunden, deutsche Schreibweise)
    public static func clock(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
