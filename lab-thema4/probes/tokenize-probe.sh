#!/usr/bin/env bash
# Tokenize-Probe Labor Thema 4: vergleicht die Byte-Schätzung des Packers mit den
# echten Qwen3-Tokens der laufenden Runtime (llama-server /tokenize).
#
# Voraussetzung: Labor läuft (setup-wsl.sh), budget-probe.ts hat
# lab-thema4/rohdaten/budget/ erzeugt. Ausführen in WSL:
#   bash lab-thema4/probes/tokenize-probe.sh [Pfad zum budget-Ordner]
# Standard-Eingabe ist der Windows-Checkout auf F:, Ausgabe tokenize-probe.tsv daneben.
set -euo pipefail
IN_DIR="${1:-/mnt/f/arsnova.eu/lab-thema4/rohdaten/budget}"
export NVM_DIR="$HOME/.nvm"
set +eu
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh" >/dev/null
nvm use 24 >/dev/null
set -eu
# Direkt über die festen Containernamen, damit das Skript von jedem Pfad aus läuft.
token="$(docker exec arsnova-v3-app printenv OPEN_WEIGHT_LLM_TOKEN)"

count_tokens() {
  node -e 'const fs=require("fs");process.stdout.write(JSON.stringify({content:fs.readFileSync(0,"utf8")}))' \
    | docker exec -i arsnova-v3-open-weight-llm curl -sS --fail \
        --unix-socket /run/open-weight-llm/llm.sock \
        -H "Authorization: Bearer $token" -H 'Content-Type: application/json' \
        --data-binary @- http://localhost/tokenize \
    | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write(String(JSON.parse(s).tokens.length)))'
}

out="$IN_DIR/tokenize-probe.tsv"
printf 'file\tutf8_bytes\tqwen_tokens\tbytes_per_token\n' > "$out"
for f in "$IN_DIR"/instruction.txt "$IN_DIR"/definition.txt "$IN_DIR"/packed-*.json; do
  bytes=$(wc -c < "$f")
  toks=$(count_tokens < "$f")
  ratio=$(node -e "console.log(($bytes/$toks).toFixed(2))")
  printf '%s\t%s\t%s\t%s\n' "$(basename "$f")" "$bytes" "$toks" "$ratio" >> "$out"
done
column -t -s $'\t' "$out" 2>/dev/null || cat "$out"
echo "→ $out"
