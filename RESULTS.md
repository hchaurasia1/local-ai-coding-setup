# Results

One section per machine. Paste the block that `./verify.sh` prints, then fill
in the rest by hand. These numbers feed the write-up, so be specific.

## MacBook Pro, M1 Pro, 16 GB

**Date:**

**verify.sh output**

```
(paste the "paste into RESULTS.md" block here)
```

**Context length that actually fit on the GPU:** 32k / 64k / other

**Memory pressure during a task (Activity Monitor):** green / yellow / red

**First task**

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
machine:        Apple M1 Pro, 16 GB
date:           2026-10-24
model:          qwen3.5:9b
context (env):  32768
kv cache:       q8_0
speed:          21.5 tok/s generation, 7 tok/s prompt processing, model load 6.7 s
tool call:      CALLED get_weather {"city":"Pune"}
ollama ps:      qwen3.5:9b    d63f830f28d5    7.9 GB    100% GPU     32768      mlx       29 minutes from now    
memory free:    28%
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
