#!/usr/bin/env bash
# Labor-Setup Referat Thema 4 – arsnova.eu Release 1.3 (Tag v1.3.0, Commit 87c39334).
#
# Ausführen in WSL (Ubuntu), sobald Docker Desktop mit WSL-Integration läuft:
#   bash /mnt/f/arsnova.eu/lab-thema4/setup-wsl.sh
#
# Braucht in WSL nur Docker und Node – kein npm install. Die Lastskripte nutzen nur
# Node-Bordmittel. node_modules gehört der Windows-Seite (WebStorm, Plan-B-Tests);
# in WSL bitte NIE npm install/ci ausführen, sonst landen Linux-Binaries dort.
#
# Idempotent: erledigte Schritte werden übersprungen. Ändert keinen Releasecode.
# Einzige Laborabweichung: docker-compose.override.yml (QA_SUMMARY_ENABLED=true).
# Ziel ist ausschließlich 127.0.0.1 – niemals gegen arsnova.eu testen.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_COMMIT="87c39334619fbcb0c5782b061da1ba0df0ba3142"
NVM_VERSION="v0.40.3"
HEALTH_URL="http://127.0.0.1:3000/trpc/health.check"
MANIFEST_OUT="$REPO_DIR/lab-thema4/referenzmanifest.md"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[0;32m    ok: %s\033[0m\n' "$*"; }
fail() { printf '\n\033[1;31mFEHLER: %s\033[0m\n' "$*" >&2; exit 1; }

cd "$REPO_DIR"

step "1/7 Umgebung prüfen"
grep -qi microsoft /proc/version || fail "Bitte in WSL ausführen, nicht in Git Bash oder PowerShell."
command -v docker >/dev/null \
  || fail "docker fehlt. Docker Desktop → Settings → Resources → WSL Integration → diese Distribution aktivieren."
docker info >/dev/null 2>&1 || fail "Docker-Daemon nicht erreichbar. Läuft Docker Desktop?"
docker compose version >/dev/null 2>&1 || fail "docker compose fehlt."
ok "$(docker version --format 'Docker {{.Server.Version}}') · $(docker compose version --short 2>/dev/null || true)"

step "2/7 Release-Stand prüfen"
# Git in WSL lehnt Repos auf /mnt/* sonst wegen abweichender Eigentümer ab.
git config --global --get-all safe.directory | grep -qxF "$REPO_DIR" \
  || git config --global --add safe.directory "$REPO_DIR"
head_commit="$(git rev-parse HEAD)"
[ "$head_commit" = "$EXPECTED_COMMIT" ] \
  || fail "HEAD ist $head_commit, erwartet v1.3.0 ($EXPECTED_COMMIT). Branch referat/thema-4 auschecken."
if git ls-files --eol | grep -q 'w/crlf'; then
  fail "Arbeitskopie enthält CRLF-Dateien (Windows-Checkout). entrypoint.sh würde im Container scheitern."
fi
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  printf '    Hinweis: getrackte Dateien sind geändert – Baseline ist dann nicht mehr unverändert:\n'
  git status --short --untracked-files=no | sed 's/^/      /'
fi
ok "v1.3.0, LF-Zeilenenden"

step "3/7 Node $(cat .nvmrc) über nvm"
export NVM_DIR="$HOME/.nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | bash
fi
set +eu  # nvm ist nicht kompatibel mit set -eu
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"
nvm install >/dev/null   # liest .nvmrc
nvm use >/dev/null
set -eu
[ "$(node -v)" = "v$(cat .nvmrc)" ] || fail "Node-Version stimmt nicht: $(node -v)"
ok "Node $(node -v)"

step "4/7 Modell prüfen (SHA-256 laut docker/open-weight-llm/model-manifest.json)"
model_file="$(node -e "process.stdout.write(require('./docker/open-weight-llm/model-manifest.json').filename)")"
model_url="$(node -e "process.stdout.write(require('./docker/open-weight-llm/model-manifest.json').downloadUrl)")"
if [ ! -s "models/open-weight-llm/$model_file" ]; then
  printf '    Modell fehlt, lade %s (2,5 GB) …\n' "$model_file"
  mkdir -p models/open-weight-llm
  curl --fail --location --retry 5 -C - --output "models/open-weight-llm/$model_file" "$model_url"
fi
node scripts/open-weight-llm/verify-model.mjs
ok "Modell verifiziert"

step "5/7 Netzwerkfreie Vorprüfung des Referenzfalls"
npm run --silent load:issue-456:validate
ok "Issue-#456-Szenario valide"

step "6/7 Stack bauen und starten (App + Postgres + Redis + Runtime, Profil llm)"
printf '    Erster Build dauert mehrere Minuten (App-Image, llama.cpp-Image).\n'
npm run docker:up:llm
printf '    Warte auf App-Health'
for _ in $(seq 1 60); do
  if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then break; fi
  printf '.'; sleep 5
done
printf '\n'
curl -fsS "$HEALTH_URL" >/dev/null 2>&1 \
  || fail "App nicht healthy. Diagnose: docker compose logs app open-weight-llm --tail 100"
docker compose ps
summary_flag="$(docker compose exec -T app printenv QA_SUMMARY_ENABLED || true)"
llm_flag="$(docker compose exec -T app printenv OPEN_WEIGHT_LLM_ENABLED || true)"
[ "$summary_flag" = "true" ] || fail "QA_SUMMARY_ENABLED im App-Container ist '$summary_flag' – Override nicht geladen?"
[ "$llm_flag" = "true" ] || fail "OPEN_WEIGHT_LLM_ENABLED im App-Container ist '$llm_flag'."
ok "App healthy, QA_SUMMARY_ENABLED=true, OPEN_WEIGHT_LLM_ENABLED=true"

step "7/7 Referenzmanifest schreiben → lab-thema4/referenzmanifest.md"
{
  echo "# Referenzmanifest Labor Thema 4"
  echo
  echo "Erzeugt: $(date -Iseconds) durch lab-thema4/setup-wsl.sh"
  echo
  echo "## Release"
  echo "- Tag/Commit: $(git describe --tags --exact-match 2>/dev/null || echo '-') / $(git rev-parse HEAD)"
  echo "- Laborabweichung: docker-compose.override.yml (QA_SUMMARY_ENABLED=true)"
  echo
  echo "## Hardware (WSL-Sicht)"
  echo "- CPU: $(lscpu | sed -n 's/^Model name:[[:space:]]*//p') · $(nproc) logische CPUs für WSL"
  echo "- RAM für WSL: $(free -g | awk '/^Mem:/{print $2}') GiB"
  echo "- Kernel: $(uname -r)"
  echo
  echo "## Container"
  echo "- $(docker version --format 'Docker Engine {{.Server.Version}}')"
  docker compose ps --format '- {{.Name}}: {{.Image}} ({{.Status}})'
  echo "- Runtime-Limits: $(docker inspect arsnova-v3-open-weight-llm --format 'CPUs={{.HostConfig.NanoCpus}} (1e9 = 1 CPU), Memory={{.HostConfig.Memory}} B, PIDs={{.HostConfig.PidsLimit}}' 2>/dev/null || echo 'nicht ermittelbar')"
  echo
  echo "## Modell"
  node -e "const m=require('./docker/open-weight-llm/model-manifest.json');console.log('- '+m.model+' '+m.quantization+' ('+m.filename+')\n- SHA-256: '+m.sha256+'\n- Quelle: '+m.sourceRepository+'@'+m.sourceRevision+'\n- Runtime-Image (Basis): '+m.runtimeImage)"
  echo
  echo "## Flags und Grenzen im App-Container"
  for var in QA_SUMMARY_ENABLED QA_SUMMARY_TIMEOUT_MS OPEN_WEIGHT_LLM_ENABLED NLP_ENABLED WORD_CLOUD_SEMANTIC_ENABLED; do
    echo "- $var=$(docker compose exec -T app printenv "$var" 2>/dev/null || echo '(nicht gesetzt → Releasedefault)')"
  done
  echo "- Releasedefaults laut Code: Timeout 8.000 ms (max. 30.000), Queue 8, Concurrency 1, Cooldown 30 s, TTL 30 min, Circuit Breaker 3 Fehler / 30 s"
} > "$MANIFEST_OUT"
ok "$MANIFEST_OUT"

cat <<'EOF'

Labor läuft. Nächste Schritte (Phase Baseline):
  npm run load:issue-456:run                      # Referenzfall, 3× wiederholen, Report sichern
  docker compose logs app | grep qa_summary       # Telemetrie zum Lauf
  npm run load:smoke:qa-classroom-30              # Live-Last parallel (Join/Vote/Submit)

Störungen (4A):  docker pause|unpause arsnova-v3-open-weight-llm · docker stop|start arsnova-v3-open-weight-llm
Kill-Switch (4C): docker compose up -d app   (ohne npm run docker:up:llm → OPEN_WEIGHT_LLM_ENABLED=false)
Zurück:           npm run docker:up:llm
Alles stoppen:    docker compose --profile llm down
EOF
