---
name: create-script-to-run-as-hot-reload
description: >-
  Creates a non-Docker run-as-hot-reload.ps1 plus YAML under scripts/local/<repo_name>
  that starts API and WebUI on the host with hot-reload, free ports, and aligned
  CORS or proxy, then tests that the script starts.
disable-model-invocation: false
metadata:
  version: "2.0.0"
  author: Armin Dashti
  category: devops
  tags: [powershell, hot-reload, local, native, scripts, air, vite]
  last_updated: "2026-09-01 09:45:00"
  uuid: cb29dd72-a955-4676-a688-52227494de58
---

# Create Script to Run as Hot Reload

## When

- User asks for a local (non-Docker) hot-reload start script
- User asks to create `run-as-hot-reload.ps1` / `run-as-hot-reload.yaml`
- User names this skill (`create-script-to-run-as-hot-reload`)
- Related: `../create-script-for-install-on-local/`, `../create-script-to-install-on-win/`, `../run-this-app-on-local-machine-hot-reload/` (agent runs without writing scripts), `../run-this-app-on-docker-hot-reload/`
- Exclusions: Docker bind-mount hot-reload; install script generation

## How

### Step 1: Detect pair and stack

1. Prefer paths from existing `scripts/install-on-local.yaml`, `scripts/local/<repo_name>/install-on-win.yaml`, or user-named `<stem>-api` + `<stem>-webui`
2. Detect stacks (`go.mod` + Air, Vite `package.json`, `Cargo.toml` + cargo-watch, uvicorn `--reload`, etc.)
3. If repos are missing on disk, stop and report

### Step 2: Create run-as-hot-reload scripts

Target under `scripts/local/<repo_name>/`:

| Path | Sample |
|------|--------|
| `scripts/local/<repo_name>/run-as-hot-reload.ps1` | [samples/run-as-hot-reload.ps1](samples/run-as-hot-reload.ps1) |
| `scripts/local/<repo_name>/run-as-hot-reload.yaml` | [samples/run-as-hot-reload.yaml](samples/run-as-hot-reload.yaml) |

1. Create `scripts/local/<repo_name>/` if missing
2. If legacy `scripts/run-hot-reload.*` exist → cut/align into `run-as-hot-reload.*`
3. If missing → copy samples, then adapt dirs, ports, start commands (paths relative to `scripts/local/<repo_name>/`)
4. Do **not** run this skill’s `samples/` — only project copies
5. Scripts are YAML-only (no CLI `--` flags)

**YAML keys:**

| Key | Rule |
|-----|------|
| `project_name` | Base name |
| `api_dir` / `webui_dir` | Paths relative to `scripts/local/<repo_name>/` |
| `api_port` / `webui_port` | Preferred host ports; script picks next free if busy |
| `api_command` | Prefer Air / cargo-watch / `npm run dev` / uvicorn `--reload` |
| `webui_command` | Prefer Vite `dev --host 0.0.0.0 --port <port> --strictPort` |
| `cors_origin` | Optional; empty = derive from webui port |
| `pid_file` | Default `run-as-hot-reload.pids` under `scripts/local/<repo_name>/` |

**Port bands (when preferred busy):**

| Role | Band |
|------|------|
| API | `8171–8302` |
| WebUI | `5173–5299` (Vite) else `8080–8169` |

**Runtime (must):**

1. Read sibling YAML only
2. Check host listeners; never bind `1–1023` or a busy port; never kill unrelated processes
3. Align WebUI proxy / `VITE_*` / API CORS to chosen ports when supported
4. Start API then WebUI as **host** background processes
5. Write PIDs to `pid_file`; print URLs and stop instructions
6. Exit non-zero if either process fails to start

### Step 3: Test (required)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\local\<repo_name>\run-as-hot-reload.ps1
```

Confirm API and WebUI listen (or report hot-reload OFF when a watch tool is missing). Stop started PIDs after smoke check unless the user asked to leave them running.

## Always

1. Put the pair under `./scripts/local/<repo_name>/run-as-hot-reload.ps1` + `.yaml`.
2. Keep API and WebUI as host processes in the generated script.
3. Smoke-test that the script starts (then stop unless asked to leave up).

## Never

1. Default the generated script to Docker for API/WebUI.
2. Bind a busy or privileged port, or kill unrelated processes to free a port.
3. Execute this skill’s `samples/*`.
4. Invent secrets or overwrite a filled `.env`.
5. Treat a failed start as success.

## Example

**Example 1 — Go + Vite pair**

- Input: “Create run-as-hot-reload.ps1 for radar”
- Output: `scripts/local/<repo_name>/run-as-hot-reload.ps1` + `.yaml` → smoke start succeeds

**Example 2 — Preferred port busy**

- Input: YAML prefers `5173` but it is listening
- Output: script picks next free in `5173–5299`

**Example 3 — Air missing**

- Input: Go API; `air` not on PATH
- Output: fallback to `go run`; prints hot-reload OFF for API

**Example 4 — Wrong target (Docker hot-reload)**

- Input: “Create Docker hot-reload scripts”
- Output: point to `run-this-app-on-docker-hot-reload`

**Example 5 — Install missing**

- Input: no `node_modules` / no go modules
- Output: tell user to run wipe-install / install-on-win first; still may create the run scripts

**Example 6 — Legacy run-hot-reload**

- Input: project has `scripts/run-hot-reload.*`
- Output: cut/align to `scripts/local/<repo_name>/run-as-hot-reload.*`
