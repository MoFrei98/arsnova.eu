# Referenzmanifest Labor Thema 4

Erzeugt: 2026-11-16T14:16:46+01:00 durch lab-thema4/setup-wsl.sh

## Release
- Basis: v1.3.0 / 87c39334619fbcb0c5782b061da1ba0df0ba3142
- Laborstand: referat/thema-4 @ 2558c8630542f174366348c145c0aa3006279782 (über v1.3.0 hinaus nur docker-compose.override.yml und lab-thema4/)
- Laborabweichung fachlich: docker-compose.override.yml (QA_SUMMARY_ENABLED=true)
- Laborabweichung betrieblich: zufällige lokale JWT_SECRET und CAPABILITY_ENVELOPE_KEY_BASE64 aus .env (Release-Compose setzt sie nicht, App startet mit NODE_ENV=production sonst nicht)

## Hardware (WSL-Sicht)
- CPU: Intel(R) Core(TM) i7-14700 · 28 logische CPUs für WSL
- RAM für WSL: 15 GiB
- Kernel: 6.18.58.1-microsoft-standard-WSL2

## Container
- Docker Engine 29.9.3
- arsnova-v3-app: arsnovaeu-app (Up 5 seconds (healthy))
- arsnova-v3-open-weight-llm: sha256:7dd403b7fe0f01f0aa7d0f60ab9abbd2a3155186569b034fa73b08a950ba8322 (Up 6 minutes (healthy))
- arsnova-v3-postgres: postgres:16-alpine (Up 6 minutes (healthy))
- arsnova-v3-redis: redis:7.4-alpine (Up 6 minutes (healthy))
- Runtime-Limits: CPUs=4000000000 (1e9 = 1 CPU), Memory=5368709120 B, PIDs=128

## Modell
- Qwen3-4B-Instruct-2507 Q4_K_M (Qwen3-4B-Instruct-2507-Q4_K_M.gguf)
- SHA-256: 3605803b982cb64aead44f6c1b2ae36e3acdb41d8e46c8a94c6533bc4c67e597
- Quelle: unsloth/Qwen3-4B-Instruct-2507-GGUF@a06e946bb6b655725eafa393f4a9745d460374c9
- Runtime-Image (Basis): ghcr.io/ggml-org/llama.cpp:server-b10524@sha256:57e505f69c3a55fa5dd9c15fced47cff7a899f5b5b504ea93d75b2f401b87830

## Flags und Grenzen im App-Container
- QA_SUMMARY_ENABLED=true
- QA_SUMMARY_TIMEOUT_MS=8000
- OPEN_WEIGHT_LLM_ENABLED=true
- NLP_ENABLED=false
- WORD_CLOUD_SEMANTIC_ENABLED=false
- Releasedefaults laut Code: Timeout 8.000 ms (max. 30.000), Queue 8, Concurrency 1, Cooldown 30 s, TTL 30 min, Circuit Breaker 3 Fehler / 30 s
