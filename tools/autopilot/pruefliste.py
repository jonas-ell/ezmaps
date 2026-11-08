"""Punkte der Prüfliste App Store + CarPlay (docs/AUTOPILOT_PLAN.md 6). Nur der Nutzer ändert diese Liste (Plan 1.4)."""

PUNKTE = [
    # 6.1 Verdachtsfälle aus der Cloud-Prüfung – zuerst
    ("6.1.1", "Pricedown im App-Store-Archiv",
     "tools/mac_archive.sh baut über tools/mac_build.sh; das kopiert ~/EzMapsPrivate/Fonts/pricedown.otf nach App/Fonts/. "
     "project.yml führt Pricedown.otf in UIAppFonts. Lizenz nur Desktop. Erwartung: Archiv nimmt nie Pricedown mit, "
     "UIAppFonts nennt nur Schriften im Bundle."),
    ("6.1.2", "CarPlay-Grundfenster mit Zusatzanzeigen",
     "App/CarPlaySceneDelegate.swift legt eigene Views auf die Karte (trialLabel, limitLabel, Hinweis-Text). "
     "Grundfenster darf nur die Karte zeigen; Lösung über Vorlagen (CPNavigationSession, CPMapTemplate-Leisten, "
     "CPInformationTemplate) oder weglassen. OSM-Hinweis darf als Teil der Karte bleiben."),
    ("6.1.3", "Öffentliche Server (Valhalla FOSSGIS, Photon komoot, OpenFreeMap)",
     "Nutzungsregeln für eine verkaufte App? docs/VEROEFFENTLICHUNG.md. Ausfall/Sperre bei der Prüfung → Ablehnung 2.1."),
    ("6.1.4", "App-Prüfer sitzt in den USA",
     "Suche, Routing und Karte müssen dort funktionieren, oder die Prüfer-Hinweise erklären es genau (Demo-Route ohne Fahrt)."),
    ("6.1.5", "Spiel-Ähnlichkeit (4.1/5.2)",
     "Pixel Quest (Blockwelt, Villager-Häuser) und Neon City (Pricedown-artig) sind Risiken. Bilder und Store-Texte "
     "bewerten. Kein Spielname in Texten, Schlüsselwörtern oder Bildern."),
    # 6.2 App Review
    ("6.2.1", "2.1 kein Absturz", "beim Start, Stilwechsel, Suche, Routenstart, Ankunft, CarPlay verbinden/trennen"),
    ("6.2.2", "2.1 keine Platzhalter", "kein „bald“, „Test“, leere Listen ohne Erklärung"),
    ("6.2.3", "2.1 Links", "alle Links in der App funktionieren (Bedingungen, Datenschutz, Hilfe)"),
    ("6.2.4", "2.1 Test-Käufe nie im Release", "EZTEST/DEBUG-Code nur in Test-Builds"),
    ("6.2.5", "2.3 Store-Bilder und Texte", "Store-Bilder zeigen die echte App, Texte versprechen nichts, was fehlt"),
    ("6.2.6", "2.5.4 Hintergrund-Modi", "location nur für Navigation, audio nur für Ansagen, im Prüfer-Hinweis begründet, "
     "kein Hintergrund-Audio ohne Ansage"),
    ("6.2.7", "3.1.1 Käufe", "nur über StoreKit, Knopf „Wiederherstellen“ sichtbar"),
    ("6.2.8", "3.1.2 Paywall-Angaben", "Abo-Laufzeit, Preis, Leistung, Links zu Nutzungsbedingungen (EULA) und Datenschutz"),
    ("6.2.9", "3.1 kein Kauf in CarPlay", "kein Kauf und keine Kaufaufforderung in CarPlay"),
    ("6.2.10", "4.2 eigener Nutzen", "App bietet mehr als eine Webseite"),
    ("6.2.11", "5.1.1 Standort", "Zwecktexte verständlich und richtig; Standort erst fragen, wenn er gebraucht wird"),
    ("6.2.12", "5.1.1 PrivacyInfo", "PrivacyInfo.xcprivacy deckt alle Required-Reason-APIs ab (UserDefaults, Systemlaufzeit, "
     "Dateidatum, Speicherplatz), mit grep gegengeprüft"),
    ("6.2.13", "5.1.2 Datenschutz-Angaben", "Angaben für App Store Connect nennen Standort und Suchtexte an Routing-, Such- und "
     "Karten-Server"),
    ("6.2.14", "5.2 Lizenzen und OSM-Hinweis", "Lizenzen aller Schriften, Grafiken (Codex, Nutzer) und Daten in docs/legal/; "
     "„© OpenStreetMap-Mitwirkende“ immer sichtbar"),
    ("6.2.15", "Fahrsicherheit", "keine Blitzer; keine Eingaben während der Fahrt außer Sprache/Vorlage; Warnhinweis beim ersten Start"),
    # 6.3 CarPlay
    ("6.3.1", "Berechtigung carplay-maps", "Stand der Signierung; App-Store-Build ohne erteilte Berechtigung stürzt nicht ab"),
    ("6.3.2", "Grundfenster nur Karte", "alles andere über Vorlagen (siehe 6.1.2)"),
    ("6.3.3", "Vorlagen-Grenzen", "Stapel höchstens 5; Knöpfe in CPMapTemplate in den Grenzen; Listen über maximumItemCount"),
    ("6.3.4", "Start aus CarPlay", "auch wenn die App nie geöffnet oder das iPhone gesperrt ist; ohne Standort-Erlaubnis klarer "
     "Hinweis in CarPlay, kein Hängen"),
    ("6.3.5", "Verbinden/Trennen", "während einer Navigation: kein Absturz, keine doppelten Ansagen"),
    ("6.3.6", "Tag und Nacht", "Karte folgt dem Erscheinungsbild von CarPlay, blendet nachts nicht"),
    ("6.3.7", "Bildschirmgrößen", "800×480 bis 1920×720, Rechtslenker, safeArea der Vorlage"),
    ("6.3.8", "Ansagen", "AVAudioSession .voicePrompt, Musik nur leiser, Sitzung danach freigegeben"),
    ("6.3.9", "Abbiegehinweise", "CPManeuver mit Symbol und Textvarianten, Restzeit/Entfernung laufend, Neuberechnung angezeigt"),
    ("6.3.10", "Suche in CarPlay", "CPSearchTemplate und Sprache, kein freies Tippen während der Fahrt"),
    ("6.3.11", "Keine verbotenen Inhalte", "kein Kauf, kein Shop, keine Werbung, kein Video, keine langen Texte in CarPlay"),
]

# Gruppen für den Finder (je ein claude -p-Aufruf, parallel)
GRUPPEN = [["6.1.1"], ["6.1.2", "6.3.2"], ["6.1.3"], ["6.1.4"], ["6.1.5"],
           ["6.2.1", "6.2.2", "6.2.3", "6.2.4", "6.2.5", "6.2.6", "6.2.7", "6.2.8"],
           ["6.2.9", "6.2.10", "6.2.11", "6.2.12", "6.2.13", "6.2.14", "6.2.15"],
           ["6.3.1", "6.3.3", "6.3.4", "6.3.5"], ["6.3.6", "6.3.7", "6.3.8", "6.3.9", "6.3.10", "6.3.11"]]

ABSCHNITTE = {"6.1": "6.1 Verdachtsfälle (zuerst geprüft)", "6.2": "6.2 App Review", "6.3": "6.3 CarPlay (Navigation)"}
