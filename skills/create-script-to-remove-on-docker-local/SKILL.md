---
name: create-script-to-remove-on-docker-local
description: >-
  Creates a local Docker remove script pair under scripts/docker/<repo_name> that
  tears down this stack’s containers, volumes, and image with no reinstall.
disable-model-invocation: false
metadata:
  version: "1.0.0"
  author: Armin Dashti
  category: devops
  tags: [docker, powershell, remove, local, teardown]
  last_updated: "2026-09-01 09:45:00"
  uuid: 138f54d7-d5ca-4323-b640-8f99704f4cba
---

# Create Script to Remove on Docker Local

## When

- User asks for a local Docker remove / tear-down / uninstall-stack script
- User names this skill (`create-script-to-remove-on-docker-local`)
- Related: `../create-script-to-install-on-docker-local/`, `../create-script-to-reinstall-on-docker-local/`, `../create-script-to-remove-on-docker-server/`, `../REFERENCE.md`
- Exclusions: remove then install again (use reinstall); volume-preserving redeploy (use update); remote remove (use remove-on-docker-server)

## How


### Step 0a: Ask for repo name (required)

1. If the user did not name the target GitHub repo folder, **stop and ask** for `repo_name` (e.g. `radar-api`, `devmin`)
2. `target_repo` = `C:/Users/armin/GitHub/<repo_name>`
3. Inspect Dockerfile, compose, and app layout under `target_repo`

### Step 0: Ask for stack name (required)

Stop and ask if `stack_name` was not already stated this conversation.

### Step 1: Require existing Docker files

1. Prefer existing `dockerfile` / `docker-compose.yml` and install YAML for paths
2. If compose is missing and cannot resolve paths → stop and point to install skill

### Step 2: Create local remove scripts

Target under `scripts/docker/<repo_name>/`:

| Path | Sample |
|------|--------|
| `remove-on-docker-local.ps1` | [samples/remove-on-docker-local.ps1](samples/remove-on-docker-local.ps1) |
| `remove-on-docker-local.yaml` | [samples/remove-on-docker-local.yaml](samples/remove-on-docker-local.yaml) |

1. Create `scripts/docker/<repo_name>/` if missing
2. Copy samples and adapt; paths relative to `scripts/docker/<repo_name>/` (`../../../…`)
3. YAML-only; `delete_image` / `delete_volume` always `"yes"`

**Runtime (must):** compose `down -v` for this `stack_name`, remove `image_tag`, remove leftover stack containers/volumes — **no** build, **no** `up`.

### Step 3: Test (required)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\docker\<repo_name>\remove-on-docker-local.ps1
```

Confirm stack containers/volumes/image for this project are gone.

## Always

1. Ask for `stack_name` before create/run work.
2. Put scripts under `./scripts/docker/<repo_name>/remove-on-docker-local.*`.
3. Tear down only this stack — do not delete shared networks still in use.
4. Test remove after create/edit.

## Never

1. Invent `stack_name` without user confirmation.
2. Build or `compose up` after remove.
3. Execute this skill’s `samples/*`.
4. Treat a failed tear-down as success.
5. Use this skill for remote remove or for reinstall (remove+install).

## Example

**Example 1 — Tear down local stack**

- Input: “Create remove-on-docker-local for myapp”
- Output: ask/confirm `stack_name` → `scripts/docker/<repo_name>/remove-on-docker-local.*` → stack gone

**Example 2 — Stack already gone**

- Input: user runs remove when nothing is up
- Output: down/rm commands no-op safely → Remove complete

**Example 3 — Wrong skill (reinstall)**

- Input: “Remove and install again”
- Output: point to `create-script-to-reinstall-on-docker-local`

**Example 4 — Wrong target (server)**

- Input: “Remove the stack on T3”
- Output: point to `create-script-to-remove-on-docker-server`

**Example 5 — Missing compose**

- Input: no docker-compose.yml
- Output: stop; point to install skill first
