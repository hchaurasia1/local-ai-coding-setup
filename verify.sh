#!/usr/bin/env bash
# Read-only checks against the local Ollama server. Changes nothing. Ends with
# a block you can paste straight into RESULTS.md.
#
# Usage:
#   ./verify.sh [profile]
#
# With no profile the model name is read from ~/.config/opencode/opencode.json.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
OPENCODE_CONFIG="${HOME}/.config/opencode/opencode.json"
PASS=0; WARN=0; FAIL=0

say()  { printf '\n==> %s\n' "$*"; }
ok()   { PASS=$((PASS + 1)); printf '  PASS  %s\n' "$*"; }
warn() { WARN=$((WARN + 1)); printf '  WARN  %s\n' "$*"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$*"; }

command -v python3 >/dev/null 2>&1 || { echo "python3 is required (it ships with the Xcode Command Line Tools)"; exit 1; }
command -v curl    >/dev/null 2>&1 || { echo "curl is required"; exit 1; }

# ----------------------------------------------------------- which model ----
MODEL=""
if [[ $# -ge 1 ]]; then
  PROFILE_FILE="${KIT_DIR}/profiles/$1.env"
  [[ -f "${PROFILE_FILE}" ]] || { echo "no such profile: $1 (see profiles/)"; exit 2; }
  # shellcheck source=/dev/null
  source "${PROFILE_FILE}"
elif [[ -f "${OPENCODE_CONFIG}" ]]; then
  MODEL="$(python3 -I - "${OPENCODE_CONFIG}" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1]))
m = cfg.get("model", "")
print(m.split("/", 1)[1] if "/" in m else m)
PY
)"
fi
[[ -n "${MODEL}" ]] || { echo "could not work out which model to test; pass a profile name"; exit 2; }

# ---------------------------------------------------------------- server ----
say "Ollama server"
if BANNER="$(curl -sf "${OLLAMA_URL}" 2>/dev/null)"; then
  ok "reachable at ${OLLAMA_URL} (${BANNER})"
else
  bad "nothing is answering at ${OLLAMA_URL}. Is the Ollama app running? (llama icon in the menu bar)"
  exit 1
fi

CTX_ENV="$(launchctl getenv OLLAMA_CONTEXT_LENGTH 2>/dev/null || true)"
if [[ -n "${CTX_ENV}" ]]; then
  ok "OLLAMA_CONTEXT_LENGTH=${CTX_ENV} is set for GUI apps"
else
  warn "OLLAMA_CONTEXT_LENGTH is not set for GUI apps; the server is probably on its 4096 default. Run ./install.sh"
fi
KV_ENV="$(launchctl getenv OLLAMA_KV_CACHE_TYPE 2>/dev/null || true)"
if [[ -n "${KV_ENV}" ]]; then
  ok "OLLAMA_KV_CACHE_TYPE=${KV_ENV}"
else
  warn "OLLAMA_KV_CACHE_TYPE is not set (default f16 uses twice the context memory of q8_0)"
fi

# ----------------------------------------------------------------- model ----
say "Model ${MODEL}"
if curl -s "${OLLAMA_URL}/v1/models" \
   | python3 -I -c 'import json, sys; ids = [m["id"] for m in json.load(sys.stdin)["data"]]; sys.exit(0 if sys.argv[1] in ids else 1)' "${MODEL}"; then
  ok "listed by ${OLLAMA_URL}/v1/models (this is what OpenCode and Conductor see)"
else
  bad "not in /v1/models. Run: ollama pull ${MODEL}"
  exit 1
fi

# ----------------------------------------------------------------- speed ----
say "Generation speed (one short completion; the first call includes load time)"
GEN_REQ="$(python3 -I -c 'import json, sys; print(json.dumps({"model": sys.argv[1], "prompt": "Write a four-line poem about git worktrees.", "stream": False, "options": {"num_predict": 120}}))' "${MODEL}")"
GEN_RESP="$(curl -s "${OLLAMA_URL}/api/generate" -d "${GEN_REQ}")"
SPEED_LINE="$(printf '%s' "${GEN_RESP}" | python3 -I -c '
import json, sys
r = json.load(sys.stdin)
if "error" in r:
    print("ERROR " + str(r["error"])); sys.exit(0)
ec, ed = r.get("eval_count", 0), max(r.get("eval_duration", 1), 1)
pc, pd = r.get("prompt_eval_count", 0), max(r.get("prompt_eval_duration", 1), 1)
load = r.get("load_duration", 0) / 1e9
print(f"{ec / (ed / 1e9):.1f} tok/s generation, {pc / (pd / 1e9):.0f} tok/s prompt processing, model load {load:.1f} s")
')"
case "${SPEED_LINE}" in
  ERROR*) bad "${SPEED_LINE}" ;;
  *)      ok "${SPEED_LINE}" ;;
esac

# ------------------------------------------------------------- tool call ----
say "Tool-call probe (a coding agent cannot read or edit files without this)"
TOOL_REQ="$(python3 -I -c 'import json, sys
print(json.dumps({
  "model": sys.argv[1],
  "messages": [{"role": "user", "content": "What is the weather in Pune right now? You must call the get_weather tool to find out."}],
  "tools": [{"type": "function", "function": {"name": "get_weather", "description": "Get the current weather for a city", "parameters": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}}}],
  "tool_choice": "auto"
}))' "${MODEL}")"
TOOL_RESP="$(curl -s "${OLLAMA_URL}/v1/chat/completions" -H 'Content-Type: application/json' -d "${TOOL_REQ}")"
TOOL_LINE="$(printf '%s' "${TOOL_RESP}" | python3 -I -c '
import json, sys
r = json.load(sys.stdin)
if "error" in r:
    print("ERROR " + str(r["error"])); sys.exit(0)
msg = r["choices"][0]["message"]
calls = msg.get("tool_calls") or []
if calls:
    f = calls[0]["function"]
    print("CALLED " + f["name"] + " " + str(f.get("arguments", "")))
else:
    print("NOCALL " + (msg.get("content") or "")[:120].replace("\n", " "))
')"
case "${TOOL_LINE}" in
  CALLED*) ok "model emitted a tool call: ${TOOL_LINE#CALLED }" ;;
  ERROR*)  bad "${TOOL_LINE}" ;;
  *)       warn "model answered in prose instead of calling the tool: ${TOOL_LINE#NOCALL }" ;;
esac

# -------------------------------------------------------------- ollama ps ----
say "Where the model is running (ollama ps)"
PS_OUT=""
if command -v ollama >/dev/null 2>&1; then
  PS_OUT="$(ollama ps 2>/dev/null || true)"
  printf '%s\n' "${PS_OUT}" | sed 's/^/    /'
fi
if ! command -v ollama >/dev/null 2>&1; then
  warn "the 'ollama' CLI is not on PATH, so 'ollama ps' could not run. Run ./install.sh"
elif printf '%s\n' "${PS_OUT}" | grep '100% GPU' >/dev/null; then
  ok "100% GPU: nothing spilled to the CPU"
elif printf '%s\n' "${PS_OUT}" | grep -E '[0-9]+%/[0-9]+% CPU/GPU' >/dev/null; then
  warn "model is split between CPU and GPU. Lower CONTEXT in the profile, or use FALLBACK_MODEL, then re-run ./install.sh"
else
  warn "could not read the PROCESSOR column (model may already have been unloaded)"
fi

# ---------------------------------------------------------------- memory ----
say "Memory"
MEM_GB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
FREE_PCT="$(memory_pressure 2>/dev/null | awk -F': ' '/System-wide memory free percentage/ {print $2}' | tail -1)"
ok "${MEM_GB} GB unified memory, ${FREE_PCT:-?} free right now (memory_pressure)"

# --------------------------------------------------------------- summary ----
say "Summary: ${PASS} pass, ${WARN} warn, ${FAIL} fail"
cat <<SUMMARY

---- paste into RESULTS.md ----
machine:        $(sysctl -n machdep.cpu.brand_string), ${MEM_GB} GB
date:           $(date +%Y-%m-%d)
model:          ${MODEL}
context (env):  ${CTX_ENV:-unset (4096 default)}
kv cache:       ${KV_ENV:-f16 (default)}
speed:          ${SPEED_LINE}
tool call:      ${TOOL_LINE}
ollama ps:      $(printf '%s\n' "${PS_OUT}" | tail -n +2 | head -1)
memory free:    ${FREE_PCT:-?}
--------------------------------
SUMMARY
[[ ${FAIL} -eq 0 ]]
