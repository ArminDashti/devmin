---
name: create-ps-script-for-local-windows
description: >-
  Prepares local Windows settings in the target repo, dual-writes
  install/remove/update/reinstall PowerShell + YAML pairs under
  devmin/deploy/<project>/local/ and <project>/.armin/deploy/local/, chooses
  free safe ports, then upserts devmin/deploy/status.md.
disable-model-invocation: false
metadata:
  version: "1.3.0"
  author: Armin Dashti
  category: devops
  tags: [powershell, local-windows, install, remove, update, reinstall, deploy, ports, dual-write]
  last_updated: "2026-09-04 15:42:00"
  uuid: ac3bc455-97e5-43d5-aba4-e752616b20df
---

# Create PS Script for Local Windows

## When

- User asks for local Windows native deploy scripts (install / remove / update / reinstall)
- User names this skill (`create-ps-script-for-local-windows`)
- Related: `../create-ps-script-for-local-docker/`, `../create-ps-script-for-cloudflare/`, `../create-ps-script-port-selection.md`, `../../skills/create-script/`, `../../skills/REFERENCE.md`
- Exclusions: Docker local/server channels; Cloudflare Workers

## How

### Step 0: Require project

1. If the user did not name the **project** (GitHub folder under `C:/Users/armin/GitHub`), stop and ask once
2. `project` = folder name (e.g. `devmin`, `asip`); `target_repo` = `C:/Users/armin/GitHub/<project>`
3. Inspect `target_repo` for API/WebUI/desktop layout and package managers

### Step 0b: Allocate free safe ports (required)

1. Follow [create-ps-script-port-selection.md](../create-ps-script-port-selection.md) fully
2. Read `devmin/deploy/status.md` for ports already claimed by other projects
3. Check listening TCP ports on this machine
4. Assign `api_port` (8100–8999), `webui_port` (5100–5999), `postgres_port` (5400–5499) — first free in each band
5. If the user named explicit ports, use them only when free; otherwise re-pick and tell the user
6. Confirm chosen ports in chat before finishing

### Step 0c: Prepare settings and params in the target repo

1. Ensure `.armin/state` exists under `target_repo` (scripts use it for pid/state files)
2. If an API `.env.example` exists and `.env` is missing, copy `.env.example` → `.env` (do not invent secrets)
3. Fill YAML keys the samples need: `project_name`, `target_repo`, `api_dir`, `webui_dir`, `stack_name`, `api_port`, `webui_port`, `postgres_port`, `state_dir`, `postgres_container`, `postgres_volume`
4. Ask before any package install (user install rule)

### Step 1: Dual-write output paths

Write the **same** eight files into **both** trees (create folders if missing):

| Tree | Path |
|------|------|
| Devmin | `devmin/deploy/<project>/local/` |
| Target | `<project>/.armin/deploy/local/` |

| File | Sample |
|------|--------|
| `install-on-local-windows.ps1` | [samples/install-on-local-windows.ps1](samples/install-on-local-windows.ps1) |
| `install-on-local-windows.yaml` | [samples/install-on-local-windows.yaml](samples/install-on-local-windows.yaml) |
| `remove-on-local-windows.ps1` | [samples/remove-on-local-windows.ps1](samples/remove-on-local-windows.ps1) |
| `remove-on-local-windows.yaml` | [samples/remove-on-local-windows.yaml](samples/remove-on-local-windows.yaml) |
| `update-on-local-windows.ps1` | [samples/update-on-local-windows.ps1](samples/update-on-local-windows.ps1) |
| `update-on-local-windows.yaml` | [samples/update-on-local-windows.yaml](samples/update-on-local-windows.yaml) |
| `reinstall-on-local-windows.ps1` | [samples/reinstall-on-local-windows.ps1](samples/reinstall-on-local-windows.ps1) |
| `reinstall-on-local-windows.yaml` | [samples/reinstall-on-local-windows.yaml](samples/reinstall-on-local-windows.yaml) |

1. Copy samples; adapt names/paths; write the **chosen** ports into every YAML sibling in **both** trees
2. YAML may differ only for path relativity (`target_repo` absolute in the devmin copy; target copy may use repo-relative roots). Ports and behavior keys stay identical
3. Scripts are YAML-only (no CLI `--` flags)
4. Do not execute this skill’s `samples/` — only the dual-written project copies
5. Reinstall calls sibling remove then install from `$PSScriptRoot` (works in either tree)

### Step 2: Runtime contract

| Script | Behavior |
|--------|----------|
| Install | If already installed (pid files alive) **or** any YAML host port is listening, **error**. Otherwise install deps, start on YAML ports, write state |
| Remove | **Complete teardown:** stop app via pid files **and** kill any listeners on YAML `api_port` / `webui_port` / `postgres_port` until those ports are free; delete state; **if** the named Postgres container and/or volume exist, remove them (no-op when absent). Do not leave orphan listeners or DB volumes |
| Update | Refresh deps and restart on the **same** YAML ports; keep `.env` and database data |
| Reinstall | Must fully tear down then install: call `remove-on-local-windows.ps1` then `install-on-local-windows.ps1` from `$PSScriptRoot`. Because remove is complete teardown, reinstall **always** removes the current app, releases its ports, and removes its DB when it exists before a clean install |

**YAML keys (typical):** `project_name`, `target_repo`, `api_dir`, `webui_dir`, `stack_name`, `api_port`, `webui_port`, `postgres_port`, `state_dir`, `postgres_container`, `postgres_volume`

### Step 3: Status registry

Upsert a row for this project/channel in `devmin/deploy/status.md` with the allocated ports, stack name, both script folders, and channel `local`.

## Always

1. Dual-write all eight files to both `devmin/deploy/<project>/local/` and `<project>/.armin/deploy/local/`.
2. Prepare target-repo settings (Step 0c) before writing scripts.
3. Keep Update and Reinstall distinct (update preserves data; reinstall tears down then installs).
4. On Remove / Reinstall: free every YAML host port (`api_port`, `webui_port`, `postgres_port`) and remove the named Postgres container/volume when they exist.

## Never

1. Invent a project name when the user did not provide one.
2. Hard-code `80`/`443`/`8080`/`3000`/`5173`/`5432` without a free-port check.
3. Wipe database or `.env` on update.
4. Duplicate remove/install logic inside reinstall instead of calling the sibling scripts.
5. Write only under `devmin-api/deploy/scripts/` or skip the target `.armin/deploy/local/` tree.
6. Write these scripts into legacy `scripts/local/` for this skill.
7. Leave YAML ports listening or leave the named Postgres volume after remove/reinstall.

## Example

**Example 1 — Full set with auto ports**

- Input: “Create local Windows scripts for `devmin`”
- Output: free ports in both `devmin/deploy/devmin/local/` and `devmin/.armin/deploy/local/` YAMLs + `devmin/deploy/status.md` row

**Example 2 — Missing project**

- Input: “Create local Windows install scripts”
- Output: ask which project under `C:/Users/armin/GitHub`; stop

**Example 3 — User port busy**

- Input: “Use api port 8195” but 8195 is listening
- Output: pick next free in 8100–8999; tell the user the substitute; write substitute into both trees

**Example 4 — Install when port taken**

- Input: agent tests install while `api_port` is listening
- Output: script exits non-zero (port conflict / already installed)

**Example 5 — Wrong channel**

- Input: “Local Docker scripts for asip”
- Output: do not use this skill; route to `create-ps-script-for-local-docker`

**Example 6 — Reinstall teardown**

- Input: “Reinstall must wipe the running app”
- Output: `reinstall-on-local-windows.ps1` calls remove then install; remove stops pid-tracked processes, kills listeners on YAML ports until free, and removes Postgres container/volume when they exist
