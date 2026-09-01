---
name: create-script-to-install-on-win
description: >-
  Creates or aligns a non-Docker Windows local install script pair under
  scripts/local/<repo_name> that refreshes deps and rebuilds without wiping .env or
  local DB data, then tests it.
disable-model-invocation: false
metadata:
  version: "2.0.0"
  author: Armin Dashti
  category: devops
  tags: [powershell, install, windows, local, native, scripts]
  last_updated: "2026-09-01 09:45:00"
  uuid: 4e662ad8-40f7-4ee0-9f76-923d2ee5613e
---

# Create Script to Install on Win

## When

- User asks for a local (non-Docker) Windows install / refresh / redeploy script
- User asks to create `install-on-win.ps1` / `install-on-win.yaml`
- User names this skill (`create-script-to-install-on-win`)
- Related: `../create-script-for-install-on-local/` (wipe first-time under `scripts/`), `../create-script-to-run-as-hot-reload/`, `C:/Users/armin/GitHub/devmin/skills`
- Exclusions: wipe first-time local install under `scripts/` (use `create-script-for-install-on-local`); Docker update (use update-on-docker-local); hot-reload start only (use run-as-hot-reload)

## How

### Step 1: Require prior local install contract

1. Prefer existing `scripts/install-on-local.yaml` or known api/webui paths for `project_name` and dirs
2. If the project has never been installed and no wipe-install pair exists → stop and point to `create-script-for-install-on-local`
3. Confirm package managers from manifests

### Step 2: Create local install-on-win scripts

Target under `scripts/local/<repo_name>/`:

| Path | Sample |
|------|--------|
| `scripts/local/<repo_name>/install-on-win.ps1` | [samples/install-on-win.ps1](samples/install-on-win.ps1) |
| `scripts/local/<repo_name>/install-on-win.yaml` | [samples/install-on-win.yaml](samples/install-on-win.yaml) |

1. Create `scripts/local/<repo_name>/` if missing
2. If legacy `scripts/update-on-local.*` exist → cut/align into `install-on-win.*`
3. If missing → copy samples, then adapt names, paths, stack commands (paths relative to `scripts/local/<repo_name>/`, typically `../../../…` to repo)
4. Do **not** run this skill’s `samples/` — only project copies
5. Scripts are YAML-only (no CLI `--` flags)

**YAML keys:**

| Key | Rule |
|-----|------|
| `project_name` | Same base name as wipe-install |
| `repo_root` / `api_dir` / `webui_dir` | Relative to `scripts/local/<repo_name>/` |
| `package_manager` | Same as wipe-install |
| `wipe_deps` | **always** `"no"` — keeps `node_modules` / `.venv` and refreshes in place |
| `wipe_local_db` | **always** `"no"` — preserves local DB |
| `env_example` | Optional; never overwrite existing `.env` |

**Runtime (must):**

1. Resolve paths from sibling YAML only
2. Do **not** delete `node_modules`, `.venv`, or local DB
3. Refresh deps (`npm install` / `go mod download` / `pip install -r` / `cargo fetch`)
4. Keep existing `.env`
5. Exit non-zero on failure

### Step 3: Test (required)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\local\<repo_name>\install-on-win.ps1
```

Install-on-win must succeed before claiming done. Fix and retest on failure.

## Always

1. Put the pair under `./scripts/local/<repo_name>/install-on-win.ps1` + `.yaml`.
2. Preserve `.env` and local DB (`wipe_local_db: "no"`, `wipe_deps: "no"`).
3. Test after create/edit.

## Never

1. Create a first-time wipe install when wipe-install scripts are missing — send the user to `create-script-for-install-on-local`.
2. Wipe deps or DB by default.
3. Execute this skill’s `samples/*`.
4. Treat a failed run as success.
5. Use this skill for Docker update or wipe first-time local install.

## Example

**Example 1 — Refresh after code pull**

- Input: “Create install-on-win script”
- Output: `scripts/local/<repo_name>/install-on-win.ps1` + `.yaml` with wipe keys `"no"` → succeeds

**Example 2 — Missing wipe-install pair**

- Input: no prior wipe-install contract
- Output: stop; point to `create-script-for-install-on-local`

**Example 3 — Pair paths from install YAML**

- Input: `scripts/install-on-local.yaml` has `api_dir` / `webui_dir`
- Output: adapt those paths relative to `scripts/local/<repo_name>/` into install-on-win YAML

**Example 4 — Wrong target (Docker)**

- Input: “Create Docker update scripts”
- Output: point to `create-script-to-update-on-docker-local`

**Example 5 — User asks to wipe DB**

- Input: “Install-on-win and wipe local Postgres”
- Output: do not set wipe here; send wipe to `create-script-for-install-on-local` with `wipe_local_db: "yes"` when documented

**Example 6 — Legacy update-on-local**

- Input: project has `scripts/update-on-local.*`
- Output: cut/align to `scripts/local/<repo_name>/install-on-win.*`
