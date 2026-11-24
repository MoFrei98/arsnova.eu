# Labor Referat Thema 4 – nachprüfen und wiederholen

Labor zum Referat „Verlässlichkeit des Moderationskompasses“ (Cloud Computing, Thema 4A/4B/4C).
Untersucht wird arsnova.eu **Release 1.3 unverändert** (Tag `v1.3.0`, Commit `87c39334`); die
einzige Abweichung ist die eingeschaltete KI-Kurzfassung in
[`docker-compose.override.yml`](../docker-compose.override.yml).

## Was hier liegt

| Datei / Ordner | Inhalt |
| --- | --- |
| [laborprotokoll.md](laborprotokoll.md) | Alle Läufe mit Zeiten, Messwerten, Schwellen SW1–SW4 und Bewertung |
| [befund-kontextbudget.md](befund-kontextbudget.md) | Warum keine Frage bei der KI ankommt; Abgleich mit v1.4.0 |
| [4a-soll-ist-matrix.md](4a-soll-ist-matrix.md) | Soll/Ist der Fehlerfälle aus den 1.3-Verträgen |
| [referenzmanifest.md](referenzmanifest.md) | Hardware, Docker, Modell mit SHA-256, Runtime-Image, Flags |
| [rohdaten/](rohdaten/) | Reports, App- und KI-Logs, Zeitstempel, Screenshots je Phase |
| [setup-wsl.sh](setup-wsl.sh), [bootstrap-wsl.sh](bootstrap-wsl.sh) | Labor aufbauen |
| [probes/](probes/) | Messreihe (`messreihe.sh`), Host-Treiber (`handsession.mjs`), Budget- und Tokenize-Probe |

## Nachprüfen ohne Labor

Jede Zahl aus Handout und Folien steht im Laborprotokoll mit Verweis auf die Rohdaten. Zuordnung
der Ordner: `00-*` Aufbau und Smoke-Lauf, `01-baseline` Phase 1, `02-stoerung` Phase 2 (4A),
`03-erkennung` Phase 3 (4B), `04-aenderung` Phase 4 (4C), `05-eigene-laeufe` Läufe vom 20.11.
mit Screenshots, `budget` und `06-upstream-main` Budget- und Tokenize-Probe.

Die **Budget-Probe** ist deterministisch und läuft ohne Docker. Im Repo-Root eines Klons auf
`referat/thema-4`:

```bash
npm ci --ignore-scripts
npm run build -w @arsnova/shared-types
npx prisma generate            # nur falls tsx über den fehlenden Prisma-Client stolpert
npx tsx lab-thema4/probes/budget-probe.ts
git diff --stat lab-thema4/rohdaten/budget   # leer = dieselben Zahlen wie im Referat
```

## Labor wiederholen

**Voraussetzungen:** Windows mit WSL2 (Ubuntu 24.04 getestet) und Docker Desktop mit
WSL-Integration für diese Distribution. Die Skripte prüfen das und brechen auf reinem Linux oder
macOS ab. Internet für nvm, npm und den Modell-Download (2,5 GB), etwa 10 GB freier Platz.
Gemessen wurde auf einem Intel i7-14700, KI-Container mit 4 CPU-Kernen und 5 GB.

**Aufbau** (etwa 15–30 Minuten, je nach Download), in Ubuntu:

```bash
git clone --branch referat/thema-4 https://github.com/MoFrei98/arsnova.eu.git ~/arsnova.eu
cd ~/arsnova.eu
bash lab-thema4/bootstrap-wsl.sh
```

`bootstrap-wsl.sh` holt den Tag `v1.3.0`, `setup-wsl.sh` installiert Node über nvm, lädt und
prüft das Modell, legt zufällige Laborsecrets in der gitignorierten `.env` an und startet den Stack
nur auf `127.0.0.1`. Schritt 8 überschreibt `lab-thema4/referenzmanifest.md` mit den eigenen
Werten; `git diff lab-thema4/referenzmanifest.md` zeigt dann die Unterschiede zur Originalumgebung.

**Messreihe** (im Klon; ohne Laufwerk F: landen die Rohdaten in
`lab-thema4/rohdaten-wiederholung/`, ein anderes Ziel über `RAW_DIR=…`):

```bash
bash lab-thema4/probes/messreihe.sh phase1    # Baseline, ~6 min
bash lab-thema4/probes/messreihe.sh phase2    # Störungen 4A, ~6 min
bash lab-thema4/probes/messreihe.sh phase3    # Erkennung 4B, ~1 min
bash lab-thema4/probes/messreihe.sh phase4    # 30 s, Kill-Switch, Rückweg 4C, ~8 min
bash lab-thema4/probes/messreihe.sh phase4b   # C2b–C4 wiederholen, wartet ggf. bis zu 60 min
bash lab-thema4/probes/tokenize-probe.sh      # echte Qwen3-Tokens, Labor muss laufen
```

Die Phasen ändern die Konfiguration selbst und stellen am Ende von Phase 4 den Releasestand wieder
her. Labor anhalten mit `docker compose down` im Klon.

## Was gleich bleiben sollte und was nicht

- **Gleich, weil deterministisch:** 0 Fragen im Modellkontext (1.3-Profil mit 4.096 Tokens), die
  Fallback-Gründe je Störung (`timeout`, `unavailable`, `circuit_open`, `busy`, `disabled`), die
  vier Felder im Log `qa_summary:completed`, HTTP 200 auch bei Ausfall, unveränderte Lernziele.
- **Hardwareabhängig:** alle Zeiten. Auf einem schnelleren Rechner kann die KI bei 30 s öfter
  fertig werden als hier (1 von 10).

## Bekannte Laborartefakte

- Neue Sitzungen sind auf 10 pro Stunde und Adresse begrenzt. `phase4b` liest den Zähler aus
  Redis und wartet das Fenster ab; Phase 4 kann daran wie am 18.11. scheitern.
- Alle simulierten Teilnehmenden kommen von einer Adresse, deshalb lehnt das Rate-Limit in der
  Großlage eine Stimmrunde ab (3.250 statt 3.500 Stimmen).
- Der Host-Token läuft nach 15 Minuten ab; `handsession.mjs` erneuert ihn.
- Im Windows-Checkout auf `/mnt/…` nie `npm ci` aus WSL starten; das Labor läuft im WSL-Klon.

## Grenzen und Sicherheit

Nur lokal gegen `127.0.0.1`, nie gegen arsnova.eu. Synthetische Daten aus den Release-Fixtures
und Lastskripten. v1.4.0 wurde nicht im Labor gemessen. Skripte und automatisierte Läufe sind mit
Claude Code entstanden; siehe KI-Hinweis im [Laborprotokoll](laborprotokoll.md).
