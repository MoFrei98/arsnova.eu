# 4A Soll-/Ist-Matrix – Entwurf aus dem Code (v1.3.0)

> **Status: Entwurf, nicht geprüft.** Erstellt am 16.11.2026 mit KI-Unterstützung (Claude) aus
> Code und Doku am Commit `87c39334` (Tag `v1.3.0`). Jede Aussage in „Ist (Code)“ ist eine
> Lesart des Codes und gilt erst als Befund, wenn dein eigener Laborlauf sie bestätigt. Die
> Spalte „Labor“ füllst du mit deinen Messungen. Gehört in die KI-Offenlegung des Handouts.

- **Soll** = Vertrag laut ADR-0035, Feature-Doku und Laufzeitvertrag am Release-Tag.
- **Ist (Code)** = was der Code an `v1.3.0` tut, mit Fundstelle.
- **Labor** = eigene Beobachtung, Wiederholungen, Rohdatenverweis.

## Gemeinsame Mechanik aller drei Auftragstypen

| Mechanik | Ist (Code) | Fundstelle |
| --- | --- | --- |
| Ein Slot | Globaler `inFlight`-Merker in der App, danach Slot-Sonde `GET /slots?fail_on_no_slot=1`. Belegt → `busy` mit `retry: 'manual'`. | [openWeightLlmClient.ts:357](../apps/backend/src/lib/openWeightLlmClient.ts#L357), [:380](../apps/backend/src/lib/openWeightLlmClient.ts#L380) |
| Fehlerklassen | Aufrufer bricht ab → `aborted`. Eigener Client-Timeout → `timeout`. Sonstige Exception (z. B. Socket weg) → `unavailable`. HTTP ≠ 200 → `unavailable`. 401/403/501 → `misconfigured`. Antwort nicht parsebar/schemawidrig → `invalid_response`. | [:172–181](../apps/backend/src/lib/openWeightLlmClient.ts#L172), [:380–406](../apps/backend/src/lib/openWeightLlmClient.ts#L380) |
| Client-Timeouts | Label 30 s, Summary 90 s, Lernziel 120 s (je Auftragstyp). | [openWeightLlmConfig.ts:4–6](../apps/backend/src/lib/openWeightLlmConfig.ts#L4) |
| Circuit Breaker | Nur `timeout`, `unavailable`, `invalid_response` zählen. Nach 3 Fehlern 30 s offen → sofort `circuit_open` ohne Runtimeaufruf. Jeder Erfolg setzt zurück. `busy` und `aborted` zählen **nicht**. | [:336–338](../apps/backend/src/lib/openWeightLlmClient.ts#L336), [:150–170](../apps/backend/src/lib/openWeightLlmClient.ts#L150), [openWeightLlmConfig.ts:9–10](../apps/backend/src/lib/openWeightLlmConfig.ts#L9) |
| Logging | Der Runtime-Client loggt nichts. Nur die Summary-Queue schreibt Logzeilen. | kein `logger`-Aufruf in `openWeightLlmClient.ts` |

Soll dazu: [Laufzeitvertrag](../docs/features/open-weight-llm-runtime.md) („global höchstens ein
App-Auftrag“, „Circuit Breaker öffnet nach drei Timeout-/Verfügbarkeits-/Antwortfehlern für 30
Sekunden“) und [ADR-0035, Abschnitt Slot](../docs/architecture/decisions/0035-self-hosted-llm-runtime-llama-cpp-over-ollama.md#L133).

## Summary (8.9c) – Live-Moderation, `qa.requestSummary`

Host-Aktion im Moderationskompass. Asynchrone Queue: Limit 8, Concurrency 1, eigener
Queue-Timeout `QA_SUMMARY_TIMEOUT_MS` = 8 s. Soll-Grundsatz: „Timeout, voller Queue, belegter
Runtime-Slot, ungültige Antwort oder während des Auftrags veränderte Quellen führen nicht zu
einer leeren Modellkarte, sondern zu einem typisierten Fallback“ ([qa-summary.md:64](../docs/features/qa-summary.md#L64), [ADR-0035 §2.5](../docs/architecture/decisions/0035-self-hosted-llm-runtime-llama-cpp-over-ollama.md#L198)).

| Störung | Soll | Ist (Code) | Fundstelle | Laborfall | Labor |
| --- | --- | --- | --- | --- | --- |
| **Timeout** | Extraktiver Fallback ([qa-summary.md:22](../docs/features/qa-summary.md#L22)) | Queue bricht nach 8 s per `AbortController` ab → extraktiv, `fallbackReason: timeout`, quellengebunden an den Stand nach dem Lauf. Der Client sieht nur den Abbruch (`aborted`), deshalb **zählt der Queue-Timeout nicht für den Circuit Breaker**. Der 90-s-Client-Timeout greift praktisch nie. | [qaSummaryQueue.ts:259–285](../apps/backend/src/lib/qaSummaryQueue.ts#L259), [:344–347](../apps/backend/src/lib/qaSummaryQueue.ts#L344), [openWeightLlmClient.ts:177](../apps/backend/src/lib/openWeightLlmClient.ts#L177) | `docker pause arsnova-v3-open-weight-llm` | |
| **503 / belegt** | Sofort fachlicher Fallback ([ADR-0035:133](../docs/architecture/decisions/0035-self-hosted-llm-runtime-llama-cpp-over-ollama.md#L133)) | `busy` (App-Merker oder Slot-503) → extraktiv, `fallbackReason: busy`, `retry: manual`. Zählt nicht für den Circuit. | [openWeightLlmClient.ts:357](../apps/backend/src/lib/openWeightLlmClient.ts#L357), [:380–381](../apps/backend/src/lib/openWeightLlmClient.ts#L380), [qaSummaryRuntimeAdapter.ts:54–69](../apps/backend/src/lib/qaSummaryRuntimeAdapter.ts#L54) | Lernzielableitung starten, währenddessen Summary anfordern | |
| **Ungültige Ausgabe (a): Schema/Parse** | Extraktiver Fallback | Unparsebar, schemawidrig oder Modellstatus `failed` → extraktiv, `fallbackReason: invalid_response`. Zählt für den Circuit. | [openWeightLlmClient.ts:403–405](../apps/backend/src/lib/openWeightLlmClient.ts#L403), [:471–478](../apps/backend/src/lib/openWeightLlmClient.ts#L471), [qaSummaryRuntimeAdapter.ts:56–69](../apps/backend/src/lib/qaSummaryRuntimeAdapter.ts#L56) | Mit echtem Modell nicht gezielt auslösbar → Vertragsnachweis über Tests oder gekennzeichneten Testadapter | |
| **Ungültige Ausgabe (b): schemagültig, aber ohne gültige Quellen** | Fremde Referenzen entfernen; bleibt keine belegte Aussage → `uncertain` ([qa-summary.md:40](../docs/features/qa-summary.md#L40)) | Aussagen ohne erlaubte `sourceIds` werden verworfen, Hinweis „Aussagen ohne belegte Quelle wurden entfernt.“. Bleibt nichts übrig: Status `uncertain`, **kein** extraktiver Fallback, `fallbackReason: null`, für den Circuit ein Erfolg. Soll = Ist, aber der Host sieht eine leere Kurzfassung und die Telemetrie einen normalen Modelllauf. | [qaSummaryValidateV2.ts:24–33](../apps/backend/src/lib/qaSummaryValidateV2.ts#L24), [:67–74](../apps/backend/src/lib/qaSummaryValidateV2.ts#L67), [:104](../apps/backend/src/lib/qaSummaryValidateV2.ts#L104) | wie (a) | |
| **Prozessausfall** | Fallback; Circuit nach 3 Fehlern 30 s | Socket ohne Listener → Exception → `unavailable` → extraktiv. Ab dem 3. Fehler `circuit_open` → extraktiv ohne Runtimeaufruf, 30 s lang. Nach einem Fallback blockiert der Cooldown keinen erneuten Klick, drei Anfragen hintereinander reichen also. | [openWeightLlmClient.ts:180](../apps/backend/src/lib/openWeightLlmClient.ts#L180), [:356](../apps/backend/src/lib/openWeightLlmClient.ts#L356), [qaSummaryQueue.ts:494–505](../apps/backend/src/lib/qaSummaryQueue.ts#L494) | `docker stop arsnova-v3-open-weight-llm`, dann 3× anfordern | |
| Queue voll | Extraktiv, `queue_full` ([qa-summary.md:23](../docs/features/qa-summary.md#L23)) | Extraktiv, `queue_full`, Log `qa_summary:skipped`. Kein Modelljob. | [qaSummaryQueue.ts:510–521](../apps/backend/src/lib/qaSummaryQueue.ts#L510) | optional, `QA_SUMMARY_QUEUE_LIMIT=1` | |
| Quelle während Lauf geändert | Modellantwort verwerfen, Fallback an neuen Stand ([qa-summary.md:66](../docs/features/qa-summary.md#L66)) | Hashvergleich vor/nach Lauf → extraktiv `source_changed`. Nach Abschluss prüft `summaryRuntime` erneut (siehe 4B). | [qaSummaryQueue.ts:340–345](../apps/backend/src/lib/qaSummaryQueue.ts#L340), [:418–439](../apps/backend/src/lib/qaSummaryQueue.ts#L418) | Stimme ändern, während die Runtime pausiert ist | |
| Kontextaufbau scheitert | Rechteverlust liefert keine alten Quellen (ADR-0035 §2.5) | Einzige echte **leere Karte**: Status `failed`, `effectiveMode: rule-based`, keine Aussagen, keine Quellen, Text „Die Zusammenfassung ist gerade nicht verfügbar.“, Grund `context_unavailable` oder `permission_changed`, Log `qa_summary:failed`. | [qaSummaryQueue.ts:189–212](../apps/backend/src/lib/qaSummaryQueue.ts#L189), [:246–257](../apps/backend/src/lib/qaSummaryQueue.ts#L246) | nicht Teil des Runtime-Störfalls; nur einordnen | |

## Lernzielableitung – Quizvorbereitung, `quiz.deriveLearningObjectives`

Läuft **nicht** in der Live-Session, sondern in der Lernzieloberfläche der Quizvorbereitung
([quiz.ts:245–271](../apps/backend/src/routers/quiz.ts#L245)). Batches sequenziell über denselben
Slot, gemeinsames Wall-Clock-Budget 120 s. Liefert nur Entwürfe; nur `completed` wird
append-only angewendet, bestehende Ziele werden nie ersetzt
([learning-objective-derivation.md:63](../docs/features/learning-objective-derivation.md#L63)).

| Störung | Soll | Ist (Code) | Fundstelle | Laborfall | Labor |
| --- | --- | --- | --- | --- | --- |
| **Timeout** | `timeout`, Teilergebnisse verworfen, Slot frei ([doc:43](../docs/features/learning-objective-derivation.md#L43)) | Gesamt-Deadline 120 s bricht den laufenden Aufruf ab → `timeout`. Der Client sieht `aborted` → zählt nicht für den Circuit. UI: „hat zu lange gedauert. Deine Lernziele bleiben unverändert.“ | [learningObjectiveDerivation.ts:410–433](../apps/backend/src/lib/learningObjectiveDerivation.ts#L410), [:357–362](../apps/backend/src/lib/learningObjectiveDerivation.ts#L357) | `docker pause` während der Ableitung (dauert 120 s) | |
| **503 / belegt** | `busy`, nur manueller Retry ([doc:35](../docs/features/learning-objective-derivation.md#L35), [ADR-0035:133](../docs/architecture/decisions/0035-self-hosted-llm-runtime-llama-cpp-over-ollama.md#L133)) | `busy` + `retry: 'manual'`, keine automatische Wiederholung. UI: „Das lokale Modell ist gerade ausgelastet. Deine Lernziele bleiben unverändert. Versuche es bewusst noch einmal.“ | [learningObjectiveDerivation.ts:434–437](../apps/backend/src/lib/learningObjectiveDerivation.ts#L434), [quiz-learning-objectives.component.ts:705](../apps/frontend/src/app/features/quiz/quiz-learning-objectives/quiz-learning-objectives.component.ts#L705) | Summary starten, währenddessen Ableitung anfordern | |
| **Ungültige Ausgabe** | Gesamter Lauf verworfen | Schemawidrig, fremde/batchfremde oder doppelte Frage-IDs → `invalid_response`, nichts angewendet. Achtung: Ist die Antwort schemagültig, aber die Referenzen falsch, hat der Client schon einen **Erfolg** für den Circuit gezählt. | [learningObjectiveDerivation.ts:439–448](../apps/backend/src/lib/learningObjectiveDerivation.ts#L439), [openWeightLlmClient.ts:414–415](../apps/backend/src/lib/openWeightLlmClient.ts#L414) | Vertragsnachweis über Tests | |
| **Prozessausfall** | `unavailable`, später `circuit_open`, Ziele unverändert | wie Soll. UI-Texte für `unavailable` und `circuit_open` vorhanden. | [openWeightLlmClient.ts:180](../apps/backend/src/lib/openWeightLlmClient.ts#L180), [quiz-learning-objectives.component.ts:713–720](../apps/frontend/src/app/features/quiz/quiz-learning-objectives/quiz-learning-objectives.component.ts#L713) | `docker stop`, dann Ableitung anfordern | |
| Datenerhalt (alle Fälle) | Kein Fehlerpfad verändert ein Lernziel | Fehlerpfade geben nur einen Status zurück, kein Schreibzugriff in der Ableitung. | [learningObjectiveDerivation.ts:368–448](../apps/backend/src/lib/learningObjectiveDerivation.ts#L368) | bestätigte Ziele vor/nach jeder Störung vergleichen | |
| Beobachtbarkeit | – | Weder Ableitung noch Client loggen. Lernzielfehler sind serverseitig unsichtbar (→ 4B). | kein `logger`-Aufruf | | |

## Label (1.14c Stufe 2) – generatives Themenlabel

| | Soll | Ist (Code) | Fundstelle |
| --- | --- | --- | --- |
| Vertrag | LLM darf nur das Label ersetzen, Ausfall → extraktives Label, **nicht** lexikalisch ([ADR-0035 §2.5](../docs/architecture/decisions/0035-self-hosted-llm-runtime-llama-cpp-over-ollama.md#L207)). Timeout 30 s. | Vertrag `topic_label` und Clientfunktion `runOpenWeightLlmTopicLabel` mit Fallback-Rückgabe existieren. | [openWeightLlmClient.ts:422–436](../apps/backend/src/lib/openWeightLlmClient.ts#L422), [open-weight-llm.ts:41](../libs/shared-types/src/open-weight-llm.ts#L41) |
| Verdrahtung | Leitfaden setzt einen Label-Auftrag auf der gemeinsamen Runtime voraus | **Kein Aufrufer im Backend.** Der Themenmodus nutzt in 1.3 immer extraktive Labels. Die Doku nennt LLM-Labels (Stufe 2) selbst als offen bzw. Nicht-Ziel. | Suche nach `topic_label` ohne weiteren Treffer; [word-cloud-semantic.md:179–181](../docs/features/word-cloud-semantic.md#L179), [ENVIRONMENT.md:392](../docs/ENVIRONMENT.md#L392) |
| Folge für 4A | – | Keine der vier Störungen kann ein Label verändern; das Soll ist erfüllt, weil Stufe 2 nicht aktiv ist. Laborfall optional: Themenmodus (Encoder-Profil) während `docker stop` → Labels bleiben extraktiv. Nicht verwechseln mit Encoder-Ausfall → lexikalischer Fallback (anderer Pfad). | |

## Folgen für Versuchsplan und Schlachtplan

1. **Recovery-Wartezeit:** Nach einem Fallback mit `retry: manual` blockiert der Cooldown keinen
   neuen Klick ([qaSummaryQueue.ts:494–505](../apps/backend/src/lib/qaSummaryQueue.ts#L494)).
   Die Wartezeit nach Wiederherstellung kommt also nur vom Circuit Breaker (bis 30 s), nicht vom
   Cooldown. Der Satz im Versuchsplan 4C („Cooldown erklärt die Wartezeit“) ist so zu korrigieren.
2. **`docker pause` öffnet den Circuit nie**, weil der 8-s-Queue-Timeout als Abbruch zählt.
   `circuit_open` entsteht nur über `docker stop` (`unavailable`) oder echte `invalid_response`.
3. **Leere Karte gibt es genau zweimal:** Kontextaufbau scheitert (`failed`) und schemagültige,
   aber vollständig unbelegte Modellantwort (`uncertain`). Beide sind für 4A und 4B interessant,
   weil die zweite in der Telemetrie wie ein Erfolg aussieht.
4. **Lernzielableitung ist kein Live-Auftrag.** Der Belegt-Test „Summary + Lernziel gleichzeitig“
   braucht zwei Browserfenster: Moderationskompass einer Live-Session und Lernzieloberfläche der
   Quizvorbereitung.
5. **Label-Zeile:** Im Handout als Befund mit Gültigkeitsgrenze formulieren („in 1.3 nicht
   verdrahtet“), nicht als bestandenen Fault-Injection-Test.

## Offene Prüfpunkte nur im Labor klärbar

- Hängt bei `docker pause` schon der Socket-Connect oder erst die Antwort? Erwartung in beiden
  Fällen: Fallback nach ≈ 8 s.
- Gibt `llama-server` den Slot nach dem Queue-Abbruch frei, oder rechnet er nach `docker unpause`
  den alten Auftrag weiter? Dann liefert die nächste Anfrage über die Slot-Sonde `busy`
  ([ADR-0035:139](../docs/architecture/decisions/0035-self-hosted-llm-runtime-llama-cpp-over-ollama.md#L139)).
- Wie lange braucht ein realer Summary-Lauf mit dem #456-Kontext? Liegt er über 8 s, landet die
  Baseline selbst im `timeout`-Fallback – das wäre der wichtigste Befund für die Entscheidung.
