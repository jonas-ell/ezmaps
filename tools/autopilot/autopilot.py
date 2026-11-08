"""EzMaps-Autopilot (docs/AUTOPILOT_PLAN.md). Befehle:
  python tools/autopilot/autopilot.py audit [--neu]   Prüfliste anlegen/prüfen, Backlog füllen (ändert keinen Code)
  python tools/autopilot/autopilot.py status          Tageskonto, STOP, Backlog
  python tools/autopilot/autopilot.py jury-test       unittest (Jury, Backlog, GM-Nummer, STOP)
  python tools/autopilot/autopilot.py run [--dry]     Runden – erst ab M3 freigeschaltet (Nutzer: „weiter“)
"""
import argparse
import concurrent.futures as cf
import datetime as dt
import glob
import json
import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import backlog  # noqa: E402
import basis  # noqa: E402
import checks  # noqa: E402
import claude_call  # noqa: E402
import jury  # noqa: E402
import pruefliste  # noqa: E402

PRUEFLISTE = basis.REPO / "docs/APPSTORE_PRUEFLISTE.md"
BERICHTE = basis.REPO / "docs/autopilot"
ZEICHEN = {"ok": "✅", "warnung": "⚠️", "fehler": "❌", "uebersprungen": "⏭️"}


def finder_schema(ids):
    def pruefe(d):
        if not isinstance(d, dict) or not isinstance(d.get("punkte"), list):
            return "Antwort muss {\"punkte\": [...]} sein"
        gefunden = {p.get("id") for p in d["punkte"] if isinstance(p, dict)}
        if gefunden != set(ids):
            return f"genau diese Punkte beantworten: {ids} (bekommen: {sorted(x for x in gefunden if x)})"
        for p in d["punkte"]:
            if p.get("status") not in ("ok", "warnung", "fehler"):
                return f"{p.get('id')}: status muss ok, warnung oder fehler sein"
            if not isinstance(p.get("beweis"), list):
                return f"{p.get('id')}: beweis muss eine Liste sein"
            if p["status"] != "ok" and not isinstance(p.get("aufgabe"), dict):
                return f"{p.get('id')}: bei warnung/fehler gehört eine aufgabe dazu"
        return None
    return pruefe


def finder_prompt(ids, pruef_text, bilder):
    punkte = {p[0]: p for p in pruefliste.PUNKTE}
    liste = "\n".join(f"- **{i} {punkte[i][1]}**: {punkte[i][2]}" for i in ids)
    rolle = (basis.HIER / "prompts/finder.md").read_text(encoding="utf-8")
    return f"""{rolle}

# Zu prüfen
{liste}

# Ergebnisse der Prüfungen ohne KI (checks.py)
{pruef_text}

# Vorhandene Bilder aus der echten App (mit Read ansehen, wo nötig)
{bilder}

# Antwort
Nur dieses JSON, nichts sonst:
{{"punkte": [{{"id": "6.x.y", "status": "ok" | "warnung" | "fehler", "befund": "1–3 Sätze, Deutsch, einfach",
  "beweis": ["Datei:Zeile …", "docs/store/…png …"],
  "aufgabe": null | {{"titel": "kurz, was zu tun ist", "stufe": "A"|"B"|"C"|"D"|"E", "art": "carplay|kauf|recht|standort|datenschutz|technik|text|design",
                     "dateien": ["…"], "nutzer": false}}}}]}}
"""


def bilder_liste():
    pfade = sorted(glob.glob(str(basis.REPO / "docs/store/**/*.png"), recursive=True))
    return "\n".join("- " + str(pathlib.Path(p).relative_to(basis.REPO)).replace("\\", "/") for p in pfade[:80])


def pruef_text(ergebnisse):
    return "\n".join(f"- {ZEICHEN[e.status]} {e.name}: {e.text}" + "".join(f"\n  - {b}" for b in e.beweis[:6])
                     for e in ergebnisse)


def audit(args):
    cfg = basis.einstellungen()
    konto = basis.Tageskonto()
    grund = basis.darf_laufen(konto, cfg["grenzen"])
    if grund:
        print(f"Audit nicht gestartet: {grund}")
        return 1
    ordner = basis.protokoll_ordner("audit-" + dt.datetime.now().strftime("%H%M%S"))
    print("1/4 Prüfungen ohne KI …")
    ergebnisse = checks.alle_ohne_mac(cfg)
    print("2/4 Mac-Build über das Gate …")
    ergebnisse.append(checks.mac_build(ordner) if not args.ohne_mac else
                      checks.Pruefung("Mac-Build", "uebersprungen", "mit --ohne-mac gestartet", []))
    for e in ergebnisse:
        print(f"   {ZEICHEN[e.status]} {e.name}: {e.text}")
    basis.schreibe(ordner, "checks.json", [e.__dict__ for e in ergebnisse])

    print(f"3/4 Finder ({len(pruefliste.GRUPPEN)} getrennte claude -p-Aufrufe, nur lesen) …")
    pt, bl = pruef_text(ergebnisse), bilder_liste()

    def finde(ids):
        return ids, claude_call.aufruf(finder_prompt(ids, pt, bl), modell=cfg["modelle"]["finder"],
                                       werkzeuge=cfg["werkzeuge"]["finder"], zeitlimit=cfg["grenzen"]["zeitlimit_aufruf_s"],
                                       cwd=basis.REPO, pruefe=finder_schema(ids), versuche=cfg["grenzen"]["json_versuche"],
                                       ordner=ordner, name="finder-" + "_".join(ids))
    befunde = {}
    with cf.ThreadPoolExecutor(max_workers=4) as pool:
        for ids, e in pool.map(finde, pruefliste.GRUPPEN):
            konto.buchen(dollar=e.dollar, sekunden=e.sekunden)
            if not e.ok:
                for i in ids:
                    befunde[i] = {"id": i, "status": "warnung", "befund": f"Finder ohne gültige Antwort: {e.fehler}",
                                  "beweis": [], "aufgabe": None}
                print(f"   ⚠️ {ids}: {e.fehler[:120]}")
                continue
            for p in e.daten["punkte"]:
                # Plan 3: ohne Beweis kein ok und keine Aufgabe
                p["beweis"] = [b for b in p.get("beweis") or [] if jury.hat_beweis(b)]
                if not p["beweis"]:
                    p["befund"] = (p.get("befund") or "") + " (ohne Beweis – nicht gewertet)"
                    p["status"], p["aufgabe"] = "warnung", None
                befunde[p["id"]] = p
            print(f"   {ids}: {e.dollar:.2f} $")
    basis.schreibe(ordner, "befunde.json", befunde)

    print("4/4 Prüfliste, Backlog, Bericht …")
    bl_ = backlog.Backlog()
    neu, nutzer = [], []
    for i, *_ in pruefliste.PUNKTE:
        p = befunde.get(i) or {}
        a = p.get("aufgabe")
        if p.get("status") in ("warnung", "fehler") and a:
            if a.get("nutzer"):
                nutzer.append((i, a.get("titel", ""), p.get("beweis", [])))
                continue
            t = bl_.hinzufuegen(a.get("titel") or i, a.get("stufe", "C"), p["beweis"], art=a.get("art", ""),
                                dateien=a.get("dateien") or [], quelle=f"prüfliste {i}")
            if t:
                neu.append(t)
    for e in ergebnisse:  # rote Prüfungen ohne KI werden ebenfalls Aufgaben
        if e.status == "fehler":
            t = bl_.hinzufuegen(f"Prüfung „{e.name}“ rot: {e.text[:80]}", "A" if e.name in ("Schriften", "Blitzer", "Mac-Build") else "B",
                                e.beweis, art="technik", quelle="checks.py")
            if t:
                neu.append(t)
    bl_.speichern()
    md = prueflisten_text(befunde, ergebnisse)
    if PRUEFLISTE.exists() and not args.neu:
        ziel = BERICHTE / f"pruefung-{basis.heute()}.md"  # Prüfliste selbst ändert nur der Nutzer (Plan 1.4)
    else:
        ziel = PRUEFLISTE
    ziel.parent.mkdir(parents=True, exist_ok=True)
    ziel.write_text(md, encoding="utf-8")
    bericht(neu, nutzer, ergebnisse, konto)
    print(f"Fertig: {ziel.relative_to(basis.REPO)}, {len(neu)} neue Aufgaben, {len(nutzer)} für dich. "
          f"Kosten heute: {konto.stand['dollar']:.2f} $")
    return 0


def prueflisten_text(befunde, ergebnisse):
    z = ["# Prüfliste App Store + CarPlay", "",
         f"Stand: {dt.datetime.now():%Y-%m-%d %H:%M}, Commit {_commit()}. Erstellt von `autopilot.py audit` "
         "(docs/AUTOPILOT_PLAN.md Abschnitt 6). Inhalt der Liste ändert nur der Nutzer.", "",
         "Zeichen: ✅ erfüllt (mit Beweis) · ⚠️ Risiko oder unklar · ❌ verstößt · ⏭️ nicht geprüft", ""]
    abschnitt = None
    for i, titel, text in pruefliste.PUNKTE:
        a = i.rsplit(".", 1)[0]
        if a != abschnitt:
            abschnitt = a
            z += ["", f"## {pruefliste.ABSCHNITTE[a]}", ""]
        p = befunde.get(i) or {"status": "uebersprungen", "befund": "nicht geprüft", "beweis": []}
        z.append(f"- {ZEICHEN[p['status']]} **{i} {titel}** – {p.get('befund', '')}")
        z.append(f"  - Prüfpunkt: {text}")
        for b in p.get("beweis", [])[:6]:
            z.append(f"  - Beweis: `{b}`")
        if p.get("aufgabe"):
            a_ = p["aufgabe"]
            z.append(f"  - Aufgabe: Stufe {a_.get('stufe')} – {a_.get('titel')}" + (" (**du**)" if a_.get("nutzer") else ""))
    z += ["", "## 6.4 Feste Prüfregeln ohne KI (checks.py)", ""]
    for e in ergebnisse:
        z.append(f"- {ZEICHEN[e.status]} **{e.name}** – {e.text}")
        for b in e.beweis[:5]:
            z.append(f"  - Beweis: `{b}`")
    return "\n".join(z) + "\n"


def bericht(neu, nutzer, ergebnisse, konto):
    datei = BERICHTE / f"bericht-{basis.heute()}.md"
    z = [f"# Autopilot-Bericht {basis.heute()}", "", "## Gemacht", "",
         f"- Audit: Prüfliste geprüft, {len(neu)} neue Aufgaben im Backlog. Kosten heute {konto.stand['dollar']:.2f} $.", "",
         "## Neue Aufgaben", ""]
    z += [f"- {t.id} Stufe {t.stufe}: {t.titel} (Beweis: `{t.beweis[0]}`)" for t in neu] or ["- keine"]
    z += ["", "## Du entscheidest", ""]
    z += [f"- {i}: {t}" + (f" (Beweis: `{b[0]}`)" if b else "") for i, t, b in nutzer] or ["- nichts"]
    z += [f"- Mac-Build: {e.text}" for e in ergebnisse if e.name == "Mac-Build" and e.status != "ok"]
    BERICHTE.mkdir(parents=True, exist_ok=True)
    datei.write_text("\n".join(z) + "\n", encoding="utf-8")


def _commit():
    return subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=basis.REPO, capture_output=True, text=True).stdout.strip()


def status(_args):
    cfg = basis.einstellungen()
    k = basis.Tageskonto()
    print(f"Heute: {k.stand}")
    print(f"STOP: {'ja' if basis.stop_gesetzt() else 'nein'}; Grenze: {k.grenze_erreicht(cfg['grenzen']) or 'frei'}")
    b = backlog.Backlog()
    for st in backlog.STUFEN:
        offen = [a for a in b.offen() if a.stufe == st]
        print(f"Stufe {st}: {len(offen)} offen" + "".join(f"\n  {a.id} {a.titel}" for a in offen))
    n = b.naechste()
    print(f"Nächste Aufgabe: {n.id + ' ' + n.titel if n else '–'}")
    return 0


def jury_test(_args):
    return subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", str(basis.HIER / "tests"), "-v"],
                          cwd=basis.HIER).returncode


def run(args):
    print("run ist noch nicht freigeschaltet: M3 (Probelauf ohne Merge) startet erst nach „weiter“ vom Nutzer, "
          "M4 (Merge nach main) erst nach „los“ (docs/AUTOPILOT_PLAN.md 9).")
    return 2


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="befehl", required=True)
    a = sub.add_parser("audit")
    a.add_argument("--neu", action="store_true", help="Prüfliste neu schreiben (nur auf Wunsch des Nutzers)")
    a.add_argument("--ohne-mac", action="store_true")
    sub.add_parser("status")
    sub.add_parser("jury-test")
    r = sub.add_parser("run")
    r.add_argument("--dry", action="store_true")
    args = ap.parse_args()
    return {"audit": audit, "status": status, "jury-test": jury_test, "run": run}[args.befehl](args)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
