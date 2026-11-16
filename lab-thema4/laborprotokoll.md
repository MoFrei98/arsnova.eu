# Laborprotokoll Referat Thema 4

Chronologisches Protokoll aller Schritte, Läufe und Messungen im lokalen Labor. Zeiten sind
Ortszeit (MEZ). Die Messreihe (Baseline 3×, Störungen, Rückweg) hat **noch nicht begonnen**;
alles hier ist Aufbau, Smoke-Lauf oder Code-/Fixture-Probe.

**KI-Hinweis:** Die Schritte wurden, sofern nicht anders vermerkt, von Claude (Claude Code) auf
Anweisung von Morris ausgeführt und protokolliert. Von Morris selbst ausgeführt: Installation
von WSL und Docker Desktop, Annahme der Docker-Vereinbarung.

Umgebung im Detail: [referenzmanifest.md](referenzmanifest.md). Befunde:
[4A-Matrix](4a-soll-ist-matrix.md), [Kontextbudget](befund-kontextbudget.md).

## Übersicht der Läufe

| Nr. | Zeit (16.11.) | Lauf | Ergebnis | Rohdaten |
| --- | --- | --- | --- | --- |
| S1 | 14:01 | Bootstrap 1 | Abbruch in Schritt 5: `ERR_MODULE_NOT_FOUND @trpc/client` | [00-setup/bootstrap-20261116-1401.log](rohdaten/00-setup/bootstrap-20261116-1401.log) |
| S2 | 14:02–14:15 | Bootstrap 2 | Images gebaut; App in Neustartschleife (fehlende Start-Secrets) | [00-setup/bootstrap-20261116-1402.log](rohdaten/00-setup/bootstrap-20261116-1402.log) |
| S3 | 14:16 | Bootstrap 3 | alle 8 Schritte grün, App healthy um 14:16:46 | [00-setup/bootstrap-20261116-1416.log](rohdaten/00-setup/bootstrap-20261116-1416.log) |
| R0 | 14:18:16–14:18:56 | Smoke-Lauf Referenzfall (kein Teil der Messreihe) | Summary `uncertain / extractive / timeout`, 0 Fragen im Kontext | [00-smoke/](rohdaten/00-smoke/) |
| P1 | nach R0 | Budget-Probe (Release-Fixtures) | Sechs-Fragen-Fixture: 1 von 6 Fragen im 4.096er-Profil | [budget/budget-probe.json](rohdaten/budget/budget-probe.json) |
| P2 | nach P1 | Tokenize-Probe (echte Qwen3-Tokens) | Schätzer überschätzt um Faktor 2,9–5,2 | [budget/tokenize-probe.tsv](rohdaten/budget/tokenize-probe.tsv) |

## Chronik

### 12.11.2026 – Repository und Grundlagen

- Fork `MoFrei98/arsnova.eu` nach `F:\arsnova.eu` geklont, Remote `upstream` =
  `kqc-real/arsnova.eu`, Tags von dort geholt. Der Fork hatte keine Tags und stand vor 1.3.
- Branch `referat/thema-4` auf `v1.3.0` (`87c39334`) angelegt.
- Git für Windows hatte alle Dateien mit CRLF ausgecheckt (`core.autocrlf=true` systemweit).
  Repo-lokal auf `core.autocrlf=false`, `core.eol=lf` gestellt und neu ausgecheckt; danach 0
  Dateien mit CRLF. Grund: `docker/open-weight-llm/entrypoint.sh` wäre im Container gescheitert.
- Modell `Qwen3-4B-Instruct-2507-Q4_K_M.gguf` von der gepinnten Hugging-Face-Revision geladen
  (2.497.281.120 Byte) und mit `scripts/open-weight-llm/verify-model.mjs` gegen das Manifest
  geprüft (SHA-256 `3605803b…c67e597`).
- WebStorm hatte auf Windows `npm install` ausgeführt; npm 10 entfernte dabei `libc`-Felder aus
  `package-lock.json`. Datei auf den Release-Stand zurückgesetzt.
- Plan-B-Tests ohne Modell auf Windows (Node 22.12, nach `prisma:generate` und `build:libs`):
  `qaSummaryQueue.test.ts`, `openWeightLlmClient.test.ts`, `qaSummaryConfig.test.ts` →
  3 Dateien, **64 von 64 Tests bestanden**.
- Laborkonfiguration angelegt und committet (`bb4678e3`): `docker-compose.override.yml`
  (`QA_SUMMARY_ENABLED=true`, Durchreichen von `QA_SUMMARY_TIMEOUT_MS`) und
  `lab-thema4/setup-wsl.sh`.
- Pre-commit-Hook des Repos (Typecheck + komplette Testsuite) auf Windows nicht lauffähig:
  zuerst fehlte der Playwright-Browser (nachinstalliert, 114,5 MiB), danach scheiterten 14
  Backend-Tests an Unix-Sockets und Symlinks. Laborcommits deshalb mit `--no-verify`
  (Freigabe durch Morris für reine Laborcommits auf diesem Branch).

### 16.11.2026 – Labor aufgebaut, erster Lauf, Befund

- Modell auf F: erneut geprüft: Prüfsumme unverändert.
- `setup-wsl.sh` korrigiert: Die Prüfung verlangte exakt den Commit `v1.3.0` und hätte am
  eigenen Laborcommit abgebrochen. Jetzt: `v1.3.0` muss Vorfahre sein, über `v1.3.0` hinaus
  dürfen nur `docker-compose.override.yml` und `lab-thema4/` geändert sein. Dazu
  `bootstrap-wsl.sh` für den Klon ins WSL-Dateisystem (`04fd6fcc`).
- Entwurf der 4A-Soll-/Ist-Matrix aus dem Code (`ba2909d5`).
- Morris installiert WSL 3.0.5 mit `Ubuntu-24.04` unter `F:\WSL\Ubuntu-24.04` und Docker
  Desktop 4.99 (Benutzerinstallation) und nimmt die Docker-Vereinbarung an.
- Docker war in Ubuntu nicht verfügbar, weil die WSL-Integration aus war. Claude stoppt Docker
  Desktop, trägt `Ubuntu-24.04` in `%APPDATA%\Docker\settings-store.json` ein (Sicherung
  `settings-store.json.bak-before-wsl-integration`) und startet neu. Danach in Ubuntu: Docker
  29.9.3, Compose 5.7.0, 28 CPUs, 15,5 GiB RAM. Docker-Daten liegen weiter auf C: (Standard).
- Vorbereitung im WSL-Klon `~/arsnova.eu`: Branch `referat/thema-4`, Tag `v1.3.0` von
  upstream, Modell von F: kopiert und per SHA-256 geprüft, Node 24.18.0 über nvm.
- **S1 (14:01):** Abbruch in Schritt 5. Die Lastskripte laden `@trpc/client` und `ws` aus
  `node_modules`, die im frischen Klon fehlten. Der Lauf meldete trotzdem Exit-Code 0, weil die
  Ausgabe durch `tee` lief; spätere Läufe mit `pipefail`. Fix `86e13f08`: Schritt 4 führt im
  WSL-Klon `npm ci --ignore-scripts` aus (keine Hooks, kein Playwright-Download) und verweigert
  das auf `/mnt`.
- **S2 (14:02–14:15):** `npm ci` und Vorprüfung grün, Images `arsnovaeu-app` und
  `arsnova-open-weight-llm:llama-b10524` gebaut, Runtime, Postgres und Redis healthy. Die App
  startete in einer Schleife neu: Mit `NODE_ENV=production` verlangt das Backend beim Start
  `JWT_SECRET` (bzw. `YJS_SHARE_TOKEN_SECRET`) und `CAPABILITY_ENVELOPE_KEY_BASE64`
  (`apps/backend/src/index.ts:52–53`); `docker-compose.yml` am Release-Tag setzt beide nicht.
  Fix `2558c863`: Die Override-Datei verlangt beide aus der gitignorierten `.env`,
  `setup-wsl.sh` erzeugt dort Zufallswerte.
- **S3 (14:16):** alle 8 Schritte grün. `health.check` → `status: ok, redis: ok`. Im
  App-Container: `QA_SUMMARY_ENABLED=true`, `OPEN_WEIGHT_LLM_ENABLED=true`,
  `QA_SUMMARY_TIMEOUT_MS=8000`. Referenzmanifest geschrieben.
- **R0 Smoke-Lauf (14:18:16–14:18:56):** `node scripts/load/issue-456-demo-acceptance.mjs --run`
  mit `REPORT_FILE`. Kein Teil der Messreihe, keine Störung. Ergebnisse siehe unten.
- **P1/P2 Proben:** `lab-thema4/probes/budget-probe.ts` (Windows-Checkout) und
  `lab-thema4/probes/tokenize-probe.sh` (WSL, gegen die laufende Runtime). Ergebnisse siehe
  unten und im [Befund](befund-kontextbudget.md). Commit `5c59f0dd`.
- Schlachtplan aktualisiert: Referenzfall korrekt benannt (Slice-8-Abnahme statt
  Sechs-Fragen-Szenario), Abschnitt „Zwischenbefunde“, Hypothesen bewusst unverändert.

## Messwerte bisher

### R0 Smoke-Lauf – Slice-8-Abnahme aus #456

Szenario: kanonisches Demo-Quiz (13 Fragen, 10 Fragetypen), 250 Teilnehmende, je 10
Q&A-Beiträge = 2.500 Beiträge aus 50 verschiedenen Texten; Ziel `http://127.0.0.1:3000`;
ein lokaler Runner mit gemeinsamer Quelladresse. Gesamtdauer 39,4 s.

| Größe | Wert |
| --- | --- |
| Q&A-Einreichungen | 2.500 / 2.500 angenommen, p50 15 ms, p95 187 ms, max 451 ms |
| Stimmen | 3.500 / 3.500 angenommen in 14 Runden, p95 je Runde 401–700 ms, max 711 ms |
| Blitzlicht (TEMPO) | 250 / 250, p95 23 ms |
| Hotpath-Lesezugriffe | 25 / 25, p50 16 ms, p95 17 ms |
| Summary angefordert → Ergebnis | Enqueue 153 ms, gesamt 8.764 ms |
| Summary-Ergebnis | `status: uncertain`, `effectiveMode: extractive`, `fallbackReason: timeout` |
| Log `qa_summary:completed` | `latencyMs: 8321` |
| Runtime-Log | `stop: cancel task, id_task = 1` (Abbruch angekommen, Slot frei) |
| Kontextvorschau, Fragen | 2.500 zulässig → 200 analysiert → 150 Duplikate → 50 wegen Token-Budget entfernt → **0 im Kontext** |
| Kontextvorschau, Budget | 3.066 von 4.096 gepackt, 640 Antwort, 128 Sicherheit; Quellen: **0** |
| Assertion des Abnahmeskripts | `scenario: passed` – **trotz leerer Kurzfassung** |

### P1/P2 Budget- und Tokenize-Probe

| Eingabe | Bytes = Schätzer-Tokens | Qwen3-Tokens | Bytes/Token |
| --- | ---: | ---: | ---: |
| Instruktion | 314 | 60 | 5,23 |
| Definitionen | 203 | 41 | 4,95 |
| Minimal-Fixture, gepackt (1 Frage) | 2.761 | 702 | 3,93 |
| Sechs-Fragen-Fixture, gepackt im 4.096er-Profil (1 von 6 Fragen) | 2.621 | 674 | 3,89 |
| Sechs-Fragen-Fixture, voller Kontext ohne Fenstergrenze (12 Quellen) | 12.130 | 4.153 | 2,92 |

## Laborabweichungen

- **Fachlich:** `QA_SUMMARY_ENABLED=true` für den App-Container (Releasedefault `false`).
- **Betrieblich:** zufällige lokale `JWT_SECRET` und `CAPABILITY_ENVELOPE_KEY_BASE64` aus `.env`;
  `npm ci --ignore-scripts` nur im WSL-Klon für die Lastskripte; Docker-Daten auf C:.
- **Versionen:** Host-Node 24.18.0 (`.nvmrc`) für die Skripte; im App-Image meldet sich Node
  24.19.0 (`node:24-alpine` mit gepinntem Digest aus dem Release-Dockerfile).
- **Nicht verändert:** Releasecode, Timeouts, Queue-, Cooldown- und Circuit-Werte, Modell,
  Runtime-Flags.

## Noch nicht gemessen / offen

- Messreihe: Baseline 3×, Störungen (Timeout, Prozessausfall, belegter Slot), Rückweg,
  Kill-Switch. Bisher 0 Läufe der Messreihe.
- Referenzfall noch nicht festgelegt: Großlage (Slice-8-Abnahme), eigener Fall mit sechs Fragen
  oder beide.
- Die Runtime protokolliert keine Tokenzahlen und keine Prefill-Zeit. Wie lange das Modell für
  eine vollständige Antwort bräuchte, ist offen (Kandidat: Timeout-Variante 30 s).
- Schwellen für die Messreihe sind noch nicht festgelegt.

## Evidenzorte

- Windows-Checkout `F:\arsnova.eu`, Branch `referat/thema-4` (gepusht nach
  `MoFrei98/arsnova.eu`): Konfiguration, Skripte, Befunde, dieses Protokoll, Rohdaten unter
  `lab-thema4/rohdaten/`.
- WSL-Klon `~/arsnova.eu` (Ubuntu-24.04): Laborlauf. `.env` mit Laborsecrets bleibt lokal und
  ist gitignoriert.
- Laborcommits: `bb4678e3`, `04fd6fcc`, `ba2909d5`, `86e13f08`, `2558c863`, `5c59f0dd` und der
  Commit dieses Protokolls.
