#!/usr/bin/env bash
# 1.3-Stack anhalten (Volumes bleiben), v1.4.0-Stack mit KI bauen und starten, auf healthy warten.
set -uo pipefail
export NVM_DIR="$HOME/.nvm"
set +eu; . "$NVM_DIR/nvm.sh" >/dev/null; set -u
echo "$(date -Iseconds) 1.3-Stack anhalten"
(cd "$HOME/arsnova.eu" && docker compose --profile llm down 2>&1 | tail -3)
cd "$HOME/arsnova-v140" || exit 1
nvm use >/dev/null
echo "$(date -Iseconds) v1.4.0 bauen und starten"
npm run --silent docker:up:llm 2>&1 | tail -5
healthy() { for i in $(seq 1 300); do [ "$(docker inspect -f '{{.State.Health.Status}}' "$1" 2>/dev/null)" = healthy ] && { echo "$1 healthy nach $i s"; return 0; }; sleep 1; done; echo "$1 NICHT healthy"; return 1; }
healthy arsnova-v3-app; healthy arsnova-v3-open-weight-llm
echo "Flags (Timeout, LLM, Summary): $(docker exec arsnova-v3-app printenv QA_SUMMARY_TIMEOUT_MS OPEN_WEIGHT_LLM_ENABLED QA_SUMMARY_ENABLED | tr '\n' ' ')"
echo "Runtime-Kontext: $(docker logs arsnova-v3-open-weight-llm 2>&1 | grep -o -E 'n_ctx(_seq)?\s*=\s*[0-9]+' | tail -2 | tr '\n' ' ')"
docker ps --format '{{.Names}} {{.Status}}'
echo "$(date -Iseconds) fertig"
