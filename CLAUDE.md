# EzMaps – Hinweise für KI-Mitarbeiter (Claude, Codex)

- Antworten an den Nutzer auf **Deutsch**, einfach. Jede Antwort endet mit einem Prompt für den Mac-Build und einer Liste „Auf dem Gerät testen“.
- Nichts als getestet ausgeben, was nicht auf dem Mac gebaut wurde.
- **Vor Swift-Änderungen [docs/LESSONS_SWIFT.md](docs/LESSONS_SWIFT.md) lesen** (echte Fehler aus dem Vorgängerprojekt).
- Jede Änderung: Eintrag in `CHANGELOG.md` (Reihe `GM-xxx`, neueste oben, Abschnitte Ziel / Dateien / Geändert / Tatsächlich geprüft / Ungetestet), dann committen und pushen.
- Geheimnisse (`*.p8`, Service-Accounts, API-Keys) nie committen. `tools/prototype/fonts/` (Pricedown, nur Desktop-Lizenz) nie committen.
- Recht: keine Spielnamen/-inhalte, Hinweis „© OpenStreetMap-Mitwirkende“ immer sichtbar, keine Blitzer-Warnungen (§ 23 Abs. 1c StVO).
- Design zuerst im **Prototyp** (`tools/prototype/`, Start: `python tools/prototype/serve.py`) zeigen, dann in Swift bauen. Routen-/Nebel-Logik in `tools/prototype/js/` und `Core/` gemeinsam ändern.
- Mac-Build: `ssh jonaselfounti@100.102.233.78 build-ezmaps` (nur freigegebene Befehle).
