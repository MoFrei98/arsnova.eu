#!/usr/bin/env bash
# Kontrolllauf v1.4.0 (24.11.2026), gleiches Muster wie die 1.3-Messreihe:
#   K1-1..2  Großlage (Slice-8-Abnahme, 250 TN, 2.500 Fragen)
#   K2-1..3  Handsession mit den sechs Referenzfragen, Anforderung bis 150 s
#   K3a      Live-Last allein (Bezug)
#   K3b      Live-Last, während die KI eine Kurzfassung rechnet
# Rohdaten: /mnt/f/arsnova.eu/lab-thema4/rohdaten/07-v140-kontrolllauf
set -uo pipefail
cd "$HOME/arsnova-v140" || exit 1
export NVM_DIR="$HOME/.nvm"
set +eu; . "$NVM_DIR/nvm.sh" >/dev/null; set -u
nvm use >/dev/null
export HAND_STATE="$HOME/lab-hand-state-v140.json"
R="${RAW_DIR:-/mnt/f/arsnova.eu/lab-thema4/rohdaten/07-v140-kontrolllauf}"
mkdir -p "$R"
APP=arsnova-v3-app
LLM=arsnova-v3-open-weight-llm

marke() { echo "$(date -Iseconds) $1" | tee -a "$R/zeitstempel.txt"; }
logs() {
  docker logs "$APP" --since "$2" > "$R/$1-app.txt" 2>&1
  docker logs "$LLM" --since "$2" > "$R/$1-runtime.txt" 2>&1 || true
}
hand() {
  local line
  line=$(node lab-thema4/probes/handsession.mjs "$2" "${3:-}")
  echo "$line" | sed "s/^{/{\"run\":\"$1\",/" | tee -a "$R/handsession.jsonl" | cut -c1-400
}
zeig() {
  node -e '
const r=require(process.argv[1]); const m=r.metrics??{}; const s=m.summary??{}; const c=m.contextPreview??{};
console.log(JSON.stringify({
  summary:{status:s.status, effectiveMode:s.effectiveMode, fallback:s.fallback?.reason??null, totalDurationMs:s.totalDurationMs,
           statements:s.statements??s.statementCount??null, sources:s.sources??s.sourceCount??null},
  kontext:{fragen:c.questionCorpus?.represented, zulaessig:c.questionCorpus?.eligible, quellen:c.sourceCount,
           budget:c.budget?`${c.budget.packedInputTokens}/${c.budget.contextWindowTokens}`:null},
  live:{qaP95:m.qa?.p95Ms, stimmen:`${m.totalVotesAccepted}/${m.expectedVotes}`, lernziele:m.learningObjectives},
  summaryKeys:Object.keys(s)}))' "$1"
}

marke "K0 Stand"
{
  echo "Tag: $(git describe --tags)"
  git log -1 --format='Commit: %H %ci'
  echo "Flags (Timeout, LLM, Summary): $(docker exec "$APP" printenv QA_SUMMARY_TIMEOUT_MS OPEN_WEIGHT_LLM_ENABLED QA_SUMMARY_ENABLED | tr '\n' ' ')"
  token="$(docker exec "$APP" printenv OPEN_WEIGHT_LLM_TOKEN)"
  echo "Runtime /props: $(docker exec "$LLM" curl -sS --unix-socket /run/open-weight-llm/llm.sock -H "Authorization: Bearer $token" http://localhost/props | grep -o -E '"n_ctx":[0-9]+|"total_slots":[0-9]+|"build_info":"[^"]*"' | sort -u | tr '\n' ' ')"
  unset token
  echo "Limits Runtime: $(docker inspect -f 'cpus={{.HostConfig.NanoCpus}} mem={{.HostConfig.Memory}}' "$LLM")"
  echo "CPU: $(lscpu | sed -n 's/^Model name:[[:space:]]*//p') · $(nproc) logische CPUs für WSL"
} | tee "$R/stand.txt"

for n in 1 2; do
  start=$(date -Iseconds)
  marke "K1-$n Großlage Start"
  REPORT_FILE="$R/K1-$n.json" node scripts/load/issue-456-demo-acceptance.mjs --run > "$R/K1-$n.log" 2>&1
  marke "K1-$n Ende rc=$?"
  logs "K1-$n" "$start"
  echo "== K1-$n"; zeig "$R/K1-$n.json"
  [ "$n" -lt 2 ] && sleep 60
done

start=$(date -Iseconds)
marke "K2 Handsession anlegen"
hand K2-create create
hand K2-preview preview
for n in 1 2 3; do
  marke "K2-$n angefordert"
  hand "K2-$n" request 150000
  marke "K2-$n Ergebnis"
  hand "K2-$n-frage" ask >/dev/null
done
logs K2 "$start"

marke "K3a Live-Last allein"
REPORT_FILE="$R/K3a-live.json" npm run --silent load:smoke:qa-classroom-30 > "$R/K3a-live.log" 2>&1
marke "K3a Ende rc=$?"
start=$(date -Iseconds)
hand K3b-frage ask >/dev/null
marke "K3b Live-Last während KI-Lauf"
REPORT_FILE="$R/K3b-live.json" npm run --silent load:smoke:qa-classroom-30 > "$R/K3b-live.log" 2>&1 &
live=$!
sleep 2
hand K3b request 150000
wait "$live"; marke "K3b Live-Last Ende rc=$?"
logs K3b "$start"
for f in K3a K3b; do
  node -e 'const r=require(process.argv[1]);const m=r.metrics??r;console.log(process.argv[2],JSON.stringify(m.submit??m).slice(0,300))' "$R/$f-live.json" "$f"
done
marke "Ende"
