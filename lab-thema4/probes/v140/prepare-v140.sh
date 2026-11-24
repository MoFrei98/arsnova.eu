#!/usr/bin/env bash
# Kontrolllauf v1.4.0: eigenen Worktree ~/arsnova-v140 auf Tag v1.4.0 anlegen, Laborteile übernehmen,
# Abhängigkeiten der Lastskripte installieren. Ändert ~/arsnova.eu (1.3-Labor) nicht.
set -euo pipefail
export GIT_TERMINAL_PROMPT=0
export NVM_DIR="$HOME/.nvm"
set +eu; . "$NVM_DIR/nvm.sh" >/dev/null; set -eu
LAB="$HOME/arsnova.eu"
WT="$HOME/arsnova-v140"
cd "$LAB"
git fetch --quiet --no-tags upstream "refs/tags/v1.4.0:refs/tags/v1.4.0"
if [ ! -d "$WT" ]; then git worktree add --quiet --detach "$WT" v1.4.0; fi
cd "$WT"
git checkout --quiet --detach v1.4.0
echo "Stand: $(git describe --tags) $(git log -1 --format='%h %ci')"
# Laborteile: dieselbe Override-Datei wie in 1.3 (KI-Kurzfassung an, Timeout nur durchgereicht),
# Laborsecrets aus der 1.3-.env, Treiber-Skripte. Nichts davon wird hier committet.
cp "$LAB/docker-compose.override.yml" "$WT/docker-compose.override.yml"
# In v1.4.0 ist der Releasestandard 90 s (qaSummaryConfig.ts:23); die 1.3-Override würde sonst 8 s erzwingen.
sed -i 's/QA_SUMMARY_TIMEOUT_MS:-8000}/QA_SUMMARY_TIMEOUT_MS:-90000}/' "$WT/docker-compose.override.yml"
grep -q 'QA_SUMMARY_TIMEOUT_MS:-90000}' "$WT/docker-compose.override.yml" || { echo "Timeout-Standard nicht gesetzt" >&2; exit 1; }
cp "$LAB/.env" "$WT/.env"; chmod 600 "$WT/.env"
mkdir -p "$WT/lab-thema4/probes"
cp "$LAB/lab-thema4/probes/handsession.mjs" "$WT/lab-thema4/probes/"
# Modell: dieselbe Datei (gleicher SHA-256 laut Manifest), als harter Link statt 2,5-GB-Kopie.
mkdir -p "$WT/models/open-weight-llm"
f=$(node -e "process.stdout.write(require('./docker/open-weight-llm/model-manifest.json').filename)")
[ -e "$WT/models/open-weight-llm/$f" ] || ln "$LAB/models/open-weight-llm/$f" "$WT/models/open-weight-llm/$f"
grep -qxF '/models/' "$(git rev-parse --git-common-dir)/info/exclude" || true
nvm install >/dev/null 2>&1; nvm use >/dev/null
echo "Node $(node -v)"
if [ ! -d node_modules/@trpc/client ]; then npm ci --ignore-scripts --no-audit --no-fund --loglevel=error; fi
node scripts/open-weight-llm/verify-model.mjs | tail -1
echo "Timeout-Standard laut Code: $(grep -o 'QA_SUMMARY_TIMEOUT_DEFAULT_MS = [0-9_]*' apps/backend/src/lib/qaSummaryConfig.ts)"
echo "bereit"
