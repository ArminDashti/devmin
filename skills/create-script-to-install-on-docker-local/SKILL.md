---
name: create-script-to-install-on-docker-local
description: >-
  Creates Dockerfile and docker-compose.yml when needed, then a local Docker
  install script under scripts/docker/<repo_name> that wipes this stack’s image,
  volumes/DB, and related containers before a fresh install, then tests it.
disable-model-invocation: false
metadata:
  version: "2.0.0"
  author: Armin Dashti
  category: devops
  tags: [docker, powershell, install, local, compose, wipe]
  last_updated: "2026-09-01 09:45:00"
  uuid: 5f0ea552-5a9b-46a5-846d-e5417f5978ae
---

# Create Script to Install on Docker Local

## When

- User asks for a first-time local Docker install script
- User asks to Dockerize an app for local install (Dockerfile / compose + local script)
- User names this skill (`create-script-to-install-on-docker-local`)
- Related: `../create-script-to-install-on-docker-server/`, `../create-script-to-update-on-docker-local/`, `../create-script-to-remove-on-docker-local/`, `../create-script-to-reinstall-on-docker-local/`, `../REFERENCE.md`, `C:/Users/armin/GitHub/devmin/skills`
- Exclusions: remote/server install (use install-on-docker-server); rebuild keeping volumes (use update-on-docker-local); remove-only (use remove-on-docker-local)

## How

Fixed order — never skip ahead: Ask stack name → Dockerfile → Compose → PowerShell + YAML → Test.


### Step 0a: Ask for repo name (required)

1. If the user did not name the target GitHub repo folder, **stop and ask** for `repo_name` (e.g. `radar-api`, `devmin`)
2. `target_repo` = `C:/Users/armin/GitHub/<repo_name>`
3. Inspect Dockerfile, compose, and app layout under `target_repo`

### Step 0: Ask for stack name (required)

1. Before any Dockerfile, compose, or script work: if this conversation does **not** already include an explicit `stack_name` from the user, **stop and ask** for it
2. You may suggest the conventional base name (strip `-api`, `-webui`, `-agent`, `-client`, `-android`, `-mcp`, `-hub`, `-ui`; never append `-local`) as a hint — still wait for the user’s answer
3. Do not invent `stack_name`
4. After the user answers, use that value for Compose `name:`, YAML `stack_name`, and `docker compose -p`

### Step 1: Detect project

| Signal | Stack hint |
|--------|------------|
| `package.json` / `*.csproj` / `go.mod` / `requirements.txt` / `Cargo.toml` | Match base image and build steps |
| Existing `dockerfile` / `Dockerfile` / `docker-compose.yml` | Reuse paths; update gaps only |

### Step 2: Create Dockerfile (first)

1. Prefer repo-root `dockerfile` (lowercase) in `target_repo`; YAML `dockerfile` is relative to `target_repo`
2. Multi-stage when a build step exists; slim runtime image
3. `EXPOSE` the real listen port; `CMD`/`ENTRYPOINT` must start the app
4. No secrets in layers

### Step 3: Create docker-compose.yml (second)

1. Prefer repo-root `docker-compose.yml`
2. Honor `IMAGE_TAG`, `DOCKER_NETWORK`, `INTERNAL_PORT`, `PUBLISH_PORT`
3. Network **external**; script creates it
4. Set Compose `name: <stack_name>` and `restart: "no"` on every service

### Step 4: Create local install scripts (third)

Target under `scripts/docker/<repo_name>/`:

| Path | Sample |
|------|--------|
| `install-on-docker-local.ps1` | [samples/install-on-docker-local.ps1](samples/install-on-docker-local.ps1) |
| `install-on-docker-local.yaml` | [samples/install-on-docker-local.yaml](samples/install-on-docker-local.yaml) |

1. If legacy `.armin/docker-scripts/install-on-docker-local.*` or `run-on-docker-local.*` exist → cut/align into `scripts/docker/<repo_name>/`
2. If missing → copy samples, then adapt
3. Do **not** run this skill’s `samples/`
4. Scripts are YAML-only
5. **Fresh wipe (required):** remove this stack’s containers, compose project, volumes, and image — then install clean

**YAML keys:**

| Key | Rule |
|-----|------|
| `target_repo` | Absolute path to the project repo |
| `stack_name` | Base project name only (never append `-local`) |
| `image_tag` | required |
| `compose_file` / `dockerfile` | Relative to `target_repo` (e.g. `docker-compose.yml`) |
| `docker_network` | required |
| `internal_port` / `publish_port` | after free-port check |
| `delete_image` | **always** `"yes"` |
| `delete_volume` | **always** `"yes"` |

### Step 5: Test (required)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\armin\GitHub\devmin\scripts\docker\<repo_name>\install-on-docker-local.ps1
```

## Always

1. Ask for `repo_name` and `stack_name` (or use values already stated this conversation) before create/run work.
2. Create/update Dockerfile and compose **before** the PowerShell pair.
3. Cut legacy files into `./scripts/docker/<repo_name>/install-on-docker-local.*`.
4. Set wipe keys `"yes"` on install YAML.
5. Test local install after create/edit.

## Never

1. Invent `stack_name` without user confirmation.
2. Invent SSH or remote host facts.
3. Add CLI `--` flags; change behavior only via YAML.
4. Execute this skill’s `samples/*`.
5. Treat a failed deploy as success.
6. Use this skill for server install or volume-preserving update.
7. Ship an install script that preserves this stack’s old image, volumes, or DB.

## Example

**Example 1 — New API, no Docker files**

- Input: “Create local Docker install scripts” (no stack name yet)
- Output: ask `stack_name` → dockerfile + compose → `scripts/docker/<repo_name>/install-on-docker-local.*` with wipe keys `"yes"` → succeeds

**Example 2 — Re-run install on existing stack**

- Input: user runs install when stack exists
- Output: `down -v` + remove image → rebuild → `up -d`

**Example 3 — Legacy docker-scripts path**

- Input: project has `.armin/docker-scripts/install-on-docker-local.*`
- Output: cut/align to `scripts/docker/<repo_name>/`

**Example 4 — Sibling api + webui**

- Input: `myapp-api` and `myapp-webui`
- Output: both use `stack_name: myapp`

**Example 5 — Wrong target**

- Input: “Install on the remote server”
- Output: point to `create-script-to-install-on-docker-server`
