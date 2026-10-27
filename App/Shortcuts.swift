import AppIntents
import EzMapsCore

/// GM-043: Siri und Kurzbefehle (GM-029 „Widgets und Kurzbefehle“): „Mit EzMaps nach Hause“, „… zur Arbeit“,
/// „Wo hab ich geparkt?“. Öffnet die App und plant die Route (Losfahren tippt der Nutzer selbst – Sicherheit).
/// Widgets brauchen ein eigenes Erweiterungs-Ziel in project.yml – folgt (siehe CHANGELOG GM-043).
struct DriveHomeIntent: AppIntent {
    static var title: LocalizedStringResource = "Nach Hause fahren"
    static var description = IntentDescription("Plant die Route nach Hause in EzMaps.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        await ShortcutRunner.drive(to: AppModel.shared.journal.home)
        return .result()
    }
}

struct DriveWorkIntent: AppIntent {
    static var title: LocalizedStringResource = "Zur Arbeit fahren"
    static var description = IntentDescription("Plant die Route zur Arbeit in EzMaps.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        await ShortcutRunner.drive(to: AppModel.shared.journal.work)
        return .result()
    }
}

struct ParkedCarIntent: AppIntent {
    static var title: LocalizedStringResource = "Wo hab ich geparkt?"
    static var description = IntentDescription("Zeigt, wo dein Auto steht.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.showParkedCar = AppModel.shared.journal.parked != nil
        if AppModel.shared.journal.parked == nil { AppModel.shared.show(L("Kein Parkplatz gemerkt")) }
        return .result()
    }
}

@MainActor
enum ShortcutRunner {
    /// Auf den Standort warten (App kann gerade erst gestartet sein), dann Route planen
    static func drive(to place: PhotonClient.Place?) async {
        let model = AppModel.shared
        guard let place else {
            model.show(L("Bitte zuerst in den Einstellungen festlegen"))
            return
        }
        var waited = 0
        while model.currentCoordinate == nil && waited < 40 {
            try? await Task.sleep(nanoseconds: 250_000_000)
            waited += 1
        }
        if model.screen == .navigating { return }
        model.choose(place)
    }
}

struct EzMapsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: DriveHomeIntent(), phrases: ["Mit \(.applicationName) nach Hause", "\(.applicationName) nach Hause"],
                    shortTitle: "Nach Hause", systemImageName: "house")
        AppShortcut(intent: DriveWorkIntent(), phrases: ["Mit \(.applicationName) zur Arbeit", "\(.applicationName) zur Arbeit"],
                    shortTitle: "Zur Arbeit", systemImageName: "briefcase")
        AppShortcut(intent: ParkedCarIntent(), phrases: ["Wo hab ich geparkt in \(.applicationName)", "\(.applicationName) wo ist mein Auto"],
                    shortTitle: "Dein Auto", systemImageName: "car")
    }
}
