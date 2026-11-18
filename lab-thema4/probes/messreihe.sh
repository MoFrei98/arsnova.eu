#!/usr/bin/env bash
# Messreihe Labor Thema 4 nach der Labor-Checkliste (Schlachtplan, Tab „Labor-Checkliste“).
# Ausführen im WSL-Klon:  bash lab-thema4/probes/messreihe.sh <phase>
#   phase1   V1, V2, B1-1..3 (Großlage), Handsession anlegen, B2-1..3, L0
#   phase2   S1-1..3 (pause), S2 (stop + Circuit), S3-1..3 (Slot belegt)
#   phase3   E3-1..2 (nur fachlich veraltet), E4 (Kontextvorschau)
#   phase4   C1 (30 s), C2a, C2b, C3 (Kill-Switch), C4 (Rückweg)
# Rohdaten landen direkt im Windows-Checkout: /mnt/f/arsnova.eu/lab-thema4/rohdaten.
set -uo pipefail
cd "$HOME/arsnova.eu"
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh" >/dev/null
nvm use >/dev/null
R=/mnt/f/arsnova.eu/lab-thema4/rohdaten
LLM=arsnova-v3-open-weight-llm
APP=arsnova-v3-app

# marke <ordner> <text>: Zeitstempel für jeden Eingriff
marke() { mkdir -p "$R/$1"; echo "$(date -Iseconds) $2" | tee -a "$R/$1/zeitstempel.txt"; }

# zeig <report.json>: Kernwerte eines Großlage-Laufs
zeig() {
  node -e 'const m=require(process.argv[1]).metrics,s=m.summary,c=m.contextPreview;
console.log("Summary:",s.status,"|",s.effectiveMode,"| Grund:",s.fallback?.reason??"-","|",s.totalDurationMs,"ms");
console.log("Kontext: Fragen",c.questionCorpus.represented,"von",c.questionCorpus.eligible,"| Quellen",c.sourceCount,"| Budget",c.budget.packedInputTokens+"/"+c.budget.contextWindowTokens);
console.log("Live: Q&A p95",m.qa.p95Ms,"ms | Stimmen",m.totalVotesAccepted+"/"+m.expectedVotes,"| Lernziele",JSON.stringify(m.learningObjectives))' "$1"
}

# logs <ordner> <name> <start-iso>: App- und Runtime-Log seit <start>
logs() {
  docker logs "$APP" --since "$3" > "$R/$1/$2-app.txt" 2>&1
  docker logs "$LLM" --since "$3" > "$R/$1/$2-runtime.txt" 2>&1 || true
}

# lauf <ordner> <name>: Großlage (Slice-8-Abnahme) mit Report, App- und Runtime-Log
lauf() {
  local out="$R/$1" ts start
  mkdir -p "$out"
  ts=$(date +%Y%m%d-%H%M%S); start=$(date -Iseconds)
  echo "$start START $2" >> "$out/zeitstempel.txt"
  REPORT_FILE="$out/$2-$ts.json" node scripts/load/issue-456-demo-acceptance.mjs --run > "$out/$2-$ts.log" 2>&1
  echo "$(date -Iseconds) ENDE $2 rc=$?" >> "$out/zeitstempel.txt"
  logs "$1" "$2-$ts" "$start"
  echo "== $2"; zeig "$out/$2-$ts.json"
}

# hand <ordner> <name> <befehl> [arg]: Handsession-Befehl, Ergebnis als JSON-Zeile
hand() {
  local line
  line=$(node lab-thema4/probes/handsession.mjs "$3" "${4:-}")
  echo "$line" | tee -a "$R/$1/handsession.jsonl" \
    | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=JSON.parse(s);console.log("  "+process.argv[1]+": "+JSON.stringify(r))})' "$2"
  echo "$line" | sed "s/^{/{\"run\":\"$2\",/" >> "$R/$1/handsession-runs.jsonl"
}

# live <datei>: Live-Last (30 Teilnehmende) im Hintergrund, PID in LIVE_PID
live() { REPORT_FILE="$1" npm run --silent load:smoke:qa-classroom-30 > "${1%.json}.log" 2>&1 & LIVE_PID=$!; }

# healthy <container> [max s]: warten bis healthy, gibt Sekunden aus
healthy() {
  local i
  for i in $(seq 1 "${2:-240}"); do
    [ "$(docker inspect -f '{{.State.Health.Status}}' "$1" 2>/dev/null)" = "healthy" ] && { echo "$i"; return 0; }
    sleep 1
  done
  echo "timeout"; return 1
}

flags() { docker exec "$APP" printenv QA_SUMMARY_TIMEOUT_MS OPEN_WEIGHT_LLM_ENABLED QA_SUMMARY_ENABLED | tr '\n' ' '; echo; }

phase1() {
  mkdir -p "$R/01-baseline"
  echo "== V1 Helfer am Smoke-Lauf"; zeig "$R/00-smoke/issue456-20261116-141816.json"
  echo "== V2 Stack und Flags"; docker ps --format '{{.Names}} {{.Status}}'; echo -n "Flags (Timeout, LLM, Summary): "; flags
  for n in 1 2 3; do lauf 01-baseline "B1-$n"; [ "$n" -lt 3 ] && sleep 60; done
  local start; start=$(date -Iseconds)
  marke 01-baseline "Handsession anlegen"
  hand 01-baseline create create
  hand 01-baseline preview-B2 preview
  for n in 1 2 3; do
    marke 01-baseline "B2-$n angefordert"
    hand 01-baseline "B2-$n" request 60000
    hand 01-baseline "B2-$n-neue-frage" ask
  done
  logs 01-baseline B2 "$start"
  marke 01-baseline "L0 Start"
  REPORT_FILE="$R/01-baseline/L0.json" npm run --silent load:smoke:qa-classroom-30 > "$R/01-baseline/L0.log" 2>&1
  marke 01-baseline "L0 Ende rc=$?"
  node -e 'const r=require(process.argv[1]);console.log("L0:",JSON.stringify(r.metrics?.submit??r.metrics,null,0).slice(0,400))' "$R/01-baseline/L0.json"
}

phase2() {
  mkdir -p "$R/02-stoerung"
  local start n
  for n in 1 2 3; do
    start=$(date -Iseconds)
    marke 02-stoerung "S1-$n pause"
    docker pause "$LLM" >/dev/null
    [ "$n" -eq 1 ] && live "$R/02-stoerung/L-S1.json"
    hand 02-stoerung "S1-$n" request 60000
    marke 02-stoerung "S1-$n Ergebnis sichtbar"
    [ "$n" -eq 1 ] && { wait "$LIVE_PID"; marke 02-stoerung "L-S1 Ende rc=$?"; }
    docker unpause "$LLM" >/dev/null
    marke 02-stoerung "S1-$n unpause"
    hand 02-stoerung "S1-$n-frage" ask
    hand 02-stoerung "S1-$n-nach-unpause" request 60000
    logs 02-stoerung "S1-$n" "$start"
  done
  start=$(date -Iseconds)
  marke 02-stoerung "S2 stop"
  docker stop "$LLM" >/dev/null
  live "$R/02-stoerung/L-S2.json"
  for n in 1 2 3 4; do
    marke 02-stoerung "S2 Anfrage $n"
    hand 02-stoerung "S2-$n" request 60000
  done
  wait "$LIVE_PID"; marke 02-stoerung "L-S2 Ende rc=$?"
  logs 02-stoerung S2 "$start"
  marke 02-stoerung "S2 start"
  docker start "$LLM" >/dev/null
  marke 02-stoerung "S2 Runtime healthy nach $(healthy "$LLM") s"
  for n in 1 2 3; do
    start=$(date -Iseconds)
    local token; token=$(docker exec "$APP" printenv OPEN_WEIGHT_LLM_TOKEN)
    marke 02-stoerung "S3-$n Slot belegt"
    docker exec "$LLM" curl -sS --unix-socket /run/open-weight-llm/llm.sock \
      -H "Authorization: Bearer $token" -H 'Content-Type: application/json' \
      -d '{"messages":[{"role":"user","content":"Zähle von 1 bis 400, jede Zahl ausgeschrieben."}],"max_tokens":600,"chat_template_kwargs":{"enable_thinking":false}}' \
      http://localhost/v1/chat/completions > /dev/null 2>&1 &
    local slot_pid=$!
    sleep 3
    hand 02-stoerung "S3-$n" ask >/dev/null
    hand 02-stoerung "S3-$n" request 60000
    wait "$slot_pid"
    marke 02-stoerung "S3-$n Slot frei"
    hand 02-stoerung "S3-$n-nach-frei" request 60000
    logs 02-stoerung "S3-$n" "$start"
  done
}

phase3() {
  mkdir -p "$R/03-erkennung"
  local start n
  for n in 1 2; do
    start=$(date -Iseconds)
    hand 03-erkennung "E3-$n-vorher" request 60000
    marke 03-erkennung "E3-$n Ergebnis da"
    hand 03-erkennung "E3-$n-stand-vorher" runtime
    hand 03-erkennung "E3-$n-stimme" vote
    marke 03-erkennung "E3-$n Stimme geändert"
    hand 03-erkennung "E3-$n-stand-nachher" runtime
    sleep 2
    logs 03-erkennung "E3-$n" "$start"
  done
  hand 03-erkennung "E4-handsession" preview
}

phase4() {
  mkdir -p "$R/04-aenderung"
  local start n t0
  marke 04-aenderung "C1 Variante 30 s"
  QA_SUMMARY_TIMEOUT_MS=30000 npm run --silent docker:up:llm > "$R/04-aenderung/C1-up.log" 2>&1
  healthy "$APP" 240 >/dev/null; echo -n "Flags (Timeout, LLM, Summary): "; flags | tee -a "$R/04-aenderung/zeitstempel.txt"
  for n in 1 2 3; do lauf 04-aenderung "C1-$n"; [ "$n" -lt 3 ] && sleep 30; done
  start=$(date -Iseconds)
  for n in 1 2 3; do
    hand 04-aenderung "C1-H$n-frage" ask
    marke 04-aenderung "C1-H$n angefordert"
    hand 04-aenderung "C1-H$n" request 90000
  done
  logs 04-aenderung C1-H "$start"
  # C2a: Wiederaufnahme nach Pause
  start=$(date -Iseconds)
  marke 04-aenderung "C2a pause"
  docker pause "$LLM" >/dev/null
  hand 04-aenderung "C2a-waehrend" request 90000
  docker unpause "$LLM" >/dev/null
  marke 04-aenderung "C2a unpause"
  hand 04-aenderung "C2a-frage" ask
  hand 04-aenderung "C2a-nach" request 90000
  logs 04-aenderung C2a "$start"
  # C2b: Wiederaufnahme nach Stop
  start=$(date -Iseconds)
  marke 04-aenderung "C2b stop"
  docker stop "$LLM" >/dev/null
  for n in 1 2 3 4; do hand 04-aenderung "C2b-stop-$n" request 90000; done
  marke 04-aenderung "C2b start"
  docker start "$LLM" >/dev/null
  marke 04-aenderung "C2b healthy nach $(healthy "$LLM") s"
  t0=$(date +%s)
  for n in 1 2 3 4 5 6; do
    hand 04-aenderung "C2b-nach-$n" request 90000
    if tail -n 1 "$R/04-aenderung/handsession.jsonl" | grep -q '"fallbackReason":null'; then
      marke 04-aenderung "C2b erster Lauf ohne Fallback nach $(( $(date +%s) - t0 )) s ab healthy"
      break
    fi
    hand 04-aenderung "C2b-nach-$n-frage" ask >/dev/null
    sleep 5
  done
  logs 04-aenderung C2b "$start"
  # C3: Kill-Switch
  marke 04-aenderung "C3 Kill-Switch an"
  OPEN_WEIGHT_LLM_ENABLED=false docker compose up -d app > "$R/04-aenderung/C3-up.log" 2>&1
  healthy "$APP" 240 >/dev/null; echo -n "Flags (Timeout, LLM, Summary): "; flags | tee -a "$R/04-aenderung/zeitstempel.txt"
  lauf 04-aenderung C3-1
  start=$(date -Iseconds)
  hand 04-aenderung "C3-H-frage" ask
  hand 04-aenderung "C3-H" request 60000
  logs 04-aenderung C3-H "$start"
  # C4: Rückweg zur Baseline
  marke 04-aenderung "C4 Rückweg"
  npm run --silent docker:up:llm > "$R/04-aenderung/C4-up.log" 2>&1
  healthy "$APP" 240 >/dev/null; echo -n "Flags (Timeout, LLM, Summary): "; flags | tee -a "$R/04-aenderung/zeitstempel.txt"
  lauf 04-aenderung C4-1
  echo "git status (WSL-Klon):"; git status --short | tee "$R/04-aenderung/C4-git-status.txt"
}

"${1:?phase1|phase2|phase3|phase4}"
