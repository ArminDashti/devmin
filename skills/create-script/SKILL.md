---
name: create-script
description: >-
  Routes deploy-script authoring for a named GitHub repo into
  create-ps-script-for-* (devmin-api/deploy/scripts) or legacy create-script-to-*
  (scripts/docker and scripts/local).
disable-model-invocation: false
metadata:
  version: "1.1.0"
  author: Armin Dashti
  category: devops
  tags: [devmin, scripts, docker, local, cloudflare, router]
  last_updated: "2026-09-04 13:20:00"
  uuid: a1b2c3d4-e5f6-4789-a012-3456789abcde
---

# Create Script (router)

## When

- User asks to create install/update/remove/reinstall/export/hot-reload scripts for a repo
- User names `create-script`, any `create-ps-script-for-*` under `.cursor/skills/`, or any `create-script-to-*` under `skills/`
- Related: [REFERENCE.md](../REFERENCE.md); `.cursor/skills/create-ps-script-for-*`; `create-script-to-*`

## How

1. Resolve **project / repo name** — folder under `C:/Users/armin/GitHub`. If missing, ask once and stop.
2. Classify the ask:

| User intent | Skill folder | Output root |
|-------------|--------------|-------------|
| Full local Windows set (install/remove/update/reinstall) | `.cursor/skills/create-ps-script-for-local-windows` | `devmin-api/deploy/scripts/<project>/` |
| Full local Docker set | `.cursor/skills/create-ps-script-for-local-docker` | `devmin-api/deploy/scripts/<project>/` |
| Full Cloudflare set | `.cursor/skills/create-ps-script-for-cloudflare` | `devmin-api/deploy/scripts/<project>/` |
| Local Docker install (wipe, legacy) | `create-script-to-install-on-docker-local` | `scripts/docker/<repo_name>/` |
| Local Docker update (legacy) | `create-script-to-update-on-docker-local` | `scripts/docker/<repo_name>/` |
| Local Docker remove (legacy) | `create-script-to-remove-on-docker-local` | `scripts/docker/<repo_name>/` |
| Local Docker reinstall (legacy) | `create-script-to-reinstall-on-docker-local` | `scripts/docker/<repo_name>/` |
| Server Docker install | `create-script-to-install-on-docker-server` | `scripts/docker/<repo_name>/` |
| Server Docker update | `create-script-to-update-on-docker-server` | `scripts/docker/<repo_name>/` |
| Server Docker remove | `create-script-to-remove-on-docker-server` | `scripts/docker/<repo_name>/` |
| Server Docker reinstall | `create-script-to-reinstall-on-docker-server` | `scripts/docker/<repo_name>/` |
| Windows / native install (legacy single) | `create-script-to-install-on-win` or `create-script-for-install-on-local` | `scripts/local/<repo_name>/` |
| Windows reinstall (legacy) | `create-script-to-reinstall-on-win` | `scripts/local/<repo_name>/` |
| Hot reload runner | `create-script-to-run-as-hot-reload` | `scripts/local/<repo_name>/` |
| Export desktop exe | `create-script-to-export-exe` | `scripts/local/<repo_name>/` |

3. Prefer `create-ps-script-for-*` in `.cursor/skills/` when the user asks for the full channel quartet or names those skills. Read that folder’s `SKILL.md`.
4. For legacy single-action asks, read `skills/create-script-to-*/SKILL.md`.
5. For `create-ps-script-for-*`, also upsert `devmin-api/deploy/status.md`.

## Always

1. Ask for project/repo name when the user did not name it.
2. Keep Dockerfile and compose in the **target** repo.
3. Set YAML `target_repo` to the absolute target path.

## Never

1. Write `create-ps-script-for-*` outputs into legacy `scripts/docker/` or `scripts/local/`.
2. Invent `stack_name` without user confirmation.

## Example

**Example 1 — Preferred local Docker full set**

- Input: “Create local Docker scripts for asip”
- Output: route → `create-ps-script-for-local-docker` → `devmin-api/deploy/scripts/asip/`

**Example 2 — Missing project**

- Input: “Create update scripts”
- Output: ask which project under `C:/Users/armin/GitHub`

**Example 3 — Cloudflare**

- Input: “Cloudflare scripts for asip”
- Output: route → `create-ps-script-for-cloudflare`

**Example 4 — Legacy single docker install**

- Input: “Create wipe install-on-docker-local for radar-api”
- Output: route → `create-script-to-install-on-docker-local` → `scripts/docker/radar-api/`

**Example 5 — Local Windows full set**

- Input: “create-ps-script-for-local-windows for devmin”
- Output: eight files under `devmin-api/deploy/scripts/devmin/` + status.md row
