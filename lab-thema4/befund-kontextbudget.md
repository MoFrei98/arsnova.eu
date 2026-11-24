# Befund: Leere Kurzfassung durch das 4.096er-Kontextbudget (v1.3.0)

> **Status: Zwischenbefund, KI-gestützt (Claude) am 16.11.2026.** Grundlage: ein Smoke-Lauf
> im lokalen Labor (kein Teil der Messreihe), zwei deterministische Prüfskripte und Code-Lektüre
> am Tag `v1.3.0`. Vor der Verwendung im Handout selbst reproduzieren und in der Messreihe
> wiederholen. Gehört in die KI-Offenlegung.

## Beobachtung (Smoke-Lauf 16.11.2026, 14:18)

`npm run load:issue-456:run` im WSL-Labor (Slice-8-Abnahme: 250 Teilnehmende, 2.500
Q&A-Beiträge aus 50 verschiedenen Texten). Rohdaten im WSL-Klon unter
`~/arsnova.eu/lab-thema4/rohdaten/00-smoke/`.

| Größe | Wert |
| --- | --- |
| Summary-Ergebnis | `status: uncertain`, `effectiveMode: extractive`, `fallbackReason: timeout` |
| Latenz laut Log `qa_summary:completed` | 8.321 ms (Gesamtdauer im Report 8.764 ms) |
| Runtime | Auftrag angekommen, nach Queue-Abbruch `stop: cancel task` (Slot frei) |
| Fragenkorpus in der Kontextvorschau | 2.500 zulässig → 200 analysiert → 150 Duplikate entfernt → 50 wegen Token-Budget entfernt → **0 im Kontext** |
| Quellen im gepackten Kontext | **0** |
| Budget | 3.066 von 4.096 gepackt, 640 Antwortreserve, 128 Sicherheitsreserve, also 262 frei |
| Live-Pfade parallel | Q&A-Submit p95 187 ms, 3.500/3.500 Stimmen, Hotpath-Lesen p95 17 ms |

Der Host sieht damit eine Kurzfassung ohne Aussagen und ohne Belege, obwohl formal ein
extraktiver Fallback greift.

## Ursachenkette im Code

1. **Konservativer Schätzer.** Der Packer zählt jedes UTF-8-Byte als ein Token
   ([moderationPromptContextPacking.ts:146–153](../apps/backend/src/lib/moderationPromptContextPacking.ts#L146)).
   Der Code nennt das ausdrücklich „deliberately conservative“ und verweist auf eine spätere
   Messung mit dem echten Tokenizer.
2. **Festes Profil.** 4.096 Fenster − 640 Antwort − 128 Sicherheit = 3.328 Byte-Tokens für die
   Eingabe. Davon sind 517 fest durch Instruktion (314) und Definitionen (203)
   ([moderationSummaryContext.ts:44–57](../apps/backend/src/lib/moderationSummaryContext.ts#L44)).
3. **Gierige Auswahl.** Eine Frage kommt nur hinein, wenn der gesamte Kontext danach noch ins
   Budget passt ([moderationPromptContextPacking.ts:1035–1057](../apps/backend/src/lib/moderationPromptContextPacking.ts#L1035)).
   In der Großlage belegt schon der Metadaten-Rahmen ohne Frage 3.066; die verbleibenden 262
   reichen für keine einzige Frage samt Metadaten.
4. **Rückfall greift zu spät.** Auf die schlanke Q&A-Textbaseline wird nur gewechselt, wenn
   schon der Metadaten-Rahmen allein nicht passt
   ([moderationSummaryContext.ts:254–277](../apps/backend/src/lib/moderationSummaryContext.ts#L254)).
   Passt der Rahmen knapp, bleibt es beim reichhaltigen Kontext – auch mit 0 Fragen.
5. **Fallback aus derselben Quelle.** Der extraktive Fallback baut seine Aussagen aus genau
   diesem gepackten Quellenregister. Ist es leer, entsteht `uncertain` ohne Aussagen
   ([qaSummaryExtractive.ts:90–115](../apps/backend/src/lib/qaSummaryExtractive.ts#L90)).
6. **Unabhängig davon:** Der Modelllauf erreicht die 8-s-Grenze der Queue nicht.

## Messung: Byte-Schätzung gegen echte Qwen3-Tokens

`lab-thema4/probes/budget-probe.ts` packt die Release-Fixtures aus `shared-types` mit dem
Summary-Profil; `lab-thema4/probes/tokenize-probe.sh` zählt dieselben Texte mit dem
`/tokenize`-Endpunkt der laufenden Runtime (llama.cpp b10524, Qwen3-4B-Instruct-2507).
Rohdaten: [rohdaten/budget/](rohdaten/budget/).

| Eingabe | Bytes (Schätzer) | Qwen-Tokens | Bytes/Token |
| --- | ---: | ---: | ---: |
| Instruktion | 314 | 60 | 5,23 |
| Definitionen | 203 | 41 | 4,95 |
| Sechs-Fragen-Fixture, gepackt im 4.096er-Profil (1 von 6 Fragen) | 2.621 | 674 | 3,89 |
| Sechs-Fragen-Fixture, voller Kontext ohne Fenstergrenze (12 Quellen) | 12.130 | 4.153 | 2,92 |

Daraus folgt:

- Im 4.096er-Profil belegt die tatsächlich gepackte Eingabe real nur rund 775 Tokens
  (674 + 60 + 41, ohne Chat-Template). Rund 2.500 reale Tokens des Fensters bleiben neben der
  Antwortreserve ungenutzt.
- Der **volle** #456-Kontext schon für sechs Fragen hätte real 4.153 Tokens und passt damit
  auch bei exakter Zählung nicht in ein 4.096er-Fenster. Der Schätzer ist also nicht die
  einzige Grenze; das Fenster ist für den reichhaltigen Kontext zu klein.
- Der Release-Test dokumentiert das Abschneiden für das Fixture bewusst („degradiert einen zu
  großen Metadaten-Basiskontext sichtbar auf die Q&A-Textbaseline“, eine von sechs Fragen,
  [moderationSummaryContext.test.ts:63–76](../apps/backend/src/lib/moderationSummaryContext.test.ts#L63)).
  Der Fall „Rahmen passt, aber keine Frage“ ist dort nicht abgedeckt.

## Einordnung für das Referat

- **4A (Degradation):** Soll laut ADR-0035 §2.5: „quellengebundene extraktive Belege mit
  typisiertem Fallback, nicht leere Karte“. In der Großlage verfehlt: Der Fallback ist da, aber
  leer. Kein Datenverlust, Live-Pfade unbeeinflusst.
- **4B (Beobachtbarkeit):** Das Log zeigt `uncertain / extractive / timeout`, aber nicht, dass
  der Kontext 0 Fragen enthielt. Sichtbar ist das nur in der hostgeschützten Kontextvorschau
  (`represented: 0`, `sourceCount: 0`) – ein gutes Beispiel für Diagnose jenseits von
  HTTP-Erfolg.
- **4C (kontrollierte Änderung):** Kandidaten für genau eine Änderung gegenüber der Baseline,
  jeweils mit Rückweg: Timeout 8 s → 30 s (zeigt, ob das Modell überhaupt fertig wird);
  Rückfall auf die Textbaseline auch bei 0 repräsentierten Fragen; kalibrierter statt
  byteweiser Schätzer. Nur eine davon wählen.

## Gültigkeitsgrenzen

- Ein Smoke-Lauf, eine Lastform (Großlage mit 50 verschiedenen Texten). Das Packen ist
  deterministisch, also reproduzierbar; die Laufzeit nicht.
- Tokenzahlen ohne Chat-Template und ohne Antwortschema-Overhead des Adapters.
- Fixture-Werte stammen aus `shared-types`, nicht aus der Laborsession. Die Bytegröße des
  Großlage-Rahmens (3.066) stammt aus der Kontextvorschau des Smoke-Laufs.
- Die Release-Doku nennt reale CPU-/Prefill-Messungen ausdrücklich als offen; dieser Befund
  ersetzt sie nicht.

## Reproduzieren

```bash
# Windows-Checkout (F:), Repo-Root
npx tsx lab-thema4/probes/budget-probe.ts
```

```bash
# WSL, Labor läuft
bash /mnt/f/arsnova.eu/lab-thema4/probes/tokenize-probe.sh
```

## Nachtrag 23.11.2026: Korrektur im Original-Repo (nach 1.3, nicht selbst gemessen)

Das Original-Repo `kqc-real/arsnova.eu` hat die Ursachen kurz nach dem 1.3-Release behoben; alle
drei Korrekturen sind in **v1.4.0** (7.11.2026) enthalten:

| Commit | Datum | Änderung | Begründung laut Commit (sinngemäß) |
| --- | --- | --- | --- |
| `06a0a10f` | 14.10. | Neu packen mit Fragen-Textbasis und kürzeren Texten, bis mindestens eine Frage enthalten ist; sonst Fallback `no_packed_sources` statt Modellaufruf mit leerem Paket | – |
| `c0a7f7d7` | 15.10. | Kontextfenster 4.096 → 8.192 in Packprofil und `llama-server --ctx-size` | das 4k-Fenster ließ die Produktionspakete leer |
| `baa27b31` | 15.10. | `QA_SUMMARY_TIMEOUT_MS` Standard 8 s → 90 s (Maximum 300 s) | der kurze Timeout brach llama.cpp vor Ende des Prefills ab und erzwang den extraktiven Fallback |

Der byteweise Schätzer ist unverändert. Die Antwortreserve bleibt in v1.4.0 bei 640 Tokens
(`moderationSummaryContext.ts:56` am Tag `v1.4.0`); erst auf `main` ist sie auf 192 gesenkt
(`OPEN_WEIGHT_LLM_SUMMARY_V2_MAX_OUTPUT_TOKENS`, geprüft an `7bfa8282`). *Korrektur vom 24.11.:*
Die erste Fassung dieses Nachtrags schrieb die 192 fälschlich schon v1.4.0 zu.

**Budget-Probe gegen `main` vom 23.11.** (`7bfa8282`; Rohdaten
[rohdaten/06-upstream-main/](rohdaten/06-upstream-main/), Dateinamen tragen noch „4096“ aus dem
Skript, das Profil ist 8.192): Das Sechs-Fragen-Fixture packt 7.861 von 8.192 Byte-Tokens mit
6 Quellen – 2 Fragen mit Text („Ist Kapitel 4 klausurrelevant?“, „Soll die Anwesenheit
verpflichtend sein?“), 2 Fragen nur als Referenz ohne Text, 2 semantische Themen. In 1.3 war es
eine Frage im Fixture und null im Live-Betrieb.

Die Zahlen der Probe gelten für `main` mit 192 Tokens Antwortreserve. In v1.4.0 bleiben wegen der
640er-Reserve 7.424 statt 7.872 Byte-Tokens für die Eingabe; wie viele Fragen dort mit Text
hineinpassen, ist nicht gerechnet. Die Mindestabdeckung aus `06a0a10f` gilt in beiden Ständen.

**Grenze:** Nur Code und Fixture-Probe. Die Messreihe des Referats bezieht sich auf 1.3.

**Kontrolllauf am 24.11. (v1.4.0 im Labor, Details im
[Laborprotokoll](laborprotokoll.md#kontrolllauf-v140-24112026)):** Das Packen funktioniert auch
live. Großlage: 2.500 Fragen → 200 analysiert → 13 verschieden → 8 im Kontext, 8 Quellen,
7.342 von 8.192. Handsession: 6 → 3 verschieden → 3 im Kontext (alle drei Themenpaare), 5.340
gepackt. Die KI rechnet 43–83 s und bleibt unter dem 90-s-Timeout, ihre Antwort wird aber in
6 von 6 Läufen verworfen (`invalid_response`). Die Ersatz-Kurzfassung zeigt jetzt 3 Fragen mit
Quellen statt nichts.

### Ergänzung 24.11.2026: Laufzeit laut Projekt, Standard, Beobachtbarkeit in v1.4.0

Quellen: Tag `v1.4.0` und `main` des Original-Repos, nur gelesen, kein eigener Lauf.

- **Die KI-Kurzfassung läuft laut Projektdokumentation.** `docs/features/qa-summary.md` (v1.4.0,
  Z. 138, eingefügt mit `7ea8e835` am 17.10.2026): Auf dem privaten Produktionshost mit 8 vCPU
  wurde `qa_summary` V2 „erfolgreich real ausgeführt“, in **56,9 s** mit 374 Completion-Tokens.
  Einschränkungen derselben Doku: Gemessen wurde mit dem damaligen Vertrag
  `qa-summary-technical-handoff-v2`, der aktuelle v4-Vertrag sei „noch neu zu vermessen“ (Z. 138).
  Das 8.192er-Profil sei ein sicherer Betriebszustand, „aber keine bestandene Full-context- oder
  CPU-Prefill-Abnahme“ (Z. 78).
- **Folge für die Messreihe (4C):** 56,9 s liegen über dem Maximum, das 1.3 überhaupt zulässt
  (`QA_SUMMARY_TIMEOUT_MAX_MS = 30_000`, `qaSummaryConfig.ts:13`). Eine echte Kurzfassung konnte in
  1.3 auf CPU also auch mit der 30-s-Variante nicht fertig werden. v1.4.0 setzt Standard 90 s und
  Maximum 300 s (`qaSummaryConfig.ts:23`, `:25`).
- **Standard bleibt aus:** `.env.example` in v1.4.0 (Z. 203–204) setzt `QA_SUMMARY_ENABLED=false`
  und `QA_SUMMARY_TIMEOUT_MS=90000`. Die Release-Notes 1.4.0 halten fest, dass die optionalen
  KI-Schalter standardmäßig aus bleiben.
- **4B unverändert:** Der Logeintrag `qa_summary:completed` hat in v1.4.0 (`qaSummaryQueue.ts:364`)
  und auf `main` (`085810d0` vom 24.11., Z. 433) weiter nur `status`, `effectiveMode`,
  `fallbackReason`, `latencyMs`. Die Zahl der übergebenen Fragen fehlt also weiterhin.
- **Host-Anzeige:** Der Text für eine leere extraktive Kurzfassung ist in v1.4.0 umformuliert,
  von „Für eine extraktive Kurzfassung sind noch keine Textbelege ausgewählt.“ zu „Es wurden noch
  keine offenen Fragen für die Kurzfassung ausgewählt.“ (`qaSummaryExtractive.ts:23`). Eine
  Auswertung von `fallback.reason` findet sich im Frontend-Code weder in 1.3 noch in 1.4.0. Im
  Browser ist v1.4.0 nicht geprüft.
