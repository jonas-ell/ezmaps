"""Aufgaben-Liste .autopilot/backlog.json (nicht committet) und GM-Nummer (docs/AUTOPILOT_PLAN.md 2, 5, 8)."""
import dataclasses
import datetime as dt
import json
import pathlib
import re
import subprocess

import basis

STUFEN = "ABCDE"
STATUS = {"offen", "in_arbeit", "erledigt", "blockiert", "abgelehnt", "verworfen"}


@dataclasses.dataclass
class Aufgabe:
    id: str
    titel: str
    stufe: str                      # A … E (Plan 5)
    art: str = ""                   # z. B. carplay, kauf, recht, technik
    beweis: list = dataclasses.field(default_factory=list)   # Datei:Zeile, Logzeile oder Bild
    dateien: list = dataclasses.field(default_factory=list)
    status: str = "offen"
    versuche: int = 0
    erstellt: str = ""
    quelle: str = ""                # prüfliste, build, test, absturz, bild, wunsch
    gruende: list = dataclasses.field(default_factory=list)  # Jury-Gründe bei Ablehnung


class Backlog:
    def __init__(self, datei=None):
        self.datei = pathlib.Path(datei or basis.DATEN / "backlog.json")
        roh = json.loads(self.datei.read_text(encoding="utf-8")) if self.datei.exists() else []
        self.aufgaben = [Aufgabe(**a) for a in roh]

    def speichern(self):
        self.datei.parent.mkdir(parents=True, exist_ok=True)
        self.datei.write_text(json.dumps([dataclasses.asdict(a) for a in self.aufgaben], indent=1, ensure_ascii=False),
                              encoding="utf-8")

    def hinzufuegen(self, titel, stufe, beweis, **mehr):
        """Neue Aufgabe. Ohne Beweis oder mit unbekannter Stufe → verworfen (None). Gleicher Titel → nicht doppelt."""
        beweis = [b for b in (beweis or []) if isinstance(b, str) and b.strip()]
        if not beweis or stufe not in STUFEN:
            return None
        if any(a.titel == titel and a.status not in ("erledigt", "verworfen") for a in self.aufgaben):
            return None
        nr = max([int(a.id[1:]) for a in self.aufgaben if re.fullmatch(r"T\d+", a.id)] or [0]) + 1
        a = Aufgabe(id=f"T{nr:03d}", titel=titel, stufe=stufe, beweis=beweis,
                    erstellt=mehr.pop("erstellt", dt.datetime.now().isoformat(timespec="seconds")), **mehr)
        self.aufgaben.append(a)
        return a

    def offen(self):
        return [a for a in self.aufgaben if a.status == "offen"]

    def naechste(self):
        """Plan 3 Schritt 2 und 5: höchste Stufe zuerst, bei gleicher Stufe die älteste.
        D erst, wenn A bis C leer sind; E nie (nur Vorschlag-Branch durch den Nutzer)."""
        kandidaten = [a for a in self.offen() if a.stufe in "ABCD"]
        if any(a.stufe in "ABC" for a in kandidaten):
            kandidaten = [a for a in kandidaten if a.stufe in "ABC"]
        if not kandidaten:
            return None
        return sorted(kandidaten, key=lambda a: (STUFEN.index(a.stufe), a.erstellt, a.id))[0]


def hoechste_gm(changelog_text):
    nummern = [int(n) for n in re.findall(r"^## GM-(\d+)", changelog_text, re.M)]
    return max(nummern or [0])


def naechste_gm(changelog_text):
    """Plan 8: GM-Nummer erst beim Mergen – höchste auf origin/main + 1."""
    return f"GM-{hoechste_gm(changelog_text) + 1:03d}"


def gm_aus_origin_main(repo=basis.REPO):
    subprocess.run(["git", "fetch", "-q", "origin", "main"], cwd=repo, check=True)
    text = subprocess.run(["git", "show", "origin/main:CHANGELOG.md"], cwd=repo, check=True,
                          capture_output=True, text=True, encoding="utf-8").stdout
    return naechste_gm(text)
