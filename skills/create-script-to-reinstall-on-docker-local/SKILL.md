---
name: create-script-to-reinstall-on-docker-local
description: >-
  Creates a local Docker reinstall script pair under scripts/docker/<repo_name> that
  removes this stack completely then installs it again, then tests it.
disable-model-invocation: false
metadata:
  version: "1.0.0"
  author: Armin Dashti
  category: devops
  tags: [docker, powershell, reinstall, local, wipe]
  last_updated: "2026-09-01 09:45:00"
  uuid: 2a325d1c-764d-4dba-bd83-5c4032c1e188
---

# Create Script to Reinstall on Docker Local

## When

- User asks for a local Docker reinstall (remove completely then install again)
- User names this skill (`create-script-to-reinstall-on-docker-local`)
- Related: `../create-script-to-remove-on-docker-local/`, `../create-script-to-install-on-docker-local/`, `../create-script-to-reinstall-on-docker-server/`, `../REFERENCE.md`
- Exclusions: remove-only; volume-preserving update; remote reinstall

## How


### Step 0a: Ask for repo name (required)

1. If the user did not name the target GitHub repo folder, **stop and ask** for `repo_name` (e.g. `radar-api`, `devmin`)
2. `target_repo` = `C:/Users/armin/GitHub/<repo_name>`
3. Inspect Dockerfile, compose, and app layout under `target_repo`

### Step 0: Ask for stack name (required)

Stop and ask if not already stated this conversation.

### Step 1: Dockerfile + Compose

Same as install-on-docker-local: ensure repo-root `dockerfile` and `docker-compose.yml` exist (create via install skill flow if missing).

### Step 2: Create local reinstall scripts

Target under `scripts/docker/<repo_name>/`:

| Path | Sample |
|------|--------|
| `reinstall-on-docker-local.ps1` | [samples/reinstall-on-docker-local.ps1](samples/reinstall-on-docker-local.ps1) |
| `reinstall-on-docker-local.yaml` | [samples/reinstall-on-docker-local.yaml](samples/reinstall-on-docker-local.yaml) |

**Reinstall = remove completely, then install again:**

1. Full remove for this `stack_name` (containers, volumes, image) — same contract as remove-on-docker-local
2. Then fresh build + `compose up -d` — same contract as install-on-docker-local
3. YAML wipe keys always `"yes"`

### Step 3: Test (required)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\docker\<repo_name>\reinstall-on-docker-local.ps1
```

## Always

1. Ask for `stack_name` before create/run work.
2. Put scripts under `./scripts/docker/<repo_name>/reinstall-on-docker-local.*`.
3. Remove completely before install (never preserve this stack’s old volumes/DB on reinstall).
4. Test after create/edit.

## Never

1. Invent `stack_name` without user confirmation.
2. Skip the remove phase.
3. Preserve volumes by default on reinstall.
4. Execute this skill’s `samples/*`.
5. Use this skill for server reinstall or remove-only.

## Example

**Example 1 — Full local reinstall**

- Input: “Reinstall myapp on local Docker”
- Output: ask `stack_name` → `scripts/docker/<repo_name>/reinstall-on-docker-local.*` → wipe then up

**Example 2 — Versus update**

- Input: “Redeploy but keep the DB”
- Output: do not use this skill; point to `create-script-to-update-on-docker-local`

**Example 3 — Versus remove**

- Input: “Just delete the stack”
- Output: point to `create-script-to-remove-on-docker-local`

**Example 4 — Missing Dockerfile**

- Input: no Docker files
- Output: create Dockerfile/compose first (install order), then reinstall scripts

**Example 5 — Wrong target**

- Input: “Reinstall on the server”
- Output: point to `create-script-to-reinstall-on-docker-server`
