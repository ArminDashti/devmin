---
name: create-script
description: >-
  Routes deploy-script authoring for a named GitHub repo into devmin
  scripts/docker/<repo_name> and scripts/local/<repo_name>.
disable-model-invocation: false
metadata:
  version: "1.0.0"
  author: Armin Dashti
  category: devops
  tags: [devmin, scripts, docker, local, router]
  last_updated: "2026-09-01 09:45:00"
  uuid: a1b2c3d4-e5f6-4789-a012-3456789abcde
---

# Create Script (router)

## When

- User asks to create install/update/remove/reinstall/export/hot-reload scripts for a repo
- User names `create-script` or any `create-script-to-*` skill under devmin
- Related: [REFERENCE.md](../REFERENCE.md) for paths; sibling skills under `C:/Users/armin/GitHub/devmin/skills/create-script-to-*/`

## How

1. Resolve **repo name** — folder under `C:/Users/armin/GitHub`. If missing, ask once and stop.
2. Classify the ask:

| User intent | Skill folder |
|-------------|--------------|
| Local Docker install (wipe) | `create-script-to-install-on-docker-local` |
| Local Docker update | `create-script-to-update-on-docker-local` |
| Local Docker remove | `create-script-to-remove-on-docker-local` |
| Local Docker reinstall | `create-script-to-reinstall-on-docker-local` |
| Server Docker install | `create-script-to-install-on-docker-server` |
| Server Docker update | `create-script-to-update-on-docker-server` |
| Server Docker remove | `create-script-to-remove-on-docker-server` |
| Server Docker reinstall | `create-script-to-reinstall-on-docker-server` |
| Windows / native install | `create-script-to-install-on-win` or `create-script-for-install-on-local` |
| Windows reinstall | `create-script-to-reinstall-on-win` |
| Hot reload runner | `create-script-to-run-as-hot-reload` |
| Export desktop exe | `create-script-to-export-exe` |

3. Read and follow the matched skill’s `SKILL.md` fully.
4. Write outputs only under:
   - `scripts/docker/<repo_name>/` for Docker channel scripts
   - `scripts/local/<repo_name>/` for native/local channel scripts

## Always

1. Ask for `repo_name` when the user did not name the target repo.
2. Keep Dockerfile and compose in the **target** repo; store PowerShell + YAML pairs in devmin `scripts/`.
3. Set YAML `target_repo` to the absolute target path.

## Never

1. Write deploy scripts into `.armin/scripts/` on the target repo (legacy — use devmin `scripts/` instead).
2. Invent `stack_name` without user confirmation.

## Example

**Example 1 — Docker local install**

- Input: “Create local Docker install scripts for radar-api”
- Output: route → `create-script-to-install-on-docker-local` → `devmin/scripts/docker/radar-api/install-on-docker-local.ps1` + `.yaml`

**Example 2 — Missing repo**

- Input: “Create update scripts”
- Output: ask which `repo_name` under `C:/Users/armin/GitHub`

**Example 3 — Wrong channel**

- Input: “Server Docker install for helix-api”
- Output: route → `create-script-to-install-on-docker-server`

**Example 4 — Native Windows**

- Input: “Install script for my Windows app in parkiroid”
- Output: route → `create-script-to-install-on-win` → `scripts/local/parkiroid/`

**Example 5 — Full set**

- Input: “All docker scripts for devmin”
- Output: run install/update/remove/reinstall for local and server into `scripts/docker/devmin/`
