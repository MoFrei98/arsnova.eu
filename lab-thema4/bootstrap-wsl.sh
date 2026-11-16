#!/usr/bin/env bash
# Bootstrap Labor Thema 4: klont das Repo ins WSL-Dateisystem und startet das Setup.
#
# Aufruf in Ubuntu (WSL2), sobald Docker Desktop mit WSL-Integration läuft:
#   bash /mnt/f/arsnova.eu/lab-thema4/bootstrap-wsl.sh
#
# Ergebnis: ~/arsnova.eu auf Branch referat/thema-4 = Tag v1.3.0 plus Labordateien
# (nicht main). Das Modell wird aus dem bereits geprüften Download auf F: kopiert,
# nicht neu geladen. Danach läuft lab-thema4/setup-wsl.sh im WSL-Klon.
# Idempotent: ein vorhandener Klon wird nur aktualisiert.
set -euo pipefail

TARGET_DIR="${TARGET_DIR:-$HOME/arsnova.eu}"
FORK_URL="https://github.com/MoFrei98/arsnova.eu.git"
UPSTREAM_URL="https://github.com/kqc-real/arsnova.eu.git"
LAB_BRANCH="referat/thema-4"
SOURCE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

grep -qi microsoft /proc/version || { echo "FEHLER: Bitte in WSL ausführen." >&2; exit 1; }
command -v git >/dev/null || { echo "FEHLER: git fehlt: sudo apt-get install -y git" >&2; exit 1; }

if [ ! -d "$TARGET_DIR/.git" ]; then
  echo "==> Klone $FORK_URL ($LAB_BRANCH) nach $TARGET_DIR"
  git clone --branch "$LAB_BRANCH" "$FORK_URL" "$TARGET_DIR"
fi
cd "$TARGET_DIR"

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$UPSTREAM_URL"
git fetch --quiet --no-tags upstream "refs/tags/v1.3.0:refs/tags/v1.3.0"
git switch --quiet "$LAB_BRANCH"
git pull --quiet --ff-only

# Modellgewichte nie committen (2,5 GB).
grep -qxF '/models/' .git/info/exclude 2>/dev/null || printf '/models/\n' >> .git/info/exclude

echo "==> Repo bereit: $TARGET_DIR · $(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD) · Basis $(git describe --tags --abbrev=0)"

MODEL_SOURCE_DIR="${MODEL_SOURCE_DIR:-$SOURCE_REPO/models/open-weight-llm}" \
  exec bash lab-thema4/setup-wsl.sh
