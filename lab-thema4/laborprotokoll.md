# Laborprotokoll Referat Thema 4

Chronologisches Protokoll aller Schritte, Läufe und Messungen im lokalen Labor. Zeiten sind
Ortszeit (MEZ). 12.–16.11.: Aufbau, Smoke-Lauf und Proben. 18.11.: Messreihe nach der
Labor-Checkliste (Phasen 1–4), Ergebnisse im Abschnitt [Messreihe 18.11.](#messreihe-18112026).

**KI-Hinweis:** Die Schritte wurden, sofern nicht anders vermerkt, von Claude (Claude Code) auf
Anweisung von Morris ausgeführt und protokolliert. Von Morris selbst ausgeführt: Installation
von WSL und Docker Desktop, Annahme der Docker-Vereinbarung, Start des Stacks am 18.11.
(`setup-wsl.sh` um 13:51). **Die gesamte Messreihe vom 18.11. hat Claude per Skript ausgeführt**
(`messreihe.sh`, `handsession.mjs`); die Host- und Teilnehmeraktionen liefen über die tRPC-API,
nicht im Browser. Selbst wiederholt hat Morris bisher keinen Lauf.

Umgebung im Detail: [referenzmanifest.md](referenzmanifest.md). Befunde:
[4A-Matrix](4a-soll-ist-matrix.md), [Kontextbudget](befund-kontextbudget.md).

## Übersicht der Läufe

| Nr. | Zeit | Lauf | Ergebnis | Rohdaten |
| --- | --- | --- | --- | --- |
| A1 | 16.11. 14:01 | Bootstrap 1 | Abbruch in Schritt 5: `ERR_MODULE_NOT_FOUND @trpc/client` | [00-setup/bootstrap-20261116-1401.log](rohdaten/00-setup/bootstrap-20261116-1401.log) |
| A2 | 16.11. 14:02–14:15 | Bootstrap 2 | Images gebaut; App in Neustartschleife (fehlende Start-Secrets) | [00-setup/bootstrap-20261116-1402.log](rohdaten/00-setup/bootstrap-20261116-1402.log) |
| A3 | 16.11. 14:16 | Bootstrap 3 | alle 8 Schritte grün, App healthy um 14:16:46 | [00-setup/bootstrap-20261116-1416.log](rohdaten/00-setup/bootstrap-20261116-1416.log) |
| R0 | 16.11. 14:18:16–14:18:56 | Smoke-Lauf Referenzfall (kein Teil der Messreihe) | Summary `uncertain / extractive / timeout`, 0 Fragen im Kontext | [00-smoke/](rohdaten/00-smoke/) |
| P1 | 16.11. nach R0 | Budget-Probe (Release-Fixtures) | Sechs-Fragen-Fixture: 1 von 6 Fragen im 4.096er-Profil | [budget/budget-probe.json](rohdaten/budget/budget-probe.json) |
| P2 | 16.11. nach P1 | Tokenize-Probe (echte Qwen3-Tokens) | Schätzer überschätzt um Faktor 2,9–5,2 | [budget/tokenize-probe.tsv](rohdaten/budget/tokenize-probe.tsv) |
| B1-1..3 | 18.11. 14:08–14:13 | Baseline Großlage, 8 s | 3× `timeout` (8,76–8,86 s), 0 von 2.500 Fragen im Kontext | [01-baseline/](rohdaten/01-baseline/) |
| B2-1..3 | 18.11. 14:12–14:13 | Baseline Handsession (#456 §12), 8 s | `timeout`, danach 2× `busy`; 0 von 6 Fragen im Kontext | [01-baseline/handsession.jsonl](rohdaten/01-baseline/handsession.jsonl) |
| L0 | 18.11. 14:13 | Live-Last 30 TN ohne Störung | Submit-p95 175 ms, 90/90, 180/180 | [01-baseline/L0.json](rohdaten/01-baseline/L0.json) |
| B3 | 18.11. 14:14 | Zusatz: Slotfreigabe nach Timeout | nach ≤ 2,3 s wieder frei | [01-baseline/](rohdaten/01-baseline/) |
| S1-1..3 | 18.11. 14:15 | Runtime pausiert, 8 s | 3× `timeout` 8,21–8,34 s; Circuit bleibt zu | [02-stoerung/](rohdaten/02-stoerung/) |
| S2 | 18.11. 14:16 | Runtime gestoppt | 3× `unavailable` ≤ 0,79 s, dann `circuit_open` | [02-stoerung/](rohdaten/02-stoerung/) |
| S3-1..4 | 18.11. 14:16–14:20 | Slot belegt | S3-1 ungültig (`circuit_open`), S3-2..4 `busy` 0,33–0,34 s | [02-stoerung/](rohdaten/02-stoerung/) |
| E3-1..2 | 18.11. 14:20 | nur fachlich veraltet | `source_changed` beim nächsten Abruf, kein Logeintrag | [03-erkennung/](rohdaten/03-erkennung/) |
| C1 | 18.11. 14:21–14:27 | Variante 30 s | Großlage: 1 von 3 Läufen `full-context` (21,5 s); Handsession 3× `timeout` 30,1–30,2 s | [04-aenderung/](rohdaten/04-aenderung/) |
| C2a | 18.11. 14:27 | Wiederaufnahme nach Pause, 30 s | `timeout` während und nach der Pause | [04-aenderung/](rohdaten/04-aenderung/) |
| C2b, C3, C4 | 18.11. 14:27–14:29 | Stop, Kill-Switch, Rückweg | **ungültig**: Host-Token abgelaufen, Session-Create-Limit erreicht | [04-aenderung/](rohdaten/04-aenderung/) |
| C2b-W, C3-W, C4-W | 18.11. ab 15:00 | Wiederholung | siehe [Phase 4b](#phase-4b--wiederholung-c2b-c3-c4) | [04-aenderung/](rohdaten/04-aenderung/) |

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
- **A1 (14:01):** Abbruch in Schritt 5. Die Lastskripte laden `@trpc/client` und `ws` aus
  `node_modules`, die im frischen Klon fehlten. Der Lauf meldete trotzdem Exit-Code 0, weil die
  Ausgabe durch `tee` lief; spätere Läufe mit `pipefail`. Fix `86e13f08`: Schritt 4 führt im
  WSL-Klon `npm ci --ignore-scripts` aus (keine Hooks, kein Playwright-Download) und verweigert
  das auf `/mnt`.
- **A2 (14:02–14:15):** `npm ci` und Vorprüfung grün, Images `arsnovaeu-app` und
  `arsnova-open-weight-llm:llama-b10524` gebaut, Runtime, Postgres und Redis healthy. Die App
  startete in einer Schleife neu: Mit `NODE_ENV=production` verlangt das Backend beim Start
  `JWT_SECRET` (bzw. `YJS_SHARE_TOKEN_SECRET`) und `CAPABILITY_ENVELOPE_KEY_BASE64`
  (`apps/backend/src/index.ts:52–53`); `docker-compose.yml` am Release-Tag setzt beide nicht.
  Fix `2558c863`: Die Override-Datei verlangt beide aus der gitignorierten `.env`,
  `setup-wsl.sh` erzeugt dort Zufallswerte.
- **A3 (14:16):** alle 8 Schritte grün. `health.check` → `status: ok, redis: ok`. Im
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

## Schwellen der Messreihe (festgelegt am 18.11.2026 vor dem ersten Störlauf)

Übernommen aus den Vorschlägen der Labor-Checkliste (Schlachtplan, Tab „Labor-Checkliste“).
Es sind **eigene Prüfziele**, keine Release-SLOs; die Begründung im Handout steht noch aus.

| Kürzel | Kriterium | Schwelle |
| --- | --- | --- |
| SW1 | Fallback sichtbar nach Störungsbeginn | höchstens Queue-Timeout + 1 s; bei Prozessausfall höchstens 1 s |
| SW2 | Live-Pfade unter Störung | Q&A-p95 höchstens 20 % über L0, keine abgelehnten Beiträge oder Stimmen |
| SW3 | Wiederaufnahme | erster Lauf ohne Fallback höchstens 60 s nach „Runtime healthy“ |
| SW4 | Datenerhalt | Lernziele (count, revision) vor und nach dem Eingriff identisch |

Ablauf und Werkzeuge der Messreihe: `lab-thema4/probes/messreihe.sh` (Phasen der Checkliste)
und `lab-thema4/probes/handsession.mjs`. Die Handsession ist eine echte Q&A-Session mit den
sechs Referenzfragen aus #456 §12 (A–F) und zwei Upvotes, bedient über dieselbe tRPC-API wie
Host- und Teilnehmeransicht, statt per Hand im Browser. Abweichung von der Checkliste: sechs
statt fünf Fragen.

## Messreihe 18.11.2026

Stack von Morris um 13:51 mit `setup-wsl.sh` gestartet (Referenzmanifest neu erzeugt, Stand
`67479dd4`). Messreihe ab 14:08 von Claude mit `messreihe.sh` ausgeführt, Laborstand
`d9857d52` bis `ae95ba5c` (nur Werkzeuge und Rohdaten geändert). Zeitstempel jedes Eingriffs in
`rohdaten/<phase>/zeitstempel.txt`, jede Handsession-Antwort als JSON-Zeile in
`rohdaten/<phase>/handsession.jsonl`, App- und Runtime-Log je Lauf daneben.

### Phase 0 – Vorbereitung

- **V1** Helfer am Smoke-Lauf geprüft: `zeig` liefert exakt die Werte von R0 (8.764 ms,
  0 von 2.500, 3.066/4.096, p95 187 ms, 3.500/3.500).
- **V2** vier Container healthy; Flags `QA_SUMMARY_TIMEOUT_MS=8000`,
  `OPEN_WEIGHT_LLM_ENABLED=true`, `QA_SUMMARY_ENABLED=true`.
- **V3** Schwellen SW1–SW4 vor dem ersten Störlauf eingetragen und committet (`d9857d52`).
- **V4** Handsession um 14:12:57 per Skript angelegt (Code `JYLM4R`, sechs Fragen A–F, zwei
  Upvotes). Kontextvorschau: 6 zulässig, **0 im Kontext**, 0 Quellen, 3.173 von 4.096 gepackt,
  alle 6 Fragen wegen Token-Budget entfernt.

### Phase 1 – Baseline bei 8 s

| Lauf | Summary | Dauer | Kontext | Live | Bemerkung |
| --- | --- | ---: | --- | --- | --- |
| B1-1 | `uncertain / extractive / timeout` | 8.761 ms | 0 von 2.500, 0 Quellen | Q&A-p95 196 ms, Stimmen 3.250/3.500 | Stimmrunde Frage 10 komplett mit 429 abgelehnt |
| B1-2 | `uncertain / extractive / timeout` | 8.863 ms | 0 von 2.500, 0 Quellen | Q&A-p95 244 ms, Stimmen 3.250/3.500 | dito Frage 5 |
| B1-3 | `uncertain / extractive / timeout` | 8.783 ms | 0 von 2.500, 0 Quellen | Q&A-p95 230 ms, Stimmen 3.250/3.500 | dito Frage 3 |
| B2-1 | `uncertain / extractive / timeout` | 8.275 ms | 0 von 6, 0 Aussagen | – | Log `latencyMs: 7297` |
| B2-2 | `uncertain / extractive / busy` | 328 ms | – | – | 0,5 s nach B2-1 |
| B2-3 | `uncertain / extractive / busy` | 309 ms | – | – | 0,5 s nach B2-2 |
| L0 | – | – | – | Submit-p95 175 ms (max 203), 90/90 Fragen, 180/180 Stimmen | Bezugsgröße für SW2 |
| B3 (Zusatz) | `timeout`, dann 0,3 s später `busy`, rund 2,3 s später wieder ein normaler Versuch (`timeout`) | – | – | – | Slot nach Queue-Abbruch nach ≤ 2,3 s frei |

Lernziele in jeder Großlage `{"count":1,"revision":1}`. Runtime-Log je Abbruch
`stop: cancel task`. Das Abnahmeskript markiert B1-1..3 als `failed` (nur wegen der Stimmen).

**Abweichungen von der Erwartung der Checkliste:**
- B2 sollte extraktive Aussagen mit Quellen zeigen. Tatsächlich ist auch die Kurzfassung der
  kleinen Session leer: Der Metadaten-Rahmen belegt 3.173 der 3.328 verfügbaren Byte-Tokens,
  keine Frage passt hinein (gleicher Mechanismus wie im [Befund](befund-kontextbudget.md)).
- B2-2/B2-3 lieferten `busy` statt eines neuen Versuchs: Der Runtime-Slot ist direkt nach dem
  Queue-Abbruch noch belegt. Daraus entstand Zusatztest B3.
- Die abgelehnten Stimmen in B1 sind ein **Laborartefakt**: Rate-Limit `vote.submit` (Log:
  `rate_limit_429`, `category: 'vote'`, `ipSource: 'express-req-ip'`), weil alle 250 simulierten
  Teilnehmenden dieselbe Quelladresse haben. Im einzelnen Smoke-Lauf R0 trat es nicht auf. Für
  SW2 zählt deshalb die 30er-Live-Last (L-Läufe).
- Kein Baseline-Lauf erreichte einen echten Modelllauf. Entscheidung nach Phase 1 laut
  Checkliste: Störungen bei 8 s, Wiederaufnahme bei 30 s.

### Phase 2 – Störungen bei 8 s (4A)

| Lauf | Eingriff | Summary | Dauer | Danach |
| --- | --- | --- | ---: | --- |
| S1-1 | `docker pause`, Live-Last parallel | `timeout` | 8.208 ms | nach `unpause` sofort normaler Versuch (`timeout` 8.235 ms), nicht `busy`, nicht `circuit_open` |
| S1-2 | `docker pause` | `timeout` | 8.263 ms | dito (8.274 ms) |
| S1-3 | `docker pause` | `timeout` | 8.341 ms | dito (8.283 ms) |
| S2-1..3 | `docker stop`, Live-Last parallel | `unavailable` | 322 / 324 / 788 ms | – |
| S2-4 | (Runtime weiter gestoppt) | `circuit_open` | 306 ms | Runtime nach `docker start` in 6 s healthy |
| S3-1 | Slot per Direktaufruf belegt | `circuit_open` | 312 ms | **ungültig**: Breaker aus S2 noch offen (≈ 10 s nach dem dritten Fehler) |
| S3-2 | Slot belegt | `busy` | 334 ms | nach Freigabe sofort normaler Versuch (`timeout`) |
| S3-3 | Slot belegt | `busy` | 331 ms | dito |
| S3-4 | Slot belegt (Wiederholung) | `busy` | 337 ms | dito |

| Live-Last | Submit-p95 | max | Fragen | Stimmen |
| --- | ---: | ---: | --- | --- |
| L0 ohne Störung | 175 ms | 203 ms | 90/90 | 180/180 |
| L-S1 während Pause | 130 ms | 142 ms | 90/90 | 180/180 |
| L-S2 während Stop | 109 ms | 137 ms | 90/90 | 180/180 |

Jeder Fallback in Phase 2 hatte **0 Aussagen und 0 Quellen** und `retry: manual`. Im
Runtime-Log stehen die `cancel task`-Einträge der pausierten Aufträge erst nach `unpause`.

**Abweichungen von der Erwartung:** S1 sollte extraktive Aussagen mit Quellen zeigen – leer,
siehe B2. S3-1 traf den offenen Circuit Breaker: Die Runtime war 6 s nach dem Start gesund, der
Breaker blockierte aber bis zum Ende seiner 30 s weiter.

### Phase 3 – Erkennung (4B)

**E1 Erkennbarkeit aus dem App-Log** (`qa_summary:completed` enthält nur `status`,
`effectiveMode`, `fallbackReason`, `latencyMs`):

| Fall | Erwartet | Gesehen | Nur aus dem Log erkennbar? |
| --- | --- | --- | --- |
| Baseline B1/B2 | `timeout`, ≈ 8.300 ms | `timeout`, 7.297–8.348 ms | Fallback ja; dass die Kurzfassung leer ist: nein |
| S1 Pause | `timeout`, ≈ 8.000 ms | `timeout`, 8.033–8.051 ms | Fallback ja; Pause von zu langsamem Modell nicht unterscheidbar |
| S2 Stop | `unavailable`, wenige ms | `unavailable`, 43–49 ms | ja |
| S2 Circuit | `circuit_open`, wenige ms | `circuit_open`, 29 ms | ja |
| S3 Slot belegt | `busy`, wenige ms | `busy`, 33–43 ms | ja |
| E3 veraltet | kein Eintrag | kein Eintrag | nein |

**E2 HTTP-Status:** Jede Anforderung (`qa.requestSummary`) und jede Abfrage
(`qa.summaryRuntime`) lieferte HTTP 200, auch bei `timeout`, `unavailable`, `circuit_open`,
`busy` und `source_changed`. Gemessen im Treiber, nicht in den Browser-Entwicklertools.

**E3 nur fachlich veraltet:**

| Lauf | Vorher | Eingriff | Nächster Abruf `qa.summaryRuntime` | App-Log |
| --- | --- | --- | --- | --- |
| E3-1 | `timeout`, Hash `2dbe34fa4982…` | Upvote „Ist Kapitel 4 klausurrelevant?“ | `source_changed`, Hash `35bdf215ac1f…`, 37 ms | kein Eintrag |
| E3-2 | `timeout`, Hash `35bdf215ac1f…` | Upvote „Müssen wir den vierten Abschnitt …“ | `source_changed`, Hash `13e522dae8c9…`, 33 ms | kein Eintrag |

Die Erkennung funktioniert also auch, wenn keine Frage im Kontext ist (die Stimmen verändern
den Hash trotzdem). Wann die **Host-Ansicht** neu abruft, wurde nicht im Browser beobachtet. Laut
Code nur beim Laden der Session, beim Öffnen des Moderationskompasses und alle 750 ms, solange
das Ergebnis `pending` ist (`session-host.component.ts`, `refreshQaSummaryRuntime`,
`startQaSummaryPolling`). Eine Stimmenänderung löst keinen Abruf aus.

**E4 Kontextvorschau:** Großlage 0 von 2.500, 0 Quellen, 3.066/4.096 (B1-Reports); Handsession
mit inzwischen 16 Fragen 0 im Kontext, 0 Quellen, 3.181 gepackt, 16 wegen Token-Budget entfernt.
Nur die Vorschau zeigt, dass die Kurzfassung ohne Belege entsteht.

### Phase 4 – Änderung 8 s → 30 s, Wiederaufnahme, Kill-Switch, Rückweg (4C)

| Lauf | Konfiguration | Summary | Dauer | Bemerkung |
| --- | --- | --- | ---: | --- |
| C1-1 | 30 s | `uncertain / extractive / timeout` | 30.644 ms | Q&A-p95 231 ms |
| C1-2 | 30 s | **`uncertain / full-context`, kein Fallback** | 21.478 ms | erster echter Modelllauf; Log `latencyMs: 20194`; 0 Fragen im Kontext, daher `uncertain`; Q&A-p95 797 ms |
| C1-3 | 30 s | `uncertain / extractive / timeout` | 30.745 ms | Q&A-p95 832 ms |
| C1-H1..3 | 30 s, Handsession | `timeout` | 30.170 / 30.110 / 30.188 ms | 0 Aussagen |
| C2a | 30 s, Pause | `timeout` | 30.330 ms | nach `unpause`: wieder `timeout` (30.117 ms), Circuit zu |
| C2b | 30 s, Stop | 3× `unavailable` (304–316 ms), dann `circuit_open` | – | Runtime nach 6 s healthy; danach 2× `circuit_open`, dann **401** (Host-Token abgelaufen) → ungültig |
| C3 | Kill-Switch | – | – | **ungültig**: Großlage scheiterte am Session-Create-Limit, Handsession an 401 und am Fragenkontingent (10 je Teilnehmer) |
| C4 | Rückweg 8 s | – | – | **ungültig**: Session-Create-Limit; Flags wieder `8000 / true / true` |

Die Q&A-p95-Werte von C1-2/C1-3 (797/832 ms gegenüber 196–244 ms in B1) fallen auf; die Ursache
ist nicht untersucht.

**Laborartefakte, die C2b/C3/C4 ungültig machten:** (1) Das Host-Token läuft nach 15 min ab
(`HOST_SESSION_TTL_SECONDS`, Standard 900 s); die Host-Ansicht erneuert es alle 10 min, der
Treiber tat das nicht – seit `ae95ba5c` erneuert er es wie die Host-Ansicht. (2) Das Release
erlaubt 10 Session-Erstellungen pro Stunde und IP (`RATE_LIMIT_SESSION_CREATE_PER_HOUR`); im
Produktionsmodus gilt die Localhost-Ausnahme nicht. Wiederholung in Phase 4b im nächsten
Stundenfenster.

### Phase 4b – Wiederholung C2b, C3, C4

*Läuft ab 15:00:20; Ergebnisse werden nach dem Lauf eingetragen.*

### Bewertung gegen die Schwellen (Stand nach Phase 4)

| Schwelle | Messwerte | Ergebnis |
| --- | --- | --- |
| SW1 Fallback sichtbar | S1 8,21–8,34 s (≤ 9 s); S2 0,31–0,79 s (≤ 1 s); S3 0,33–0,34 s; C2a 30,33 s (≤ 31 s) | erfüllt |
| SW2 Live-Pfade | L-S1 130 ms, L-S2 109 ms gegen L0 175 ms (Grenze 210 ms); 0 abgelehnte Fragen oder Stimmen | erfüllt |
| SW3 Wiederaufnahme | siehe Phase 4b | offen |
| SW4 Datenerhalt | siehe Phase 4b | offen |

**Gesamtbefund bis hier:** Die Degradation ist technisch robust – jeder Fehler wird schnell und
typisiert gemeldet, die Live-Pfade bleiben unbeeinflusst, der Circuit Breaker verhält sich wie
spezifiziert. Fachlich liefert der Fallback in keinem einzigen Lauf Inhalt: Alle Kurzfassungen
der Messreihe hatten 0 Aussagen und 0 Quellen. Bei 8 s erreicht kein Lauf das Modell erfolgreich;
bei 30 s einer von sechs (C1-2), und auch er ist mangels Fragen im Kontext `uncertain`.

## Laborabweichungen

- **Fachlich:** `QA_SUMMARY_ENABLED=true` für den App-Container (Releasedefault `false`).
- **Betrieblich:** zufällige lokale `JWT_SECRET` und `CAPABILITY_ENVELOPE_KEY_BASE64` aus `.env`;
  `npm ci --ignore-scripts` nur im WSL-Klon für die Lastskripte; Docker-Daten auf C:.
- **Versionen:** Host-Node 24.18.0 (`.nvmrc`) für die Skripte; im App-Image meldet sich Node
  24.19.0 (`node:24-alpine` mit gepinntem Digest aus dem Release-Dockerfile).
- **Kontrollierte Variante der Messreihe:** `QA_SUMMARY_TIMEOUT_MS=30000` (Phase 4), danach
  Rückweg auf 8.000.
- **Nicht verändert:** Releasecode, Queue-, Cooldown- und Circuit-Werte, Modell, Runtime-Flags,
  Rate-Limits.

## Noch nicht gemessen / offen

- Phase 4b (Wiederaufnahme nach Stop bei 30 s, Kill-Switch, Rückweg) – läuft.
- Host-Ansicht im Browser: Zeitpunkt der Aktualisierung nach einer Stimmenänderung (E3) und
  HTTP-Status in den Entwicklertools (E2) nur per API bzw. Code belegt.
- Ursache der höheren Q&A-p95 in C1-2/C1-3.
- Die Runtime protokolliert keine Tokenzahlen und keine Prefill-Zeit.
- Kein Lauf von Morris selbst wiederholt.

## Evidenzorte

- Windows-Checkout `F:\arsnova.eu`, Branch `referat/thema-4` (gepusht nach
  `MoFrei98/arsnova.eu`): Konfiguration, Skripte, Befunde, dieses Protokoll, Rohdaten unter
  `lab-thema4/rohdaten/`.
- WSL-Klon `~/arsnova.eu` (Ubuntu-24.04): Laborlauf. `.env` mit Laborsecrets bleibt lokal und
  ist gitignoriert.
- Laborcommits: `bb4678e3`, `04fd6fcc`, `ba2909d5`, `86e13f08`, `2558c863`, `5c59f0dd` und der
  Commit dieses Protokolls.
