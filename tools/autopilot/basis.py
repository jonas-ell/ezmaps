"""Gemeinsames: Pfade, Einstellungen, Not-Aus (STOP), Tagesgrenzen, Protokoll (docs/AUTOPILOT_PLAN.md 1.5, 2)."""
import datetime as dt
import json
import os
import pathlib

import yaml

REPO = pathlib.Path(__file__).resolve().parents[2]
HIER = pathlib.Path(__file__).resolve().parent
STOP_DATEI = HIER / "STOP"
DATEN = REPO / ".autopilot"  # nicht committet


def einstellungen(pfad=HIER / "config.yaml"):
    with open(pfad, encoding="utf-8") as f:
        return yaml.safe_load(f)


def heute():
    return dt.date.today().isoformat()


def stop_gesetzt(stop_datei=STOP_DATEI):
    """Not-Aus: liegt tools/autopilot/STOP vor, endet die Schleife nach der laufenden Runde."""
    return pathlib.Path(stop_datei).exists()


class Tageskonto:
    """Runden, Dollar und Sekunden je Tag in .autopilot/konto.json."""

    def __init__(self, datei=None, tag=None):
        self.datei = pathlib.Path(datei or DATEN / "konto.json")
        self.tag = tag or heute()
        self.alle = json.loads(self.datei.read_text(encoding="utf-8")) if self.datei.exists() else {}

    @property
    def stand(self):
        return self.alle.setdefault(self.tag, {"runden": 0, "dollar": 0.0, "sekunden": 0.0})

    def buchen(self, dollar=0.0, sekunden=0.0, runden=0):
        s = self.stand
        s["dollar"] = round(s["dollar"] + (dollar or 0.0), 4)
        s["sekunden"] = round(s["sekunden"] + (sekunden or 0.0), 1)
        s["runden"] += runden
        self.datei.parent.mkdir(parents=True, exist_ok=True)
        self.datei.write_text(json.dumps(self.alle, indent=1), encoding="utf-8")

    def grenze_erreicht(self, grenzen):
        """Grund als Text, wenn eine Tagesgrenze erreicht ist, sonst None."""
        s = self.stand
        if s["runden"] >= grenzen["runden_pro_tag"]:
            return f"Runden-Grenze erreicht ({s['runden']}/{grenzen['runden_pro_tag']})"
        if s["dollar"] >= grenzen["dollar_pro_tag"]:
            return f"Kosten-Grenze erreicht ({s['dollar']:.2f}/{grenzen['dollar_pro_tag']} $)"
        if s["sekunden"] >= grenzen["stunden_pro_tag"] * 3600:
            return f"Zeit-Grenze erreicht ({s['sekunden'] / 3600:.1f}/{grenzen['stunden_pro_tag']} h)"
        return None


def darf_laufen(konto, grenzen, stop_datei=STOP_DATEI):
    """Plan 3 Schritt 0: None = weiter, sonst Grund zum Aufhören."""
    if stop_gesetzt(stop_datei):
        return "STOP-Datei liegt vor"
    return konto.grenze_erreicht(grenzen)


def protokoll_ordner(runde):
    """.autopilot/logs/<datum>/<runde>/"""
    p = DATEN / "logs" / heute() / str(runde)
    p.mkdir(parents=True, exist_ok=True)
    return p


def schreibe(ordner, name, inhalt):
    if ordner is None:
        return
    p = pathlib.Path(ordner) / name
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(inhalt if isinstance(inhalt, str) else json.dumps(inhalt, indent=1, ensure_ascii=False), encoding="utf-8")


os.environ.setdefault("PYTHONIOENCODING", "utf-8")
