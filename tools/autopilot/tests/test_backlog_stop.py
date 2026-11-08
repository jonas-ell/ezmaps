"""Backlog-Reihenfolge, GM-Nummer, STOP und Tagesgrenzen (docs/AUTOPILOT_PLAN.md 1.5, 3, 5, 8)."""
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import backlog  # noqa: E402
import basis  # noqa: E402

GRENZEN = {"runden_pro_tag": 5, "dollar_pro_tag": 25.0, "stunden_pro_tag": 6.0}


class Reihenfolge(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.b = backlog.Backlog(pathlib.Path(self.tmp.name) / "b.json")

    def tearDown(self):
        self.tmp.cleanup()

    def neu(self, titel, stufe, erstellt):
        return self.b.hinzufuegen(titel, stufe, ["App/A.swift:1"], erstellt=erstellt)

    def test_hoechste_stufe_zuerst(self):
        self.neu("c", "C", "2026-01-01")
        self.neu("a", "A", "2026-01-03")
        self.neu("b", "B", "2026-01-02")
        self.assertEqual(self.b.naechste().titel, "a")

    def test_gleiche_stufe_aelteste_zuerst(self):
        self.neu("neu", "B", "2026-01-05")
        self.neu("alt", "B", "2026-01-01")
        self.assertEqual(self.b.naechste().titel, "alt")

    def test_d_erst_wenn_a_bis_c_leer(self):
        self.neu("d", "D", "2026-01-01")
        c = self.neu("c", "C", "2026-01-09")
        self.assertEqual(self.b.naechste().titel, "c")
        c.status = "erledigt"
        self.assertEqual(self.b.naechste().titel, "d")

    def test_e_nie(self):
        self.neu("idee", "E", "2026-01-01")
        self.assertIsNone(self.b.naechste())

    def test_nur_offene(self):
        a = self.neu("a", "A", "2026-01-01")
        a.status = "blockiert"
        self.assertIsNone(self.b.naechste())

    def test_ohne_beweis_verworfen(self):
        self.assertIsNone(self.b.hinzufuegen("x", "A", []))
        self.assertIsNone(self.b.hinzufuegen("x", "A", ["  "]))
        self.assertIsNone(self.b.hinzufuegen("x", "Z", ["a.swift:1"]))
        self.assertEqual(self.b.aufgaben, [])

    def test_kein_doppelter_titel(self):
        self.neu("gleich", "B", "2026-01-01")
        self.assertIsNone(self.neu("gleich", "B", "2026-01-02"))

    def test_speichern_und_laden(self):
        self.neu("a", "A", "2026-01-01")
        self.b.speichern()
        b2 = backlog.Backlog(self.b.datei)
        self.assertEqual(b2.aufgaben[0].titel, "a")
        self.assertEqual(b2.aufgaben[0].id, "T001")


class GmNummer(unittest.TestCase):
    def test_hoechste_plus_eins(self):
        text = "# Changelog\n\n## GM-097 – a\n\n## GM-096 – b\n\n## GM-099 – Nachzügler\n"
        self.assertEqual(backlog.naechste_gm(text), "GM-100")

    def test_nur_ueberschriften_zaehlen(self):
        self.assertEqual(backlog.naechste_gm("## GM-005 – x\nsiehe GM-900 im Text\n"), "GM-006")

    def test_leer(self):
        self.assertEqual(backlog.naechste_gm(""), "GM-001")


class NotAus(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = pathlib.Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_stop_datei(self):
        konto = basis.Tageskonto(self.d / "k.json", tag="2026-01-01")
        stop = self.d / "STOP"
        self.assertIsNone(basis.darf_laufen(konto, GRENZEN, stop))
        stop.write_text("")
        self.assertEqual(basis.darf_laufen(konto, GRENZEN, stop), "STOP-Datei liegt vor")

    def test_tagesgrenzen(self):
        stop = self.d / "STOP"
        for buchung, wort in [({"runden": 5}, "Runden"), ({"dollar": 25.0}, "Kosten"), ({"sekunden": 6 * 3600}, "Zeit")]:
            with self.subTest(wort=wort):
                konto = basis.Tageskonto(self.d / f"{wort}.json", tag="2026-01-01")
                konto.buchen(**buchung)
                self.assertIn(wort, basis.darf_laufen(konto, GRENZEN, stop))

    def test_neuer_tag_neues_konto(self):
        k = basis.Tageskonto(self.d / "k.json", tag="2026-01-01")
        k.buchen(runden=5)
        k2 = basis.Tageskonto(self.d / "k.json", tag="2026-01-02")
        self.assertIsNone(k2.grenze_erreicht(GRENZEN))

    def test_stop_ist_gitignored(self):
        gi = (basis.REPO / ".gitignore").read_text(encoding="utf-8")
        self.assertIn("tools/autopilot/STOP", gi)
        self.assertIn(".autopilot/", gi)


if __name__ == "__main__":
    unittest.main()
