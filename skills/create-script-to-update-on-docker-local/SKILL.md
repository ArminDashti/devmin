---
name: create-script-to-update-on-docker-local
description: >-
  Creates or aligns a local Docker update/redeploy script pair under
  scripts/docker/<repo_name> for an existing stack, then tests it.
disable-model-invocation: false
metadata:
  version: "2.0.0"
  author: Armin Dashti
  category: devops
  tags: [docker, powershell, update, local, redeploy]
  last_updated: "2026-09-01 09:45:00"
  uuid: f259d5fa-3bca-4498-9f11-7ff142f21034
---

# Create Script to Update on Docker Local

## When

- User asks for a local Docker update / redeploy / rebuild script
- User asks to align existing local update scripts to the current contract
- User names this skill (`create-script-to-update-on-docker-local`)
- Related: `../create-script-to-install-on-docker-local/`, `../create-script-to-update-on-docker-server/`, `../create-script-to-remove-on-docker-local/`, `../REFERENCE.md`, `C:/Users/armin/GitHub/devmin/skills`
- Exclusions: first-time local install; remote update; full remove/reinstall

## How


### Step 0a: Ask for repo name (required)

1. If the user did not name the target GitHub repo folder, **stop and ask** for `repo_name` (e.g. `radar-api`, `devmin`)
2. `target_repo` = `C:/Users/armin/GitHub/<repo_name>`
3. Inspect Dockerfile, compose, and app layout under `target_repo`

### Step 0: Ask for stack name (required)

Stop and ask if `stack_name` was not already stated this conversation.

### Step 1: Require existing Docker files

1. Target repo must already have `dockerfile` / `Dockerfile` and `docker-compose.yml`
2. If missing → stop and point to `create-script-to-install-on-docker-local`

### Step 2: Create local update scripts

Target under `scripts/docker/<repo_name>/`:

| Path | Sample |
|------|--------|
| `update-on-docker-local.ps1` | [samples/update-on-docker-local.ps1](samples/update-on-docker-local.ps1) |
| `update-on-docker-local.yaml` | [samples/update-on-docker-local.yaml](samples/update-on-docker-local.yaml) |

1. Cut legacy `.armin/docker-scripts/` or `run-on-docker-local.*` into this folder (keep volumes)
2. If missing → copy samples, then adapt
3. YAML-only; `compose_file` / `dockerfile` relative to `scripts/docker/<repo_name>/` (`../../../…`)

**YAML keys:** `delete_image: "yes"`, `delete_volume: "no"` (preserve data).

### Step 3: Test (required)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\docker\<repo_name>\update-on-docker-local.ps1
```

## Always

1. Ask for `stack_name` before create/run work.
2. Preserve volumes (`delete_volume: "no"`) unless the user explicitly asks to wipe.
3. Use the confirmed `stack_name` / network consistently with the install scripts.
4. Test local update after create/edit.

## Never

1. Invent `stack_name` without user confirmation.
2. Create a first-time Dockerfile/compose set when missing — send to install skill.
3. Wipe volumes by default on update.
4. Invent SSH / remote facts.
5. Execute this skill’s `samples/*`.
6. Treat a failed redeploy as success.
7. Use this skill for server update or first-time local install.

## Example

**Example 1 — Rebuild after code change**

- Input: “Create local Docker update script” (no stack name)
- Output: ask `stack_name` → `scripts/docker/<repo_name>/update-on-docker-local.*` with `delete_volume: "no"`

**Example 2 — Legacy path**

- Input: `.armin/docker-scripts/update-on-docker-local.*`
- Output: cut/align to `scripts/docker/<repo_name>/`

**Example 3 — Missing Dockerfile**

- Input: no Dockerfile
- Output: stop; point to `create-script-to-install-on-docker-local`

**Example 4 — Port change**

- Input: user asks to move host port
- Output: update YAML `publish_port` after free-port check; retest

**Example 5 — Wrong target**

- Input: “Update the stack on the server”
- Output: point to `create-script-to-update-on-docker-server`
