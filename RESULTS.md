# Results

One section per machine. The measured blocks come from `./verify.sh`; the
rest is filled in by hand. These numbers feed the write-up, so be specific.

## MacBook Pro, M1 Pro, 16 GB

**Date:** 2026-10-24

**verify.sh at 32k context** (`results/m1pro-16gb/results-32k`)

```
machine:        Apple M1 Pro, 16 GB
model:          qwen3.5:9b
context (env):  32768
kv cache:       q8_0
model load:     4.5 s
speed:          20.4 tok/s generation, 179 tok/s prompt processing (1363-token prompt)
tool call:      CALLED get_weather {"city":"Pune"}
ollama ps:      qwen3.5:9b    d63f830f28d5    8.1 GB    100% GPU     32768      mlx
memory free:    29%
```

**verify.sh at 64k context** (`results/m1pro-16gb/results-64k`)

```
machine:        Apple M1 Pro, 16 GB
model:          qwen3.5:9b
context (env):  65536
context (server): 65536
kv cache:       q8_0
model load:     0.0 s (already in memory)
speed:          20.3 tok/s generation, 179 tok/s prompt processing (1362-token prompt)
tool call:      CALLED get_weather {"city":"Pune"}
ollama ps:      qwen3.5:9b    d63f830f28d5    8.2 GB    100% GPU     65536      mlx
memory free:    33%
```

**Context length that actually fit on the GPU:** 64k. Going from 32k to 64k
grew the loaded model from 8.1 GB to 8.2 GB and stayed 100% on the GPU.
Qwen3.5 uses a hybrid attention design whose per-token cache is small, so
the context window is nearly free on this model. Ollama ran it on its MLX
runner.

**Things that went wrong on the way**

- The very first verify reported 7 tok/s prompt processing. That was a
  measurement artifact from a 12-token prompt; the script now uses a
  ~1,360-token prompt and reports ~179 tok/s.
- Setting `OLLAMA_CONTEXT_LENGTH` with `launchctl setenv` worked for the
  first value (32k) but changing it to 64k did nothing: the Ollama menu-bar
  app has its own context slider and that setting wins once stored. The fix
  was moving the slider in the app's Settings. The kit now detects this.
- The AppleScript quit of the Ollama app is ignored; a forced stop works, but
  the relaunch took longer than the script's 60 s wait once.

**Memory pressure during a task (Activity Monitor):** green / yellow / red

**First task in Conductor**

- Repo:
- Prompt I gave it:
- Time for the first response:
- Number of turns until done (or until I gave up):
- What it got right:
- What it got wrong:
- Did Conductor's diff view and PR flow work as expected?

**Would I use this for real work?** One or two honest sentences.

**Screenshots:** `results/m1pro-16gb/`

## MacBook Pro, M3 Pro, 36 GB

**Date:**

**verify.sh output**

```
(paste here)
```

**Context length that actually fit on the GPU:**

**Memory pressure during a task:**

**First task**

- Repo:
- Prompt I gave it:
- Time for the first response:
- Number of turns until done:
- What it got right:
- What it got wrong:

**Compared with the 16 GB machine:** what changed, in plain terms.

**Screenshots:** `results/m3pro-36gb/`
