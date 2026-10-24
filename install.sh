#!/usr/bin/env bash
# Set up a free, fully local coding-agent stack on an Apple Silicon Mac:
#
#   Ollama   - runs the model on your machine and serves it on localhost:11434
#   Qwen     - the open-weight model Ollama downloads and runs
#   OpenCode - the coding agent (harness); this script writes its config
#
# Conductor is a GUI app you download yourself; CHECKLIST.md walks through it.
#
# Usage:
#   ./install.sh <profile> [--dry-run]
#
#   <profile>   a file in profiles/ without the .env suffix, e.g. m1pro-16gb
#   --dry-run   print every command that would run instead of running it
#
# Safe to re-run. Re-run it after editing a profile (for example to raise
# CONTEXT once `ollama ps` shows the model fully on the GPU).
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCODE_DIR="${HOME}/.config/opencode"
OPENCODE_CONFIG="${OPENCODE_DIR}/opencode.json"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"

usage() {
  echo "usage: $0 <profile> [--dry-run]"
  echo "profiles:"
  for f in "${KIT_DIR}"/profiles/*.env; do
    echo "  $(basename "${f%.env}")"
  done
}

say()  { printf '\n==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

DRY_RUN=0
PROFILE=""
for arg in "$@"; do
  case "${arg}" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "unknown flag: ${arg}" >&2; usage; exit 2 ;;
    *) PROFILE="${arg}" ;;
  esac
done

# Run a command, or print it when --dry-run is set.
run() {
  if [[ ${DRY_RUN} -eq 1 ]]; then
    printf '    $'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

# ---------------------------------------------------------------- profile ----
[[ -n "${PROFILE}" ]] || { usage; exit 2; }
PROFILE_FILE="${KIT_DIR}/profiles/${PROFILE}.env"
[[ -f "${PROFILE_FILE}" ]] || die "no such profile: ${PROFILE} (see profiles/)"
# shellcheck source=/dev/null
source "${PROFILE_FILE}"
for v in MODEL CONTEXT KV_CACHE FALLBACK_MODEL; do
  [[ -n "${!v:-}" ]] || die "profile ${PROFILE} does not set ${v}"
done
# How long Ollama keeps the model in memory after the last request. The
# default is 5 minutes, which means a reload (10-20 s) after every short break.
KEEP_ALIVE="${KEEP_ALIVE:-30m}"

# ------------------------------------------------------------- this mac ----
say "Checking this Mac"
[[ "$(uname -s)" == "Darwin" ]] || die "this kit is for macOS only"
[[ "$(uname -m)" == "arm64" ]]  || die "this kit expects Apple Silicon (arm64), got $(uname -m)"
MEM_GB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
note "$(sysctl -n machdep.cpu.brand_string), ${MEM_GB} GB unified memory"
note "profile ${PROFILE}: model ${MODEL}, context ${CONTEXT}, KV cache ${KV_CACHE}"
[[ ${DRY_RUN} -eq 1 ]] && note "(dry run: nothing below is executed)"

# -------------------------------------------------------------- homebrew ----
say "Checking Homebrew"
if command -v brew >/dev/null 2>&1; then
  note "found $(brew --version | head -1)"
else
  die "Homebrew is not installed. Install it from https://brew.sh and re-run."
fi

# ---------------------------------------------------------------- ollama ----
say "Installing Ollama"
if command -v ollama >/dev/null 2>&1; then
  note "already installed: $(ollama --version 2>/dev/null | head -1 || echo ollama)"
else
  run brew install --cask ollama
fi
if brew list --formula ollama >/dev/null 2>&1; then
  note "WARNING: the Homebrew *formula* 'ollama' is also installed."
  note "         Two servers will fight over port 11434. Remove it with:"
  note "         brew services stop ollama && brew uninstall ollama"
fi

# ------------------------------------------------------ server settings ----
say "Configuring the Ollama server"
note "Ollama defaults to a 4096-token context on machines under 24 GB of VRAM."
note "Coding agents need 32k-64k. These settings apply to the menu-bar app."
run launchctl setenv OLLAMA_CONTEXT_LENGTH "${CONTEXT}"
run launchctl setenv OLLAMA_FLASH_ATTENTION 1
run launchctl setenv OLLAMA_KV_CACHE_TYPE "${KV_CACHE}"
run launchctl setenv OLLAMA_KEEP_ALIVE "${KEEP_ALIVE}"

# --------------------------------------------------------- restart app ----
say "Restarting the Ollama app so it picks up those settings"
if [[ ${DRY_RUN} -eq 1 ]]; then
  note '$ osascript -e '"'"'tell application "Ollama" to quit'"'"
  note '$ open -a Ollama'
  note "(then wait until ${OLLAMA_URL} answers)"
else
  osascript -e 'tell application "Ollama" to quit' >/dev/null 2>&1 || true
  for _ in $(seq 1 20); do
    curl -sf "${OLLAMA_URL}" >/dev/null 2>&1 || break
    sleep 0.5
  done
  open -a Ollama
  for i in $(seq 1 60); do
    if curl -sf "${OLLAMA_URL}" >/dev/null 2>&1; then
      break
    fi
    [[ ${i} -eq 60 ]] && die "Ollama did not start listening on ${OLLAMA_URL} within 60 s"
    sleep 1
  done
  note "server is up: $(curl -s "${OLLAMA_URL}")"
fi

# ------------------------------------------------------------ pull model ----
say "Downloading ${MODEL}"
note "This is several GB and happens once. Models live in ~/.ollama/models."
run ollama pull "${MODEL}"

# -------------------------------------------------------- opencode config ----
say "Writing the OpenCode config"
TEMPLATE="${KIT_DIR}/opencode/opencode.json.template"
[[ -f "${TEMPLATE}" ]] || die "missing ${TEMPLATE}"
RENDERED="$(sed -e "s|__MODEL__|${MODEL}|g" -e "s|__CONTEXT__|${CONTEXT}|g" "${TEMPLATE}")"
if [[ ${DRY_RUN} -eq 1 ]]; then
  note "would write ${OPENCODE_CONFIG}:"
  printf '%s\n' "${RENDERED}" | sed 's/^/    /'
else
  mkdir -p "${OPENCODE_DIR}"
  if [[ -f "${OPENCODE_CONFIG}" ]]; then
    BACKUP="${OPENCODE_CONFIG}.bak.$(date +%Y%m%d-%H%M%S)"
    cp "${OPENCODE_CONFIG}" "${BACKUP}"
    note "existing config backed up to ${BACKUP}"
  fi
  printf '%s\n' "${RENDERED}" > "${OPENCODE_CONFIG}"
  if command -v python3 >/dev/null 2>&1; then
    python3 -I -c 'import json, sys; json.load(open(sys.argv[1]))' "${OPENCODE_CONFIG}" \
      || die "rendered config is not valid JSON: ${OPENCODE_CONFIG}"
  fi
  note "wrote ${OPENCODE_CONFIG}"
fi

# ------------------------------------------------------------- what next ----
say "Done. Next steps"
note "1. ./verify.sh ${PROFILE}    confirms the model answers, measures speed, probes tool calls"
note "2. open CHECKLIST.md         the Conductor steps: download, sign in, pick ollama/${MODEL}"
note ""
note "If 'ollama ps' shows a CPU/GPU split, edit profiles/${PROFILE}.env:"
note "lower CONTEXT, or set MODEL=\"${FALLBACK_MODEL}\", then re-run this script."
