import Foundation
import Security
import EzMapsCore

/// GM-041: Speicher für „Stadt aufdecken“ und die Stil-Testzeit.
/// - Aufdecken: JSON-Datei in Application Support (nur auf dem Gerät, aus dem Backup nicht ausgeschlossen).
/// - Testzeit: Schlüsselbund (bleibt nach Löschen der App erhalten) **und** iCloud-Schlüsselwerte (gleiche Apple-ID
///   auf anderem Gerät). Beim Laden gilt je Stil der größere Verbrauch (`StyleTrial.merge`), damit Löschen und
///   Neuinstallieren keinen neuen Test bringt. Ohne iCloud-Berechtigung bleibt nur der Schlüsselbund – kein Absturz.
enum GameStorage {
    // MARK: Aufdecken

    private static var explorationURL: URL {
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("exploration.json")
    }

    static func loadExploration() -> ExplorationStore {
        guard let data = try? Data(contentsOf: explorationURL),
              let store = try? JSONDecoder().decode(ExplorationStore.self, from: data) else { return ExplorationStore() }
        return store
    }

    static func saveExploration(_ store: ExplorationStore) {
        guard let data = try? JSONEncoder().encode(store) else { return }
        try? data.write(to: explorationURL, options: .atomic)
    }

    // MARK: Stil-Testzeit

    private static let service = "app.ezmaps.trial"
    private static let account = "used"
    private static let cloudKey = "ezmaps.trial.used"

    /// Stand aus Schlüsselbund und iCloud, zusammengeführt
    static func loadTrial() -> StyleTrial {
        var trial = StyleTrial()
        trial.merge(readKeychain())
        NSUbiquitousKeyValueStore.default.synchronize()
        if let cloud = NSUbiquitousKeyValueStore.default.dictionary(forKey: cloudKey) as? [String: Double] {
            trial.merge(cloud)
        }
        return trial
    }

    /// Nach jeder Änderung des Verbrauchs aufrufen (z. B. alle 10 s und beim Wechsel in den Hintergrund)
    static func saveTrial(_ trial: StyleTrial) {
        writeKeychain(trial.used)
        NSUbiquitousKeyValueStore.default.set(trial.used, forKey: cloudKey)
    }

    private static func baseQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    private static func readKeychain() -> [String: Double] {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let used = try? JSONDecoder().decode([String: Double].self, from: data) else { return [:] }
        return used
    }

    private static func writeKeychain(_ used: [String: Double]) {
        guard let data = try? JSONEncoder().encode(used) else { return }
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status: OSStatus = SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery()
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}
