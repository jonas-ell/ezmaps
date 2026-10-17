# Mac für EzMaps einrichten (einmalig)

Jedes Projekt bekommt einen **eigenen** SSH-Schlüssel, der auf dem Mac nur fünf Befehle darf
(`ping`, `clean`, `extract`, `build`, `log`). So kann ein Build für EzMaps nie die andere App überschreiben.

## Schon erledigt (Windows-PC)

- Schlüssel `~/.ssh/ezmaps_mac` erzeugt (der private Teil bleibt auf dem PC).
- Eintrag `mac-ezmaps` in `~/.ssh/config` (Adresse `100.102.233.78`, Benutzer `jonaselfounti`).
- Build-Skript `tools/mac_build.sh` (läuft auf dem Mac) und `tools/mac_run.sh` (startet alles vom PC).

## Auf dem Mac (Terminal) – einmal einfügen und Enter

```bash
mkdir -p ~/bin ~/Projekte/ezmaps
cat > ~/bin/ezmaps-gate.sh <<'GATE'
#!/bin/bash
# Gate für EzMaps: nur fünf feste Befehle.
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
DIR="$HOME/Projekte/ezmaps"
LOG=/tmp/ezmaps_build.log
mkdir -p "$DIR"
case "${SSH_ORIGINAL_COMMAND:-}" in
  ping)    echo ok ;;
  clean)   find "$DIR" -mindepth 1 -maxdepth 1 ! -name build -exec rm -rf {} + && echo cleaned ;;
  extract) tar -xf - -C "$DIR" && echo extracted ;;
  build)   cd "$DIR" && bash tools/mac_build.sh 2>&1 | tee "$LOG" ;;
  log)     tail -n 80 "$LOG" ;;
  *)       echo "Nicht erlaubt: ${SSH_ORIGINAL_COMMAND:-}"; exit 1 ;;
esac
GATE
chmod +x ~/bin/ezmaps-gate.sh
echo 'command="/Users/jonaselfounti/bin/ezmaps-gate.sh",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEsyUv/0s5sMt8ueisdC/+gH90DG76NuoUr5cQ3mx904 ezmaps gate' >> ~/.ssh/authorized_keys
command -v xcodegen || echo "xcodegen fehlt: brew install xcodegen"
```

Der lange Text `ssh-ed25519 AAAA…` ist der **öffentliche** Schlüssel – unbedenklich.

## Test (Windows, Git Bash)

```bash
ssh mac-ezmaps ping      # muss „ok“ ausgeben
ssh mac-ezmaps ls        # muss „Nicht erlaubt: ls“ ausgeben
bash tools/mac_run.sh    # schickt den letzten Commit und baut
```

## Wenn etwas nicht geht

| Meldung | Ursache |
|---|---|
| `Permission denied (publickey …)` | Zeile nicht in `~/.ssh/authorized_keys` oder Tippfehler |
| Zeitüberschreitung | Mac schläft oder Tailscale aus |
| `xcodegen: command not found` | `brew install xcodegen`, ggf. Pfad im Gate anpassen |
| Erster Build dauert lange | MapLibre (ca. 10 MB) wird von GitHub geladen |
