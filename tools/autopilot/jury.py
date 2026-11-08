"""Harte Jury (docs/AUTOPILOT_PLAN.md 4): fünf getrennte Juroren, Zählung nach festen Regeln.

Regeln (alle mit Tests in tests/test_jury.py):
- Im Zweifel NEIN. Ungültiges JSON, Zeitüberschreitung oder ein Grund ohne Beweis zählt als NEIN.
- Ein Veto mit Schwere „blocker“ lehnt ab, egal wie die anderen stimmen.
- Mehrheit 4 von 5; 5 von 5 bei CarPlay, Käufen, Standort/Datenschutz, Recht, Hintergrund-Modi (Pfade und Aufgaben-Art).
- Juroren sehen nur Aufgabe, Plan, Diff, Prüfausgaben und Bilder – nie, was der Bauer über seine Arbeit sagt.
- Stufe A: zwei Durchläufe mit neuer Reihenfolge der Unterlagen, beide müssen die Mehrheit haben.
Nur der Nutzer ändert diese Datei (Plan 1.4).
"""
import dataclasses
import fnmatch
import pathlib
import random
import re

import basis
import claude_call

STIMMEN = {"JA", "NEIN"}
SCHWEREN = {"blocker", "hoch", "mittel", "niedrig"}
# Beweis = Datei:Zeile, Bildname oder Log-Datei (mit optionaler Zeile)
BEWEIS = re.compile(r"([\w./\\-]+\.[A-Za-z0-9]{1,10}:\d+)|([\w./\\-]+\.(png|jpe?g|webp))|([\w./\\-]+\.(log|txt)(:\d+)?)", re.I)
EINLEITUNG = "Du bist absichtlich streng. Ohne Beweis stimmst du NEIN."


@dataclasses.dataclass
class Stimme:
    rolle: str
    ja: bool
    veto: bool = False
    schwere: str = "niedrig"
    gruende: list = dataclasses.field(default_factory=list)
    bedingungen: list = dataclasses.field(default_factory=list)
    gueltig: bool = True
    hinweis: str = ""          # warum als NEIN gewertet


@dataclasses.dataclass
class Urteil:
    angenommen: bool
    ja: int
    noetig: int
    stimmen: list
    veto_von: list
    zusammenfassung: str


def hat_beweis(grund):
    return isinstance(grund, str) and BEWEIS.search(grund) is not None


def schema_fehler(daten):
    """Fehlertext, wenn die Antwort nicht dem Juror-Schema entspricht (für die Wiederholung in claude_call)."""
    if not isinstance(daten, dict):
        return "Antwort ist kein JSON-Objekt"
    if daten.get("stimme") not in STIMMEN:
        return "„stimme“ muss JA oder NEIN sein"
    if not isinstance(daten.get("veto"), bool):
        return "„veto“ muss true oder false sein"
    if daten.get("schwere") not in SCHWEREN:
        return "„schwere“ muss blocker, hoch, mittel oder niedrig sein"
    if not isinstance(daten.get("gruende"), list) or not daten["gruende"]:
        return "„gruende“ muss eine nicht leere Liste sein"
    if not isinstance(daten.get("bedingungen", []), list):
        return "„bedingungen“ muss eine Liste sein"
    return None


def werte(rolle, ergebnis):
    """Antwort eines Jurors → Stimme. Alles Zweifelhafte wird NEIN."""
    if ergebnis is None or not getattr(ergebnis, "ok", False):
        fehler = getattr(ergebnis, "fehler", "keine Antwort")
        return Stimme(rolle, ja=False, gueltig=False, hinweis=f"ungültig: {fehler}")
    d = ergebnis.daten
    f = schema_fehler(d)
    if f:
        return Stimme(rolle, ja=False, gueltig=False, hinweis=f"ungültig: {f}")
    s = Stimme(rolle, ja=d["stimme"] == "JA", veto=d["veto"], schwere=d["schwere"],
               gruende=list(d["gruende"]), bedingungen=list(d.get("bedingungen") or []))
    ohne = [g for g in s.gruende if not hat_beweis(g)]
    if ohne:
        s.ja = False
        s.hinweis = f"Grund ohne Beweis: {ohne[0][:120]}"
    return s


def streng(dateien, art, cfg):
    """True, wenn 5 von 5 nötig sind (Plan 4: Pfade und Aufgaben-Art)."""
    j = cfg["jury"]
    if (art or "").lower() in {a.lower() for a in j["streng_arten"]}:
        return True
    for d in dateien or []:
        d = str(d).replace("\\", "/")
        name = d.rsplit("/", 1)[-1]
        if any(fnmatch.fnmatch(name, m) for m in j["streng_dateinamen"]):
            return True
        if any(fnmatch.fnmatch(d, m) for m in j["streng_pfade"]):
            return True
    return False


def zaehle(stimmen, noetig):
    veto = [s.rolle for s in stimmen if s.veto and s.schwere == "blocker"]
    ja = sum(1 for s in stimmen if s.ja)
    ok = not veto and ja >= noetig
    if veto:
        text = f"abgelehnt: Veto (blocker) von {', '.join(veto)}"
    else:
        text = f"{'angenommen' if ok else 'abgelehnt'}: {ja} von {len(stimmen)} JA, nötig {noetig}"
    return Urteil(ok, ja, noetig, stimmen, veto, text)


def unterlagen_text(unterlagen, reihenfolge):
    teile = []
    for k in reihenfolge:
        v = unterlagen.get(k)
        if v:
            teile.append(f"## {k}\n\n{v}")
    return "\n\n".join(teile)


def juror_prompt(rolle, unterlagen, reihenfolge, prompts_ordner=basis.HIER / "prompts"):
    rollentext = (pathlib.Path(prompts_ordner) / f"juror-{rolle}.md").read_text(encoding="utf-8")
    if not rollentext.startswith(EINLEITUNG):
        rollentext = EINLEITUNG + "\n\n" + rollentext
    return (f"{rollentext}\n\n# Unterlagen\n\n{unterlagen_text(unterlagen, reihenfolge)}\n\n"
            "# Antwort\nNur dieses JSON, nichts sonst:\n"
            '{"stimme": "JA" | "NEIN", "veto": true | false, "schwere": "blocker" | "hoch" | "mittel" | "niedrig", '
            '"gruende": ["… mit Datei:Zeile oder Bildname …"], "bedingungen": ["…"]}')


ERLAUBTE_UNTERLAGEN = ("Aufgabe", "Plan", "Diff", "Prüfausgaben", "Bilder")


def befrage(unterlagen, *, dateien, art, stufe, cfg, aufrufer=None, ordner=None, konto=None, zufall=None):
    """Jury über Plan oder Ergebnis. `unterlagen`: dict mit nur den erlaubten Schlüsseln (Aufgabe, Plan, Diff,
    Prüfausgaben, Bilder). `aufrufer(rolle, prompt)` → claude_call.Ergebnis (in Tests gefälscht)."""
    fremd = set(unterlagen) - set(ERLAUBTE_UNTERLAGEN)
    if fremd:  # z. B. Selbstbeschreibung des Bauers – darf die Jury nie sehen
        raise ValueError(f"Jury darf nur {ERLAUBTE_UNTERLAGEN} sehen, nicht {sorted(fremd)}")
    j = cfg["jury"]
    noetig = j["mehrheit_streng"] if streng(dateien, art, cfg) else j["mehrheit_normal"]
    noetig = min(noetig, len(j["rollen"]))
    zufall = zufall or random.Random()
    if aufrufer is None:
        def aufrufer(rolle, prompt, name):
            return claude_call.aufruf(prompt, modell=cfg["modelle"]["juror"], werkzeuge=cfg["werkzeuge"]["juror"],
                                      zeitlimit=cfg["grenzen"]["zeitlimit_aufruf_s"], cwd=basis.REPO,
                                      pruefe=schema_fehler, versuche=cfg["grenzen"]["json_versuche"],
                                      ordner=ordner, name=name, konto=konto)
    durchlaeufe = 2 if stufe in j["zwei_durchlaeufe_stufe"] else 1
    urteile = []
    for d in range(durchlaeufe):
        reihenfolge = list(ERLAUBTE_UNTERLAGEN)
        if d > 0:
            while reihenfolge == list(ERLAUBTE_UNTERLAGEN):
                zufall.shuffle(reihenfolge)
        stimmen = []
        for rolle in j["rollen"]:  # jeder getrennt, keiner sieht die anderen
            prompt = juror_prompt(rolle, unterlagen, reihenfolge)
            stimmen.append(werte(rolle, aufrufer(rolle, prompt, f"juror-{rolle}-d{d + 1}")))
        urteile.append(zaehle(stimmen, noetig))
    if len(urteile) == 1:
        return urteile[0]
    ok = all(u.angenommen for u in urteile)
    text = " / ".join(f"Durchlauf {i + 1}: {u.zusammenfassung}" for i, u in enumerate(urteile))
    return Urteil(ok, min(u.ja for u in urteile), noetig, [s for u in urteile for s in u.stimmen],
                  sorted({r for u in urteile for r in u.veto_von}), text)
