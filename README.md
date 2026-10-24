# local-ai-coding-setup

Run a coding agent on a Mac for free, with no API key and nothing leaving the
machine. Two scripts, one checklist, and a results file so the numbers are
real.

## The stack

| Layer | Tool | What it does |
|---|---|---|
| Model | [Qwen](https://ollama.com/library/qwen3.5) | Open-weight model from Alibaba that supports tool calls |
| Model server | [Ollama](https://ollama.com) | Downloads the model, runs it on the GPU, serves it on `localhost:11434` |
| Agent | [OpenCode](https://opencode.ai) | Turns the model into a coding agent: reads files, edits, runs commands |
| Workspaces | [Conductor](https://conductor.build) | One git worktree and branch per task, diff review, PRs |

Conductor bundles OpenCode. OpenCode talks to Ollama over HTTP exactly as it
would talk to a cloud provider. Ollama runs the model. Nothing in this chain
costs money.

## Hardware

The model and its context window both have to fit in GPU memory, which on
Apple Silicon is a slice of the unified memory. Rough budgets:

| Machine | Usable for the model | Profile | Model | Context |
|---|---|---|---|---|
| M1 Pro, 16 GB | ~10-11 GB | `m1pro-16gb` | `qwen3.5:9b` (~7 GB) | 32k, try 64k |
| M3 Pro, 36 GB | ~26-27 GB | `m3pro-36gb` | `qwen3-coder:30b` (~19 GB) | 64k |

Below 16 GB a local coding agent is not practical. Ollama's default context is
4096 tokens, which is useless for agent work; the install script raises it.

## Quick start

```sh
git clone https://github.com/hchaurasia1/local-ai-coding-setup.git
cd local-ai-coding-setup

./install.sh m1pro-16gb          # Ollama + model + OpenCode config
./verify.sh  m1pro-16gb          # does it answer, how fast, can it call tools
open CHECKLIST.md                # the Conductor steps
```

Add `--dry-run` to `install.sh` to see every command before it runs, and
`--config-only` to rewrite just the OpenCode config against the running server.

## What is in here

```
install.sh                  install Ollama, set server env, pull model, write OpenCode config
verify.sh                   read-only checks; prints a block for RESULTS.md
profiles/*.env              model, context length and KV-cache type per machine
opencode/opencode.json.template   rendered to ~/.config/opencode/opencode.json
CHECKLIST.md                the manual Conductor steps and a troubleshooting table
RESULTS.md                  what actually happened on each machine
results/<profile>/          screenshots
```

## Things worth knowing

- `install.sh` overwrites `~/.config/opencode/opencode.json` after backing up
  the old one next to it. If you already use OpenCode with other providers,
  merge by hand instead.
- The Ollama menu-bar app has its own context-length setting (llama icon,
  Settings). `install.sh` sets `OLLAMA_CONTEXT_LENGTH` with `launchctl setenv`,
  which the app honours on a fresh install, but once the app has stored a
  value of its own that value wins. So the script checks what the server
  actually runs after every change and, if it differs, tells you to move the
  slider and re-run with `--config-only`. On an M1 Pro this is exactly what
  happened going from 32k to 64k.
- `launchctl setenv` values last for the current login session. After a
  reboot, run `./verify.sh` and re-run `install.sh` if it complains.
- `OLLAMA_KV_CACHE_TYPE=q8_0` halves the memory the context window takes. It
  needs flash attention, which the script also turns on.
- A 9B model is a long way from a frontier model. Expect slower turns, the
  occasional wrong file, and the need to keep tasks small. That is the trade
  for free.

## Status

- [ ] M1 Pro, 16 GB: pending
- [ ] M3 Pro, 36 GB: pending

Results land in `RESULTS.md` as they happen.
