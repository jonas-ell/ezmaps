"""Ein claude -p-Aufruf (headless) mit Zeitlimit, Kosten und JSON-Prüfung (docs/AUTOPILOT_PLAN.md 2).

Der Prompt geht über stdin (Windows-Befehlszeilen sind auf 8191 Zeichen begrenzt).
Antwort muss JSON nach Schema sein, sonst bis zu `versuche` neue Versuche mit dem Fehler als Hinweis.
"""
import dataclasses
import json
import os
import re
import shutil
import subprocess
import time

import basis


@dataclasses.dataclass
class Ergebnis:
    ok: bool
    daten: object = None       # geprüftes JSON aus der Antwort
    text: str = ""             # Antworttext von Claude
    dollar: float = 0.0
    sekunden: float = 0.0
    session_id: str = ""
    fehler: str = ""


def json_aus_text(text):
    """Erstes JSON-Objekt oder -Array aus dem Antworttext (auch in ```json … ```)."""
    m = re.search(r"```(?:json)?\s*(.*?)```", text, re.S)
    kandidat = m.group(1) if m else text
    starts = [i for i in (kandidat.find("{"), kandidat.find("[")) if i >= 0]
    if not starts:
        raise ValueError("kein JSON in der Antwort")
    dec = json.JSONDecoder()
    obj, _ = dec.raw_decode(kandidat[min(starts):])
    return obj


SYSTEM_HINWEIS = ("Du läufst headless als Teil des EzMaps-Autopiloten (tools/autopilot, docs/AUTOPILOT_PLAN.md). "
                 "Das Antwortformat aus CLAUDE.md (Mac-Build-Prompt, Liste „Auf dem Gerät testen“) gilt hier NICHT: "
                 "antworte nur mit dem verlangten JSON. Alle anderen Regeln aus CLAUDE.md gelten weiter.")


def saubere_umgebung():
    """Umgebung ohne die Variablen einer laufenden Claude-Code-Sitzung (CLAUDECODE, CLAUDE_CODE_*, Messaging-Socket):
    jeder Aufruf ist eine eigene, unabhängige Sitzung – wie aus einem normalen Terminal gestartet."""
    weg = ("CLAUDECODE", "CLAUDE_CODE_", "CLAUDE_PID", "CLAUDE_AGENT_SDK", "CLAUDE_EFFORT")
    return {k: v for k, v in os.environ.items() if not k.startswith(weg)}


def _programm():
    return shutil.which("claude") or "claude"


def aufruf(prompt, *, modell, werkzeuge, zeitlimit, cwd=None, pruefe=None, versuche=2,
           start=None, ordner=None, name="aufruf", konto=None):
    """Startet claude -p. `pruefe(daten)` gibt einen Fehlertext oder None zurück.
    `start` ersetzt subprocess.run (Tests). Zeitüberschreitung und Fehler → ok=False."""
    start = start or subprocess.run
    hinweis = ""
    gesamt = Ergebnis(ok=False)
    for n in range(versuche + 1):
        voll = prompt + hinweis
        basis.schreibe(ordner, f"{name}-{n}-prompt.md", voll)
        cmd = [_programm(), "-p", "--output-format", "json", "--model", modell, "--allowedTools", ",".join(werkzeuge),
               "--append-system-prompt", SYSTEM_HINWEIS]
        t0 = time.time()
        try:
            p = start(cmd, input=voll, capture_output=True, text=True, encoding="utf-8", timeout=zeitlimit, cwd=cwd,
                      env=saubere_umgebung())
        except subprocess.TimeoutExpired:
            gesamt.sekunden += time.time() - t0
            gesamt.fehler = f"Zeitüberschreitung nach {zeitlimit} s"
            break
        gesamt.sekunden += time.time() - t0
        basis.schreibe(ordner, f"{name}-{n}-antwort.json", p.stdout or p.stderr or "")
        try:
            huelle = json.loads(p.stdout)
        except (json.JSONDecodeError, TypeError):
            gesamt.fehler = f"claude -p lieferte kein JSON (Code {p.returncode}): {(p.stderr or p.stdout or '')[:300]}"
            break
        gesamt.dollar += float(huelle.get("total_cost_usd") or 0.0)
        gesamt.session_id = huelle.get("session_id", "")
        gesamt.text = huelle.get("result") or ""
        if huelle.get("is_error"):
            gesamt.fehler = f"claude -p meldet Fehler: {gesamt.text[:300]}"
            break
        try:
            daten = json_aus_text(gesamt.text)
            fehler = pruefe(daten) if pruefe else None
        except ValueError as e:
            fehler = str(e)
        if not fehler:
            gesamt.ok, gesamt.daten, gesamt.fehler = True, daten, ""
            break
        gesamt.fehler = fehler
        hinweis = (f"\n\n---\nDeine letzte Antwort war ungültig: {fehler}\n"
                   "Antworte NUR mit dem verlangten JSON, ohne weiteren Text.")
    if konto is not None:
        konto.buchen(dollar=gesamt.dollar, sekunden=gesamt.sekunden)
    return gesamt
