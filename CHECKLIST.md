# Checklist: from a fresh Mac to a working local coding agent

Do these in order. Steps 1-2 are scripted; the rest are clicks in Conductor.

## 1. Model server and model

```sh
./install.sh m1pro-16gb      # or m3pro-36gb
```

What it does: installs Ollama via Homebrew, sets the context length and KV
cache for the Ollama app, restarts the app, downloads the model, and writes
`~/.config/opencode/opencode.json` pointing OpenCode at it.

## 2. Prove the model works before touching Conductor

```sh
./verify.sh m1pro-16gb
```

All of these should pass:

- the server answers on `localhost:11434`
- the model appears in `/v1/models`
- a short completion returns with a tokens-per-second number
- the tool-call probe reports `CALLED get_weather`
- `ollama ps` shows `100% GPU`

If the tool-call probe says the model answered in prose, the model will not
work as an agent. Try the fallback model in the profile.

## 3. Conductor

1. Download Conductor from <https://conductor.build> and open it.
2. Sign in with GitHub when prompted.
3. Add a repository. Any repo you can push to is fine; a small one is better
   for a first run.
4. Open **Settings -> Agents -> OpenCode**. Conductor bundles OpenCode, so there
   is nothing to install. The model list should include
   `ollama/qwen3.5:9b` (or whatever `MODEL` your profile sets). Conductor
   builds that list by asking OpenCode which providers are configured, so if it
   is missing, see Troubleshooting below.
5. Create a new workspace. Pick **OpenCode** as the agent and `ollama/<model>`
   as the model.

## 4. First task

Keep it small and specific. Good first prompts:

- "Add a unit test for `<function>` in `<file>` covering the empty-input case."
- "Explain what `<file>` does in five sentences."
- "Rename `<oldName>` to `<newName>` in `<file>` and update its callers."

While it runs, keep a terminal open with `ollama ps` and Activity Monitor on
the Memory tab. Note how long a turn takes and whether memory pressure goes
yellow or red.

Review the diff in Conductor before doing anything with it. A 9B model will
sometimes edit the wrong file or invent an import; that is normal and part of
what you are here to learn.

## 5. Record what happened

Fill in `RESULTS.md` using the block that `verify.sh` prints, plus your own
notes from the first task. Drop screenshots in `results/<profile>/`.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Model missing from Conductor's OpenCode picker | Ollama not running, or `opencode.json` invalid | Check the llama icon in the menu bar; run `./verify.sh`; `python3 -m json.tool ~/.config/opencode/opencode.json` |
| `ollama ps` shows e.g. `40%/60% CPU/GPU` | Weights plus context do not fit in GPU memory | Lower `CONTEXT` in the profile or set `MODEL` to `FALLBACK_MODEL`, re-run `./install.sh` |
| Tool calls come back garbled or as prose mid-task | Context overflowed | Raise `CONTEXT` if `ollama ps` is at 100% GPU; otherwise use a smaller model |
| OpenCode asks for an API key | `small_model` not set, so it reached for a cloud provider | Re-run `./install.sh`; the template sets `small_model` to the local model |
| First reply after a break takes 10-20 s | Model was unloaded from memory | Expected. `install.sh` sets `OLLAMA_KEEP_ALIVE=30m`; raise it if you like |
| `./verify.sh` warns `OLLAMA_CONTEXT_LENGTH` is not set | Env was set but the app was not restarted | Quit Ollama from the menu bar and reopen it, or re-run `./install.sh` |
| Everything is slow and the fans are loud | Another app is holding memory | Close browsers and editors you are not using; check Activity Monitor |
