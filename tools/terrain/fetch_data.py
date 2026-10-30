"""GM-074: Rohdaten für die gemalten Frontier-Kacheln holen (Höhen + Bodenbedeckung).

Quellen (beide frei, auch kommerziell, Quellenhinweis Pflicht – steht in docs/FRONTIER_KACHELN.md):
- Copernicus DEM GLO-30 (30 m), AWS Open Data: 1°-Kacheln
- ESA WorldCover 2021 v200 (10 m, CC BY 4.0), AWS Open Data: 3°-Kacheln

Aufruf:  python tools/terrain/fetch_data.py test       → nur Taunus/Idstein (1 + 1 Datei, ~130 MB)
         python tools/terrain/fetch_data.py germany    → ganz Deutschland (~80 + 16 Dateien, mehrere GB)
Ziel: C:\\Users\\jonas\\EzMapsData (außerhalb von OneDrive und Repo, EZMAPS_DATA überschreibt das)
Vorhandene Dateien werden übersprungen, abgebrochene Downloads neu geholt.
"""
import os
import pathlib
import sys
import urllib.error
import urllib.request

DATA = pathlib.Path(os.environ.get("EZMAPS_DATA", pathlib.Path.home() / "EzMapsData"))
DEM_URL = "https://copernicus-dem-30m.s3.amazonaws.com/{n}/{n}.tif"
WC_URL = "https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/ESA_WorldCover_10m_2021_v200_{n}_Map.tif"

# Deutschland mit etwas Rand (Süd, Nord, West, Ost)
GERMANY = (47, 55, 5, 15)
TEST = (50, 51, 8, 9)   # Idstein, Taunus


def dem_name(lat, lon):
    return f"Copernicus_DSM_COG_10_N{lat:02d}_00_E{lon:03d}_00_DEM"


def wc_name(lat, lon):
    return f"N{lat:02d}E{lon:03d}"


def fetch(url, out):
    if out.exists() and out.stat().st_size > 0:
        return "da"
    tmp = out.with_suffix(".part")
    try:
        with urllib.request.urlopen(url, timeout=120) as r, open(tmp, "wb") as f:
            while chunk := r.read(1 << 20):
                f.write(chunk)
    except urllib.error.HTTPError as e:
        tmp.unlink(missing_ok=True)
        return f"fehlt ({e.code})"   # Meer: keine Kachel
    tmp.rename(out)
    return f"{out.stat().st_size // (1 << 20)} MB"


def main():
    s, n, w, e = TEST if (sys.argv[1:] or ["test"])[0] == "test" else GERMANY
    (DATA / "dem").mkdir(parents=True, exist_ok=True)
    (DATA / "worldcover").mkdir(parents=True, exist_ok=True)
    for lat in range(s, n):
        for lon in range(w, e):
            name = dem_name(lat, lon)
            print("Höhe", name, fetch(DEM_URL.format(n=name), DATA / "dem" / f"{name}.tif"), flush=True)
    for lat in range(s - s % 3, n, 3):
        for lon in range(w - w % 3, e, 3):
            name = wc_name(lat, lon)
            print("Boden", name, fetch(WC_URL.format(n=name), DATA / "worldcover" / f"{name}.tif"), flush=True)
    print("FERTIG", DATA)


if __name__ == "__main__":
    main()
