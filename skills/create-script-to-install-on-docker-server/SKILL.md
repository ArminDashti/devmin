---
name: create-script-to-install-on-docker-server
description: >-
  Creates Dockerfile and docker-compose.yml when needed, then a remote Docker
  install script under scripts/docker/<repo_name> that wipes this stack’s image,
  volumes/DB, and related containers before a fresh install, then tests when
  SSH is set.
disable-model-invocation: false
metadata:
  version: "2.0.0"
  author: Armin Dashti
  category: devops
  tags: [docker, powershell, install, server, ssh, wipe]
  last_updated: "2026-09-01 09:45:00"
  uuid: 7f09e49c-c4f8-4394-8ad6-326c53c71cfa
---

# Create Script to Install on Docker Server

## When

- User asks for a first-time remote/server Docker install script
- User asks to Dockerize an app for server install
- User names this skill (`create-script-to-install-on-docker-server`)
- Related: `../create-script-to-install-on-docker-local/`, `../create-script-to-update-on-docker-server/`, `../create-script-to-remove-on-docker-server/`, `../create-script-to-reinstall-on-docker-server/`, `../REFERENCE.md`, `C:/Users/armin/.cursor/skills/publish-on-t3/`
- Exclusions: local-only install; volume-preserving remote update; remove-only

## How

Fixed order: Ask stack name → Dockerfile → Compose → PowerShell + YAML → Test.


### Step 0a: Ask for repo name (required)

1. If the user did not name the target GitHub repo folder, **stop and ask** for `repo_name` (e.g. `radar-api`, `devmin`)
2. `target_repo` = `C:/Users/armin/GitHub/<repo_name>`
3. Inspect Dockerfile, compose, and app layout under `target_repo`

### Step 0: Ask for stack name (required)

Same rules as install-on-docker-local: stop and ask if not already stated this conversation.

### Step 1–3: Detect, Dockerfile, Compose

Same as install-on-docker-local (repo-root `dockerfile` / `docker-compose.yml`, `restart: "no"`, external network). YAML paths relative to `scripts/docker/<repo_name>/` use `../../../…`.

### Step 4: Create server install scripts

Target under `scripts/docker/<repo_name>/`:

| Path | Sample |
|------|--------|
| `install-on-docker-server.ps1` | [samples/install-on-docker-server.ps1](samples/install-on-docker-server.ps1) |
| `install-on-docker-server.yaml` | [samples/install-on-docker-server.yaml](samples/install-on-docker-server.yaml) |

1. Cut legacy `.armin/docker-scripts/` or `run-on-docker-server.*` into this folder
2. Fill `ssh` / `volume_dir` from `C:/Users/armin/GitHub/devmin/skills` when the user names a defined server
3. **Fresh wipe (required)** on remote before build/up

**YAML keys:** same wipe rules as local install, plus `build_image_on` (`local`|`server`), `ssh`, `volume_dir`.

### Step 5: Test (required)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\docker\<repo_name>\install-on-docker-server.ps1
```

Run only when `ssh` and `volume_dir` are not placeholders. Never echo SSH passwords.

## Always

1. Ask for `stack_name` before create/run work.
2. Create/update Dockerfile and compose before the PowerShell pair.
3. Cut legacy server deploy files into `./scripts/docker/<repo_name>/install-on-docker-server.*`.
4. Pull remote `ssh` / `volume_dir` only from `servers/<id>.md` or user-supplied values.
5. Set wipe keys `"yes"` on install YAML.

## Never

1. Invent `stack_name` without user confirmation.
2. Invent SSH hosts, aliases, passwords, or key paths.
3. Print the password segment of `host@user@password`.
4. Add CLI `--` flags for behavior.
5. Execute this skill’s `samples/*`.
6. Treat a failed deploy as success.
7. Use this skill for local-only install or volume-preserving remote update.
8. Ship an install script that preserves this stack’s old image, volumes, or DB.

## Example

**Example 1 — New API for T3**

- Input: “Create server Docker install scripts for t3” (no stack name)
- Output: ask `stack_name` → scripts under `scripts/docker/<repo_name>/` with wipe `"yes"` and ssh from `servers/t3.md`

**Example 2 — Re-run on existing remote stack**

- Input: install when stack exists remotely
- Output: remote `down -v` + remove image → rebuild → `up -d`

**Example 3 — Legacy path**

- Input: `.armin/docker-scripts/install-on-docker-server.*`
- Output: cut/align to `scripts/docker/<repo_name>/`

**Example 4 — Build on server**

- Input: `build_image_on: server`
- Output: wipe remote stack, sync to `volume_dir`, build remotely, fresh `up -d`

**Example 5 — Wrong target**

- Input: “Only install on this PC’s Docker”
- Output: point to `create-script-to-install-on-docker-local`
