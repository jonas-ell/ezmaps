# CarPlay-Antrag (Navigation)

Formular: developer.apple.com/contact/carplay, angemeldet mit dem Entwicklerkonto. Kategorie **Navigation**.
Antwort von Apple dauert oft Wochen. Erst danach kommt die Berechtigung `com.apple.developer.carplay-maps` ins Geräte-Profil.

## 1. Stand gegenüber Apples Regeln für CarPlay-Navis

Quelle: „CarPlay Developer Guide“ von Apple (Abschnitt Navigation apps). Stand GM-045.

| Regel | Stand |
|---|---|
| Eigene Karte im Grundfenster (`CPWindow`), alles andere über Apples Vorlagen | ✅ `CarMapViewController` + `CPMapTemplate`, Listen, Suche |
| Routen-Vorschau mit Alternativen (`CPTrip`, `showTripPreviews`) | ✅ |
| Abbiegehinweise und Restzeit (`CPNavigationSession`, `CPManeuver`, `CPTravelEstimates`) | ✅ Entfernungen ab 1 km in km (GM-029) |
| Neuberechnung anzeigen (`pauseTrip(for: .rerouting)`) | ✅ GM-045 |
| Karte verschieben, auch ohne Touchscreen (Pfeiltasten, `showPanningInterface`) | ✅ GM-045 |
| Karte verschieben per Wischen (Touchscreen) | ✅ GM-045 |
| Zoom-Knöpfe | ✅ |
| Zurück zum Auto („Mitte“) | ✅ |
| Navigation abbrechen im Auto | ✅ `mapTemplateDidCancelNavigation` |
| Sprachansagen mit Ducking, Modus `voicePrompt` | ✅ `SpeechService` |
| Kein Text eintippen nötig während der Fahrt; Suche über `CPSearchTemplate` (iOS sperrt das Tippen beim Fahren selbst) | ✅ |
| Keine Kaufaufforderung im Auto | ✅ Shop nur auf dem iPhone; im Auto nur die kleine Test-Uhr |
| Freies Fahren ohne Route (Karte folgt dem Auto) | ✅ Hauptmodus GM-025 |
| Läuft, wenn das iPhone gesperrt ist / App im Hintergrund (Standort „Hintergrund“) | ⚠️ im Gerät prüfen |
| CarPlay Dashboard (`CPTemplateApplicationDashboardScene`) | ❌ freiwillig, später |
| Kombiinstrument (Instrument Cluster) | ❌ freiwillig, später |
| Tag/Nacht: helle Karte nachts nicht blendend | ⚠️ „Klassik“ ist hell; nachts Stil „Neon City“ empfehlen oder automatisch umschalten (offen) |
| Keine Blitzer-Warnungen (deutsches Recht) | ✅ |

## 2. Text für das Formular (Englisch)

**App name:** EzMaps: Game Maps

**Category:** Navigation (turn-by-turn)

**Short description:**
EzMaps is a turn-by-turn navigation app for drivers in Germany with original, game-inspired map styles
(for example a neon night city, a western look and a toy-town look). It uses OpenStreetMap data,
Valhalla routing and shows speed limits. Drivers can also use it without a route: the map follows
the car, so it works as a stylish moving map for everyday driving.

**CarPlay functionality:**
- Full-screen map drawn in the CarPlay base view, following the car with heading-up camera
- Destination list (recent places) and search with `CPSearchTemplate`
- Route preview with alternatives, start guidance from the car
- Turn-by-turn maneuvers, distance and time estimates, rerouting state
- Spoken guidance (ducks other audio)
- Map panning with directional buttons and touch, zoom buttons, recenter
- No purchases, no text-heavy content, no video in the car

**Status:** Working build in the CarPlay simulator (Xcode, iOS 17+), iPhone app in final testing,
App Store release planned after the entitlement.

## 3. Was vor dem Absenden fehlt

1. [N] Entwicklerkonto aktiv, Firmen-/Personenangaben wie im Konto.
2. [N] Bundle-ID festlegen (`docs/VEROEFFENTLICHUNG.md` 1.3), sie steht im Antrag.
3. [M] Ein Gerätetest des iPhone-Ablaufs im Auto (Halterung) und ein Durchlauf aller CarPlay-Bilder ohne Fehler (`bash tools/mac_check.sh`).
