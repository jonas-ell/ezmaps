import Foundation

/// Lokalisierung: deutscher Text ist der Schlüssel, Englisch steht in en.lproj/Localizable.strings.
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}
