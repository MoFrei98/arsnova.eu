#!/usr/bin/env bash
# K4: Not-Aus in v1.4.0 (OPEN_WEIGHT_LLM_ENABLED=false), gleiche Handsession wie K2.
set -uo pipefail
cd "$HOME/arsnova-v140" || exit 1
export NVM_DIR="$HOME/.nvm"
set +eu; . "$NVM_DIR/nvm.sh" >/dev/null; set -u
nvm use >/dev/null
export HAND_STATE="$HOME/lab-hand-state-v140.json"
R="${RAW_DIR:-/mnt/f/arsnova.eu/lab-thema4/rohdaten/07-v140-kontrolllauf}"
APP=arsnova-v3-app
marke() { echo "$(date -Iseconds) $1" | tee -a "$R/zeitstempel.txt"; }
hand() {
  local line
  line=$(node lab-thema4/probes/handsession.mjs "$2" "${3:-}")
  echo "$line" | sed "s/^{/{\"run\":\"$1\",/" | tee -a "$R/handsession.jsonl" | cut -c1-420
}
healthy() { for i in $(seq 1 240); do [ "$(docker inspect -f '{{.State.Health.Status}}' "$1" 2>/dev/null)" = healthy ] && return 0; sleep 1; done; return 1; }
marke "K4 Not-Aus an"
OPEN_WEIGHT_LLM_ENABLED=false docker compose up -d app > "$R/K4-up.log" 2>&1
sleep 5; healthy "$APP" && echo "App healthy"
echo "Flags (Timeout, LLM, Summary): $(docker exec "$APP" printenv QA_SUMMARY_TIMEOUT_MS OPEN_WEIGHT_LLM_ENABLED QA_SUMMARY_ENABLED | tr '\n' ' ')" | tee -a "$R/zeitstempel.txt"
start=$(date -Iseconds)
for n in 1 2; do
  hand "K4-$n-frage" ask >/dev/null
  hand "K4-$n" request 60000
done
docker logs "$APP" --since "$start" > "$R/K4-app.txt" 2>&1
marke "K4 Ende"
