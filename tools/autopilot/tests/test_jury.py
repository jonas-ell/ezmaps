"""Alle Jury-Regeln aus docs/AUTOPILOT_PLAN.md Abschnitt 4 – mit gefälschten Antworten, keine echten Aufrufe."""
import pathlib
import random
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import basis  # noqa: E402
import claude_call  # noqa: E402
import jury  # noqa: E402

CFG = basis.einstellungen()
UNTERLAGEN = {"Aufgabe": "T001 Test", "Plan": "Plan", "Diff": "diff", "Prüfausgaben": "ok", "Bilder": "keine"}


def antwort(stimme="JA", veto=False, schwere="niedrig", gruende=("App/ContentView.swift:12 passt",), bedingungen=()):
    return claude_call.Ergebnis(ok=True, daten={"stimme": stimme, "veto": veto, "schwere": schwere,
                                                "gruende": list(gruende), "bedingungen": list(bedingungen)})


def gefaelscht(je_rolle, standard=None):
    """aufrufer, der je Rolle eine feste Antwort liefert und mitschreibt, was er gesehen hat."""
    gesehen = []

    def aufrufer(rolle, prompt, name):
        gesehen.append((rolle, prompt, name))
        return je_rolle.get(rolle, standard or antwort())
    return aufrufer, gesehen


def befrage(je_rolle, standard=None, dateien=("App/ContentView.swift",), art="technik", stufe="B", unterlagen=UNTERLAGEN):
    aufrufer, gesehen = gefaelscht(je_rolle, standard)
    u = jury.befrage(unterlagen, dateien=list(dateien), art=art, stufe=stufe, cfg=CFG, aufrufer=aufrufer,
                     zufall=random.Random(1))
    return u, gesehen


class Mehrheit(unittest.TestCase):
    def test_fuenf_ja_angenommen(self):
        u, _ = befrage({})
        self.assertTrue(u.angenommen)
        self.assertEqual((u.ja, u.noetig), (5, 4))

    def test_vier_von_fuenf_reicht_normal(self):
        u, _ = befrage({"fahrer": antwort("NEIN", gruende=["docs/store/ui/karte.png verdeckt"])})
        self.assertTrue(u.angenommen)
        self.assertEqual(u.ja, 4)

    def test_drei_von_fuenf_abgelehnt(self):
        nein = antwort("NEIN", gruende=["App/A.swift:1 falsch"])
        u, _ = befrage({"fahrer": nein, "recht": nein})
        self.assertFalse(u.angenommen)
        self.assertEqual(u.ja, 3)


class Streng(unittest.TestCase):
    """5 von 5, wenn CarPlay, Käufe, Standort/Datenschutz, Recht oder Hintergrund-Modi betroffen sind."""

    def pruefe_streng(self, dateien=(), art="technik"):
        u, _ = befrage({"fahrer": antwort("NEIN", gruende=["x.png zu klein"])}, dateien=dateien, art=art)
        self.assertEqual(u.noetig, 5)
        self.assertFalse(u.angenommen, "4 von 5 darf bei strengen Änderungen nicht reichen")

    def test_carplay_pfad(self):
        self.pruefe_streng(["App/CarPlaySceneDelegate.swift"])

    def test_kauf_pfad(self):
        self.pruefe_streng(["App/PurchaseManager.swift"])

    def test_privacy(self):
        self.pruefe_streng(["App/PrivacyInfo.xcprivacy"])

    def test_project_yml(self):
        self.pruefe_streng(["project.yml"])

    def test_info_plist(self):
        self.pruefe_streng(["App/Info.plist"])

    def test_legal(self):
        self.pruefe_streng(["docs/legal/datenschutz.md"])

    def test_windows_pfad(self):
        self.pruefe_streng(["App\\CarPlaySceneDelegate.swift"])

    def test_arten(self):
        for art in ["carplay", "kauf", "storekit", "standort", "datenschutz", "recht", "hintergrund", "CarPlay"]:
            with self.subTest(art=art):
                self.pruefe_streng(["App/ContentView.swift"], art=art)

    def test_normal_bleibt_vier(self):
        self.assertFalse(jury.streng(["App/ContentView.swift", "tools/maplibre/build_style.py"], "technik", CFG))

    def test_fuenf_von_fuenf_streng_angenommen(self):
        u, _ = befrage({}, dateien=["App/CarPlaySceneDelegate.swift"])
        self.assertTrue(u.angenommen)


class ImZweifelNein(unittest.TestCase):
    def test_ungueltiges_json(self):
        kaputt = claude_call.Ergebnis(ok=False, fehler="kein JSON in der Antwort")
        u, _ = befrage({"apple": kaputt, "recht": kaputt})
        self.assertFalse(u.angenommen)
        s = {s.rolle: s for s in u.stimmen}
        self.assertFalse(s["apple"].ja)
        self.assertFalse(s["apple"].gueltig)

    def test_zeitueberschreitung(self):
        zeit = claude_call.Ergebnis(ok=False, fehler="Zeitüberschreitung nach 900 s")
        u, _ = befrage({"technik": zeit, "carplay": zeit})
        self.assertFalse(u.angenommen)
        self.assertIn("Zeitüberschreitung", {s.rolle: s for s in u.stimmen}["technik"].hinweis)

    def test_keine_antwort(self):
        self.assertFalse(jury.werte("apple", None).ja)

    def test_falsches_schema_wird_nein(self):
        for daten in [{"stimme": "VIELLEICHT", "veto": False, "schwere": "niedrig", "gruende": ["a.swift:1"]},
                      {"stimme": "JA", "veto": "nein", "schwere": "niedrig", "gruende": ["a.swift:1"]},
                      {"stimme": "JA", "veto": False, "schwere": "egal", "gruende": ["a.swift:1"]},
                      {"stimme": "JA", "veto": False, "schwere": "niedrig", "gruende": []},
                      {"stimme": "JA", "veto": False, "schwere": "niedrig"},
                      ["JA"]]:
            with self.subTest(daten=daten):
                s = jury.werte("apple", claude_call.Ergebnis(ok=True, daten=daten))
                self.assertFalse(s.ja)
                self.assertFalse(s.gueltig)

    def test_ja_ohne_beweis_wird_nein(self):
        s = jury.werte("apple", antwort("JA", gruende=["sieht gut aus"]))
        self.assertFalse(s.ja)
        self.assertIn("ohne Beweis", s.hinweis)

    def test_ein_grund_ohne_beweis_reicht_fuer_nein(self):
        s = jury.werte("apple", antwort("JA", gruende=["App/A.swift:3 passt", "und überhaupt schön"]))
        self.assertFalse(s.ja)

    def test_zwei_ohne_beweis_kippen_mehrheit(self):
        leer = antwort("JA", gruende=["alles prima"])
        u, _ = befrage({"apple": leer, "fahrer": leer})
        self.assertFalse(u.angenommen)

    def test_beweisformen(self):
        for g in ["App/CarPlaySceneDelegate.swift:350 Label", "siehe docs/store/carplay/carplay-frei.png",
                  "Bild karte.jpg", ".autopilot/logs/build.log:12 error", "Core/Tests/x.swift:7", "ausgabe.txt"]:
            with self.subTest(g=g):
                self.assertTrue(jury.hat_beweis(g))
        for g in ["sieht gut aus", "Zeile 12", "App/ContentView.swift", "", None]:
            with self.subTest(g=g):
                self.assertFalse(jury.hat_beweis(g))


class Veto(unittest.TestCase):
    def test_veto_blocker_lehnt_trotz_mehrheit_ab(self):
        u, _ = befrage({"recht": antwort("JA", veto=True, schwere="blocker", gruende=["App/Fonts/x.otf:1 Lizenz"])})
        self.assertFalse(u.angenommen)
        self.assertEqual(u.veto_von, ["recht"])
        self.assertIn("Veto", u.zusammenfassung)

    def test_veto_ohne_blocker_zaehlt_nicht_als_veto(self):
        u, _ = befrage({"recht": antwort("NEIN", veto=True, schwere="hoch", gruende=["a.swift:1"])})
        self.assertTrue(u.angenommen)  # 4 von 5 JA, kein Blocker-Veto
        self.assertEqual(u.veto_von, [])

    def test_veto_eines_ungueltigen_jurors_zaehlt_nicht(self):
        kaputt = claude_call.Ergebnis(ok=True, daten={"stimme": "NEIN", "veto": True, "schwere": "blocker", "gruende": []})
        u, _ = befrage({"recht": kaputt})
        self.assertEqual(u.veto_von, [])  # ungültig → nur ein NEIN
        self.assertTrue(u.angenommen)


class Getrennt(unittest.TestCase):
    def test_fuenf_getrennte_aufrufe_ohne_fremde_stimmen(self):
        nein = antwort("NEIN", gruende=["GEHEIMER_GRUND in a.swift:1"])
        u, gesehen = befrage({"apple": nein})
        self.assertEqual([g[0] for g in gesehen], CFG["jury"]["rollen"])
        for rolle, prompt, _ in gesehen:
            self.assertNotIn("GEHEIMER_GRUND", prompt, f"{rolle} sieht die Stimme eines anderen")

    def test_jeder_rollentext_beginnt_streng(self):
        _, gesehen = befrage({})
        for rolle, prompt, _ in gesehen:
            self.assertTrue(prompt.startswith(jury.EINLEITUNG), rolle)

    def test_selbstbeschreibung_des_bauers_verboten(self):
        u = dict(UNTERLAGEN, Bauer="Ich habe alles perfekt gemacht")
        with self.assertRaises(ValueError):
            befrage({}, unterlagen=u)

    def test_nur_erlaubte_unterlagen_im_prompt(self):
        _, gesehen = befrage({})
        for _, prompt, _ in gesehen:
            for k in jury.ERLAUBTE_UNTERLAGEN:
                self.assertIn(f"## {k}", prompt)


class StufeA(unittest.TestCase):
    def test_zwei_durchlaeufe_mit_neuer_reihenfolge(self):
        _, gesehen = befrage({}, stufe="A")
        self.assertEqual(len(gesehen), 10)

        def reihenfolge(p):
            return [k for k in sorted(jury.ERLAUBTE_UNTERLAGEN, key=lambda k: p.index(f"## {k}"))]
        self.assertNotEqual(reihenfolge(gesehen[0][1]), reihenfolge(gesehen[5][1]))

    def test_beide_durchlaeufe_muessen_halten(self):
        zaehler = {"n": 0}
        nein = antwort("NEIN", gruende=["a.swift:1"])

        def aufrufer(rolle, prompt, name):
            zaehler["n"] += 1
            # zweiter Durchlauf: zwei Juroren sagen NEIN
            return nein if name.endswith("d2") and rolle in ("apple", "recht") else antwort()
        u = jury.befrage(UNTERLAGEN, dateien=["App/ContentView.swift"], art="technik", stufe="A", cfg=CFG,
                         aufrufer=aufrufer, zufall=random.Random(2))
        self.assertEqual(zaehler["n"], 10)
        self.assertFalse(u.angenommen)
        self.assertIn("Durchlauf 2", u.zusammenfassung)

    def test_stufe_b_nur_ein_durchlauf(self):
        _, gesehen = befrage({}, stufe="B")
        self.assertEqual(len(gesehen), 5)


class Wiederholung(unittest.TestCase):
    """claude_call: ungültiges JSON → bis zu 2 neue Versuche, danach ok=False (zählt in der Jury als NEIN)."""

    def lauf(self, ergebnisse):
        aufrufe = []

        class P:
            def __init__(self, stdout):
                self.stdout, self.stderr, self.returncode = stdout, "", 0

        def start(cmd, **kw):
            aufrufe.append(kw["input"])
            return P(ergebnisse[len(aufrufe) - 1])
        e = claude_call.aufruf("frage", modell="opus", werkzeuge=["Read"], zeitlimit=5, pruefe=jury.schema_fehler,
                               versuche=2, start=start)
        return e, aufrufe

    @staticmethod
    def huelle(text, dollar=0.1):
        import json
        return json.dumps({"type": "result", "result": text, "total_cost_usd": dollar, "session_id": "s"})

    def test_dritter_versuch_gueltig(self):
        gut = '{"stimme": "JA", "veto": false, "schwere": "niedrig", "gruende": ["a.swift:1"], "bedingungen": []}'
        e, aufrufe = self.lauf([self.huelle("weiß nicht"), self.huelle("{kaputt"), self.huelle("```json\n" + gut + "\n```")])
        self.assertTrue(e.ok)
        self.assertEqual(len(aufrufe), 3)
        self.assertIn("ungültig", aufrufe[1])
        self.assertAlmostEqual(e.dollar, 0.3)

    def test_nach_drei_fehlversuchen_nein(self):
        e, aufrufe = self.lauf([self.huelle("nein")] * 3)
        self.assertFalse(e.ok)
        self.assertEqual(len(aufrufe), 3)
        self.assertFalse(jury.werte("apple", e).ja)

    def test_zeitueberschreitung(self):
        import subprocess

        def start(cmd, **kw):
            raise subprocess.TimeoutExpired(cmd, 5)
        e = claude_call.aufruf("frage", modell="opus", werkzeuge=["Read"], zeitlimit=5, start=start)
        self.assertFalse(e.ok)
        self.assertIn("Zeitüberschreitung", e.fehler)

    def test_prompt_ueber_stdin_nicht_befehlszeile(self):
        gesehen = {}

        class P:
            stdout, stderr, returncode = self.huelle('{"a": 1}'), "", 0

        def start(cmd, **kw):
            gesehen["cmd"], gesehen["input"] = cmd, kw["input"]
            return P()
        claude_call.aufruf("GEHEIM", modell="opus", werkzeuge=["Read", "Grep"], zeitlimit=5, start=start)
        self.assertNotIn("GEHEIM", " ".join(gesehen["cmd"]))
        self.assertIn("GEHEIM", gesehen["input"])
        self.assertIn("Read,Grep", gesehen["cmd"])


if __name__ == "__main__":
    unittest.main()
