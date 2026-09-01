---
name: create-script-for-install-on-local
description: >-
  Creates a first-time non-Docker local install script pair under scripts/
  that wipes this project’s local deps and optional local DB data, then
  installs clean and tests the script.
disable-model-invocation: false
metadata:
  version: "1.0.0"
  author: Armin Dashti
  category: devops
  tags: [powershell, install, local, native, scripts, wipe]
  last_updated: "2026-08-26 12:28:32"
  uuid: 83277eda-7024-46a3-b7b3-e30e5b75c99e
---

# Create Script for Install on Local

## When

- User asks for a first-time local (non-Docker) install script
- User asks to create `install-on-local.ps1` / `install-on-local.yaml`
- User names this skill (`create-script-for-install-on-local`)
- Related: `../create-script-to-install-on-win/`, `../create-script-to-run-as-hot-reload/`, `C:/Users/armin/GitHub/devmin/skills`
- Exclusions: Docker install (use docker-by-armin install-on-docker-local); update of an already-installed local project (use update-on-local); starting hot-reload (use run-hot-reload)

## How

Fixed order: Detect → Scripts under `scripts/` → Test.

### Step 1: Detect project

| Signal | Use |
|--------|-----|
| `go.mod` / `package.json` / `Cargo.toml` / `requirements.txt` / `*.csproj` | Stack and install commands |
| Sibling `<stem>-api` + `<stem>-webui` | Pair paths when user named a pair |
| Existing `.env.example` | Copy to `.env` on install when `.env` missing |

Confirm `project_name`, repo root(s), package manager, and whether a local DB wipe is allowed.

### Step 2: Create local install scripts

Target under repo-root `scripts/`:

| Path | Sample |
|------|--------|
| `scripts/install-on-local.ps1` | [samples/install-on-local.ps1](samples/install-on-local.ps1) |
| `scripts/install-on-local.yaml` | [samples/install-on-local.yaml](samples/install-on-local.yaml) |

1. Create `scripts/` if missing
2. If missing → copy samples, then adapt names, paths, stack commands
3. Do **not** run this skill’s `samples/` — only project copies
4. Scripts are YAML-only (no CLI `--` flags)
5. **Fresh wipe (required):** before install, remove this project’s local deps dirs listed in YAML (`node_modules`, `.venv`, `vendor`, `bin`, build outs) and optionally wipe local DB when `wipe_local_db: "yes"`. Do not touch Docker volumes or other projects.

**YAML keys (local install):**

| Key | Rule |
|-----|------|
| `project_name` | Base name (strip `-api` / `-webui` suffixes when a pair) |
| `repo_root` | `.` relative to `scripts/` (usually `..`) |
| `api_dir` / `webui_dir` | Paths relative to `scripts/`; empty if single-repo |
| `package_manager` | `npm` / `pnpm` / `yarn` / `go` / `pip` / `cargo` (comma-list OK for pairs) |
| `wipe_deps` | **always** `"yes"` on install |
| `wipe_local_db` | `"yes"` only when project has a documented local wipe/migrate-reset; else `"no"` |
| `env_example` | Path to `.env.example` relative to `scripts/`; empty if none |
| `install_commands` | Optional override; one shell line per stack step (semicolon-separated in YAML value, or adapt script) |

**Install script runtime (must):**

1. Resolve paths from sibling YAML only
2. Stop any leftover host processes this project started (PIDs file under `scripts/` if present) — do not kill unrelated apps
3. Wipe listed dep/build dirs when `wipe_deps` is yes
4. Wipe/reset local DB only when `wipe_local_db` is yes and a project-documented command exists
5. Copy `.env.example` → `.env` when example exists and `.env` is missing (never overwrite a filled `.env` with blanks)
6. Run install commands for detected stacks (`npm install`, `go mod download`, `pip install -r …`, etc.)
7. Print success paths; exit non-zero on failure

### Step 3: Test (required)

From the target repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-on-local.ps1
```

Install must succeed before claiming done. Fix and retest on failure.

## Always

1. Put the pair under `./scripts/install-on-local.ps1` + `.yaml`.
2. Keep `wipe_deps: "yes"` on install YAML.
3. Test local install after create/edit.

## Never

1. Use Docker compose / image wipe as this skill’s path (point to docker install skill).
2. Add CLI `--` flags; change behavior only via YAML.
3. Execute this skill’s `samples/*`.
4. Treat a failed install as success.
5. Wipe another project’s folders or invent DB wipe commands with no project docs.
6. Overwrite an existing filled `.env` with empty values.

## Example

**Example 1 — New Go API + Vite WebUI pair**

- Input: “Create local install scripts for radar”
- Output: `scripts/install-on-local.ps1` + `.yaml` with `wipe_deps: "yes"`, api/webui paths → wipe `node_modules` / download modules → install succeeds

**Example 2 — Single Python API repo**

- Input: “Create install-on-local.ps1”
- Output: YAML with `webui_dir: ""`, wipe `.venv` when configured, recreate venv + `pip install -r requirements.txt`

**Example 3 — Re-run install**

- Input: user runs `scripts/install-on-local.ps1` again
- Output: wipe deps dirs again → fresh install; `.env` kept if already present

**Example 4 — Wrong target (Docker)**

- Input: “Create Docker install scripts”
- Output: do not use this skill; point to `create-script-to-install-on-docker-local`

**Example 5 — Update ask**

- Input: “Create update scripts without wiping DB”
- Output: do not use this skill; point to `create-script-to-install-on-win`
