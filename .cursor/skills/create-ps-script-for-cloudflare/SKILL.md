---
name: create-ps-script-for-cloudflare
description: >-
  Prepares Cloudflare Worker settings in the target repo, dual-writes
  install/remove/update/reinstall PowerShell + YAML pairs under
  devmin/deploy/<project>/cloudflare/ and <project>/.armin/deploy/cloudflare/,
  learned from asip, then upserts devmin/deploy/status.md.
disable-model-invocation: false
metadata:
  version: "1.1.0"
  author: Armin Dashti
  category: devops
  tags: [powershell, cloudflare, workers, wrangler, d1, install, remove, update, reinstall, dual-write]
  last_updated: "2026-09-04 14:54:00"
  uuid: 96f37363-2d15-44fc-92d2-3debb5048888
---

# Create PS Script for Cloudflare

## When

- User asks for Cloudflare Workers deploy scripts (install / remove / update / reinstall)
- User names this skill (`create-ps-script-for-cloudflare`)
- Related: `../create-ps-script-for-local-windows/`, `../create-ps-script-for-local-docker/`, `C:/Users/armin/.cursor/skills/deploy-on-cloudflare/`, `C:/Users/armin/.cursor/skills/update-cloudflare-workers-after-task/`, `../../skills/create-script/`, `../../skills/REFERENCE.md`
- Exclusions: local Windows; local Docker; custom domains outside workers.dev unless the project already uses them

## How

### Step 0: Require project

1. If the user did not name the **project**, stop and ask once
2. `target_repo` = `C:/Users/armin/GitHub/<project>`
3. Discover Worker roots (`wrangler.toml` / `wrangler.json` / `wrangler.jsonc`) under `target_repo`
4. Use **asip** as the reference shape when adapting samples:
   - API: `asip-api/cloudflare/` — Worker `asip-api`, D1 `asip`, `npm run deploy`, `db:migrate`
   - WebUI: `asip-webui/` — Worker `asip`, `[assets] directory = "./dist"`, SPA handling
   - URLs: `https://<name>.armindashti.workers.dev`
   - Order: API migrate+deploy first, then WebUI build+deploy

### Step 0c: Prepare settings and params in the target repo

1. Align YAML with existing `wrangler.toml` / `wrangler.json*` — do **not** invent Worker names
2. Record Worker roots/names, D1 name/id, public URLs, build commands, and narrow `assets.directory` (e.g. `dist`, never repo root / `src` / `node_modules`)
3. Ensure Wrangler configs in the target already use a shrunk upload set; fix `assets.directory` / `.assetsignore` in the target when too wide
4. Ask before `npm install` (user install rule)

### Step 1: Dual-write output paths

Write the **same** eight files into **both** trees (create folders if missing):

| Tree | Path |
|------|------|
| Devmin | `devmin/deploy/<project>/cloudflare/` |
| Target | `<project>/.armin/deploy/cloudflare/` |

| File | Sample |
|------|--------|
| `install-on-cloudflare.ps1` | [samples/install-on-cloudflare.ps1](samples/install-on-cloudflare.ps1) |
| `install-on-cloudflare.yaml` | [samples/install-on-cloudflare.yaml](samples/install-on-cloudflare.yaml) |
| `remove-on-cloudflare.ps1` | [samples/remove-on-cloudflare.ps1](samples/remove-on-cloudflare.ps1) |
| `remove-on-cloudflare.yaml` | [samples/remove-on-cloudflare.yaml](samples/remove-on-cloudflare.yaml) |
| `update-on-cloudflare.ps1` | [samples/update-on-cloudflare.ps1](samples/update-on-cloudflare.ps1) |
| `update-on-cloudflare.yaml` | [samples/update-on-cloudflare.yaml](samples/update-on-cloudflare.yaml) |
| `reinstall-on-cloudflare.ps1` | [samples/reinstall-on-cloudflare.ps1](samples/reinstall-on-cloudflare.ps1) |
| `reinstall-on-cloudflare.yaml` | [samples/reinstall-on-cloudflare.yaml](samples/reinstall-on-cloudflare.yaml) |

1. Copy samples; set Worker roots, names, D1 name/id, build commands, public URLs in every YAML sibling in **both** trees
2. YAML may differ only for path relativity (`target_repo` absolute in the devmin copy; target copy may use repo-relative Worker roots). Worker/D1/URL keys stay identical
3. YAML-only; do not run this skill’s `samples/`
4. Reinstall calls sibling remove then install from `$PSScriptRoot` (works in either tree)

### Step 2: Runtime contract

| Script | Behavior |
|--------|----------|
| Install | If any Worker named in YAML already exists remotely, **error**. Else shrink upload set, apply D1 migrations when configured, `npx wrangler deploy` per root (API then WebUI) |
| Remove | `wrangler delete` each Worker; delete project-owned D1 named in YAML (data gone) |
| Update | Build if needed + `wrangler deploy` only; **keep D1 data** |
| Reinstall | Call `remove-on-cloudflare.ps1` then `install-on-cloudflare.ps1` |

**Upload shrink (required):** `assets.directory` must be a narrow build output (e.g. `dist`), never repo root / `src` / `node_modules`.

**YAML keys:** `target_repo`, `api_worker_root`, `api_worker_name`, `webui_worker_root`, `webui_worker_name`, `d1_database_name`, `d1_database_id`, `api_url`, `webui_url`, `workers_dev_suffix`

### Step 3: Status registry

Upsert `devmin/deploy/status.md` with Worker names, public URLs, D1 name, both script folders, channel `cloudflare`.

## Always

1. Dual-write all eight files to both `devmin/deploy/<project>/cloudflare/` and `<project>/.armin/deploy/cloudflare/`.
2. Prepare target-repo Worker/D1 settings before writing scripts.
3. Deploy API before WebUI when both exist.
4. Prefer `npx wrangler` from each Worker root.

## Never

1. Upload the whole repo as assets.
2. Delete D1 on update.
3. Invent Worker names that do not match `wrangler.toml`.
4. Write only under `devmin-api/deploy/scripts/` or skip the target `.armin/deploy/cloudflare/` tree.
5. Run live remove against production without the user asking to execute remove.

## Example

**Example 1 — asip**

- Input: “Create Cloudflare scripts for `asip`”
- Output: scripts under both `devmin/deploy/asip/cloudflare/` and `asip/.armin/deploy/cloudflare/` with Workers `asip-api` + `asip`, D1 `asip`, URLs on `armindashti.workers.dev`

**Example 2 — Missing project**

- Input: “Cloudflare install scripts”
- Output: ask for project; stop

**Example 3 — Already deployed**

- Input: install when Workers exist
- Output: non-zero “already installed”

**Example 4 — Update keeps D1**

- Input: update after code change
- Output: wrangler deploy only; no D1 delete

**Example 5 — Reinstall**

- Input: reinstall
- Output: remove sibling then install sibling
