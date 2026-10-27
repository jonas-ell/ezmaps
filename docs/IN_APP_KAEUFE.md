# In-App-Käufe und Abos – alles zum Anlegen in App Store Connect

Stand GM-050. Produkt-IDs stehen fest in `Core/Sources/EzMapsCore/Purchases.swift` und dürfen nicht abweichen.
Preise wie `App/EzMaps.storekit` und `Core/Sources/EzMapsCore/TestStore.swift` (ein Test prüft, dass beide gleich sind).

Bis die Produkte angelegt und freigegeben sind, läuft die App auf dem Test-iPhone im **Test-Kauf-Modus**
(`bash tools/mac_device.sh`): Preise werden angezeigt, „Kaufen“ schaltet ohne Geld frei, nur auf diesem Gerät.
Zurücksetzen: Einstellungen → „Testkäufe zurücksetzen“. Im App-Store-Build gibt es diesen Modus nicht.

## 1. Abo-Gruppe

- **Name der Gruppe (intern):** EzMaps Plus
- **Anzeigename der Gruppe:** DE „EzMaps Plus“ · EN „EzMaps Plus“
- Rangfolge (Upgrade-Reihenfolge): 1 Jährlich, 2 Monatlich
- Kein Gratis-Zeitraum, kein Einführungsangebot (GM-042)

## 2. Produkte

Apple-Grenzen: Anzeigename höchstens 30 Zeichen, Beschreibung höchstens 45 Zeichen.

| Produkt-ID | Art | Referenzname (intern) | Preis (EUR) | Anzeigename DE | Beschreibung DE | Anzeigename EN | Beschreibung EN |
|---|---|---|---|---|---|---|---|
| `ezmaps.plus.monthly` | Auto-Abo, 1 Monat | Plus Monat | 4,99 | EzMaps Plus Monat | Alle Kartenstile, auch in CarPlay | EzMaps Plus Monthly | All map styles, also in CarPlay |
| `ezmaps.plus.yearly` | Auto-Abo, 1 Jahr | Plus Jahr | 29,99 | EzMaps Plus Jahr | Alle Kartenstile, auch in CarPlay | EzMaps Plus Yearly | All map styles, also in CarPlay |
| `ezmaps.plus.lifetime` | Nicht verbrauchbar | Plus für immer | 79,99 | EzMaps Plus für immer | Alle Stile und jeder neue, einmal zahlen | EzMaps Plus Lifetime | All styles and every new one, pay once |
| `ezmaps.style.neon` | Nicht verbrauchbar | Stil Neon City | 39,99 | Neon City | Dunkle Open-World-Karte für immer | Neon City | Dark open-world map, yours forever |
| `ezmaps.style.western` | Nicht verbrauchbar | Stil Wild West | 29,99 | Wild West | Papierkarte im Western-Look für immer | Wild West | Western paper map, yours forever |
| `ezmaps.style.pixel` | Nicht verbrauchbar | Stil Pixel Quest | 29,99 | Pixel Quest | Pixel-Blockwelt als Karte für immer | Pixel Quest | Pixel block-world map, yours forever |
| `ezmaps.style.toy` | Nicht verbrauchbar | Stil Toy Town | 29,99 | Toy Town | Bunter Spielteppich als Karte für immer | Toy Town | Colorful play-mat map, yours forever |

Keine Spielnamen in Texten (Markenrecht, App-Review 4.1).

## 3. Bilder

- **Werbebild je Produkt** (optional, nur nötig für „beworbene“ Käufe): `docs/store/iap/<Produkt-ID>.png`, 1024 × 1024, ohne runde Ecken, ohne Preis.
  Neu erzeugen: `python tools/maplibre/render_previews.py` (Server muss laufen), dann `python tools/store_iap_images.py`.
- **Prüf-Screenshot** (Pflicht je Produkt, für Apples Prüfer): `docs/store/iphone-69/stil.png` (Stil-Seite mit Plus und Einzelkauf).
  Entsteht bei `bash tools/mac_check.sh` (Screenshot-Zustand `stil`). Für alle Produkte dasselbe Bild verwenden.

## 4. Hinweis für die Prüfung (Feld „Review Notes“)

DE: „Kartenstile werden auf der Startkarte über das Paletten-Symbol (oben rechts) gekauft. Jeder Stil lässt sich vorher
10 Minuten kostenlos testen. EzMaps Plus schaltet alle Stile frei, Einzelkäufe nur den jeweiligen Stil. Klassik und die
Navigation sind gratis. ‚Käufe wiederherstellen‘ steht im Shop und in den Einstellungen.“

EN: “Map styles are purchased from the home map via the palette button (top right). Each style can be tried for free for
10 minutes first. EzMaps Plus unlocks all styles, single purchases unlock one style. Classic and navigation are free.
‘Restore Purchases’ is in the shop and in Settings.”

## 5. Reihenfolge

1. [N] Bundle-ID festlegen (`docs/VEROEFFENTLICHUNG.md` 1.3) und App in App Store Connect anlegen.
2. [N] Vertrag „Paid Apps“ und Bankdaten/Steuer in App Store Connect abschließen (sonst lädt StoreKit keine Produkte).
3. [N] Abo-Gruppe und die 7 Produkte mit den Texten oben anlegen, Prüf-Screenshot hochladen.
4. [C] TestFlight-Build hochladen (nur auf Ansage); dort mit Sandbox-Konto echte Testkäufe prüfen.
5. Die Produkte werden mit der ersten App-Version zur Prüfung eingereicht.
