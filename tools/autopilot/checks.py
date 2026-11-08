"""Prüfungen ohne KI (docs/AUTOPILOT_PLAN.md 2, 6.4, 7). Jede liefert Status und Beweise (Datei:Zeile oder Logzeile)."""
import contextlib
import dataclasses
import os
import pathlib
import re
import shutil
import subprocess
import time

import basis

TEXT_ENDUNGEN = {".swift", ".strings", ".md", ".yml", ".yaml", ".json", ".plist", ".xcprivacy", ".txt", ".html", ".js", ".py", ".sh"}


@dataclasses.dataclass
class Pruefung:
    name: str
    status: str            # ok | warnung | fehler | uebersprungen
    text: str
    beweis: list = dataclasses.field(default_factory=list)


def _git_dateien(*pfade):
    out = subprocess.run(["git", "ls-files", "--", *pfade], cwd=basis.REPO, capture_output=True, text=True,
                         encoding="utf-8").stdout
    return [basis.REPO / p for p in out.splitlines() if p]


def _zeilen(datei):
    try:
        return datei.read_text(encoding="utf-8").splitlines()
    except (UnicodeDecodeError, OSError):
        return []


def _rel(p):
    return str(pathlib.Path(p).relative_to(basis.REPO)).replace("\\", "/")


def _suche(dateien, muster, flags=re.I):
    rx = re.compile(muster, flags)
    treffer = []
    for d in dateien:
        if d.suffix.lower() not in TEXT_ENDUNGEN:
            continue
        for i, z in enumerate(_zeilen(d), 1):
            if rx.search(z):
                treffer.append(f"{_rel(d)}:{i} {z.strip()[:110]}")
    return treffer


def spielnamen(cfg):
    """Kein Spielname in App/, docs/store/ und App-Texten (Plan 6.4). Kommentare im Code zählen mit (Repo ist öffentlich)."""
    dateien = _git_dateien("App", "docs/store", "docs/APPSTORE_TEXTE.md")
    muster = r"\b(" + "|".join(re.escape(n) for n in cfg["spielnamen"]) + r")\b"
    t = _suche(dateien, muster)
    texte = [x for x in t if ".strings:" in x or "docs/store" in x or "APPSTORE_TEXTE" in x]
    if texte:
        return Pruefung("Spielnamen", "fehler", f"{len(texte)} Treffer in App-/Store-Texten, {len(t)} insgesamt", texte + t[:20])
    if t:
        return Pruefung("Spielnamen", "warnung", f"{len(t)} Treffer in Code-Kommentaren/Namen (öffentliches Repo)", t[:25])
    return Pruefung("Spielnamen", "ok", "keine Treffer in App/, docs/store/, App-Texten", [])


def _yml_liste(schluessel):
    for i, z in enumerate(_zeilen(basis.REPO / "project.yml"), 1):
        m = re.match(rf"\s*{schluessel}:\s*\[(.*)\]", z)
        if m:
            return i, [x.strip() for x in m.group(1).split(",") if x.strip()]
    return None, []


def schriften():
    """UIAppFonts ⊆ Schriften im Bundle (im Repo); kein Pricedown im Archiv-Weg (Plan 6.1 Nr. 1, 6.4)."""
    zeile, fonts = _yml_liste("UIAppFonts")
    im_repo = {p.name for p in _git_dateien("App/Fonts")}
    fehlt = [f for f in fonts if f not in im_repo]
    beweis = [f"project.yml:{zeile} UIAppFonts: {fonts}"] if zeile else []
    beweis += [f"{_rel(d)}" for d in _git_dateien("App/Fonts")]
    weg = _suche([basis.REPO / "tools/mac_build.sh", basis.REPO / "tools/mac_archive.sh"], r"pricedown")
    status, text = "ok", "alle UIAppFonts liegen im Repo, Archiv-Weg ohne Pricedown"
    if fehlt:
        status, text = "fehler", f"UIAppFonts nennt Schriften, die nicht im Repo sind: {fehlt}"
    if weg:
        status = "fehler"
        text += "; Pricedown wird im Build-Weg kopiert (gilt auch für das Archiv, wenn mac_archive.sh mac_build.sh nutzt)"
    return Pruefung("Schriften", status, text, beweis + weg)


def hintergrund():
    zeile, modi = _yml_liste("UIBackgroundModes")
    extra = [m for m in modi if m not in ("location", "audio")]
    b = [f"project.yml:{zeile} UIBackgroundModes: {modi}"] if zeile else []
    if extra:
        return Pruefung("Hintergrund-Modi", "fehler", f"nicht erlaubt: {extra}", b)
    return Pruefung("Hintergrund-Modi", "ok", "nur location und audio", b)


def testkaeufe():
    """Test-Kauf-Code nur hinter #if DEBUG || EZTEST (Plan 6.4)."""
    d = basis.REPO / "App/PurchaseManager.swift"
    z = _zeilen(d)
    tiefe, schutz, offen = 0, [], []
    for i, s in enumerate(z, 1):
        t = s.strip()
        if t.startswith("#if"):
            schutz.append("DEBUG" in t or "EZTEST" in t)
        elif t.startswith("#endif") and schutz:
            schutz.pop()
        elif re.search(r"testMode\s*=\s*true|TestStore\.(unlock|buy|kaufen)", t) and not any(schutz):
            offen.append(f"{_rel(d)}:{i} {t[:100]}")
    geschuetzt = [f"{_rel(d)}:{i} {s.strip()}" for i, s in enumerate(z, 1) if re.search(r"#if .*(DEBUG|EZTEST)", s)]
    if offen:
        return Pruefung("Test-Käufe", "fehler", "Test-Kauf außerhalb von #if DEBUG || EZTEST", offen)
    if not geschuetzt:
        return Pruefung("Test-Käufe", "warnung", "kein #if DEBUG || EZTEST gefunden", [f"{_rel(d)}:1"])
    return Pruefung("Test-Käufe", "ok", "testMode wird nur hinter #if DEBUG || EZTEST gesetzt", geschuetzt)


def blitzer(cfg):
    muster = "|".join(re.escape(b) for b in cfg["blitzer_begriffe"])
    # Hinweise wie „keine Blitzer (§ 23 Abs. 1c StVO)“ sind erlaubt, nur Warn-Funktionen zählen
    t = [x for x in _suche(_git_dateien("App", "Core/Sources"), muster) if not re.search(r"keine?|§ ?23|nie|no", x, re.I)]
    return Pruefung("Blitzer", "fehler" if t else "ok", "Blitzer-Begriffe im Code" if t else "keine Blitzer-Begriffe", t)


PRIVACY_APIS = {
    "NSPrivacyAccessedAPICategoryUserDefaults": r"\bUserDefaults\b|@AppStorage",
    "NSPrivacyAccessedAPICategorySystemBootTime": r"systemUptime|mach_absolute_time",
    "NSPrivacyAccessedAPICategoryFileTimestamp": r"creationDate|modificationDate|contentModificationDate|\.fileModificationDate",
    "NSPrivacyAccessedAPICategoryDiskSpace": r"volumeAvailableCapacity|systemFreeSize|systemSize",
}


def privacy():
    datei = basis.REPO / "App/PrivacyInfo.xcprivacy"
    inhalt = datei.read_text(encoding="utf-8") if datei.exists() else ""
    code = _git_dateien("App", "Core/Sources")
    fehlt, beweis = [], []
    for kat, muster in PRIVACY_APIS.items():
        t = [x for x in _suche(code, muster, 0) if ".swift:" in x]
        if t:
            beweis.append(t[0])
            if kat not in inhalt:
                fehlt.append(kat)
                beweis.extend(t[:3])
    if fehlt:
        return Pruefung("PrivacyInfo", "fehler", f"Required-Reason-API im Code, aber nicht in PrivacyInfo: {fehlt}", beweis)
    return Pruefung("PrivacyInfo", "ok", "alle genutzten Required-Reason-APIs sind eingetragen",
                    beweis + [f"{_rel(datei)}:1"] if datei.exists() else beweis)


def englisch():
    """Jeder L("…")-Text hat einen Eintrag in en.lproj (Plan 6.4)."""
    en = (basis.REPO / "App/en.lproj/Localizable.strings").read_text(encoding="utf-8")
    vorhanden = set(re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=', en, re.M))
    fehlt = []
    for d in _git_dateien("App"):
        if d.suffix != ".swift":
            continue
        for i, z in enumerate(_zeilen(d), 1):
            for k in re.findall(r'\bL\("((?:[^"\\]|\\.)*)"\)', z):
                if k not in vorhanden and not re.fullmatch(r"[\W\d]*", k):
                    fehlt.append(f"{_rel(d)}:{i} {k[:60]}")
    if fehlt:
        return Pruefung("Englisch", "warnung", f"{len(fehlt)} Texte ohne englischen Eintrag", fehlt[:30])
    return Pruefung("Englisch", "ok", "alle L(…)-Texte haben Englisch", [])


def stil():
    p = subprocess.run(["python", "tools/maplibre/check_style.py"], cwd=basis.REPO, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    letzte = (p.stdout + p.stderr).strip().splitlines()[-3:]
    ok = p.returncode == 0 and any("STIL OK" in z for z in letzte)
    return Pruefung("Kartenstil", "ok" if ok else "fehler", " | ".join(letzte), [f"check_style.py: {z}" for z in letzte])


def core_tests():
    if not shutil.which("swift"):
        return Pruefung("Core-Tests", "uebersprungen", "swift nicht installiert (Windows) – laufen im Mac-Build mit", [])
    p = subprocess.run(["swift", "test"], cwd=basis.REPO / "Core", capture_output=True, text=True, encoding="utf-8",
                       errors="replace", timeout=1800)
    z = (p.stdout + p.stderr).strip().splitlines()[-3:]
    return Pruefung("Core-Tests", "ok" if p.returncode == 0 else "fehler", " | ".join(z), z)


@contextlib.contextmanager
def mac_sperre(warten_s=0):
    """Plan 7: immer nur ein Mac-Lauf zur Zeit (.autopilot/mac.lock)."""
    lock = basis.DATEN / "mac.lock"
    lock.parent.mkdir(parents=True, exist_ok=True)
    ende = time.time() + warten_s
    while True:
        try:
            fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.write(fd, str(os.getpid()).encode())
            os.close(fd)
            break
        except FileExistsError:
            if time.time() >= ende:
                raise RuntimeError(f"Mac belegt ({lock})")
            time.sleep(10)
    try:
        yield
    finally:
        lock.unlink(missing_ok=True)


def mac_erreichbar():
    p = subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "mac-ezmaps", "ping"],
                       capture_output=True, text=True)
    return p.stdout.strip() == "ok", (p.stdout + p.stderr).strip()


def mac_build(ordner=None):
    """Build + Tests über das Gate (tools/mac_run.sh). Nur mit Sperre."""
    ok, info = mac_erreichbar()
    if not ok:
        return Pruefung("Mac-Build", "uebersprungen", f"Mac nicht erreichbar: {info[:120]}", [])
    with mac_sperre():
        p = subprocess.run(["bash", "tools/mac_run.sh"], cwd=basis.REPO, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=3600)
    log = p.stdout + p.stderr
    basis.schreibe(ordner, "mac_build.log", log)
    zeilen = log.splitlines()
    fehler = [f"mac_build.log:{i} {z.strip()[:120]}" for i, z in enumerate(zeilen, 1) if "error:" in z][:15]
    gruen = "ALLES OK" in log
    beweis = fehler or [f"mac_build.log:{i} {z.strip()}" for i, z in enumerate(zeilen, 1) if "ALLES OK" in z or "Executed" in z][:3]
    return Pruefung("Mac-Build", "ok" if gruen else "fehler", "Build und Tests grün" if gruen else "Build oder Tests rot", beweis)


def alle_ohne_mac(cfg):
    return [spielnamen(cfg), schriften(), hintergrund(), testkaeufe(), blitzer(cfg), privacy(), englisch(), stil(), core_tests()]
