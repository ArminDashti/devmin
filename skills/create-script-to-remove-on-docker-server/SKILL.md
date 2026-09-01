---
name: create-script-to-remove-on-docker-server
description: >-
  Creates a remote Docker remove script pair under scripts/docker/<repo_name> that
  tears down this stack’s containers, volumes, and image on the server with no
  reinstall.
disable-model-invocation: false
metadata:
  version: "1.0.0"
  author: Armin Dashti
  category: devops
  tags: [docker, powershell, remove, server, ssh, teardown]
  last_updated: "2026-09-01 09:45:00"
  uuid: 68b4c1c2-7b70-4f1c-9242-6c2f3a4d2c2d
---

# Create Script to Remove on Docker Server

## When

- User asks for a remote/server Docker remove / tear-down script
- User names this skill (`create-script-to-remove-on-docker-server`)
- Related: `../create-script-to-install-on-docker-server/`, `../create-script-to-reinstall-on-docker-server/`, `../create-script-to-remove-on-docker-local/`, `../REFERENCE.md`
- Exclusions: remove then install again (use reinstall); local-only remove; volume-preserving update

## How


### Step 0a: Ask for repo name (required)

1. If the user did not name the target GitHub repo folder, **stop and ask** for `repo_name` (e.g. `radar-api`, `devmin`)
2. `target_repo` = `C:/Users/armin/GitHub/<repo_name>`
3. Inspect Dockerfile, compose, and app layout under `target_repo`

### Step 0: Ask for stack name (required)

Stop and ask if not already stated this conversation.

### Step 1: Require Docker + SSH contract

1. Prefer existing compose / install-server YAML
2. Fill `ssh` / `volume_dir` from `C:/Users/armin/GitHub/devmin/skills` when the user names a defined server

### Step 2: Create server remove scripts

Target under `scripts/docker/<repo_name>/`:

| Path | Sample |
|------|--------|
| `remove-on-docker-server.ps1` | [samples/remove-on-docker-server.ps1](samples/remove-on-docker-server.ps1) |
| `remove-on-docker-server.yaml` | [samples/remove-on-docker-server.yaml](samples/remove-on-docker-server.yaml) |

**Runtime (must):** sync compose if needed for remote `down -v`, remove remote image, remove leftover stack containers/volumes — **no** build, **no** `up`.

### Step 3: Test (required)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\docker\<repo_name>\remove-on-docker-server.ps1
```

Run only when `ssh` and `volume_dir` are not placeholders. Never echo SSH passwords.

## Always

1. Ask for `stack_name` before create/run work.
2. Put scripts under `./scripts/docker/<repo_name>/remove-on-docker-server.*`.
3. Pull `ssh` / `volume_dir` only from `servers/<id>.md` or user-supplied values.
4. Tear down only this stack on the remote.

## Never

1. Invent `stack_name` or SSH credentials.
2. Print the password segment of `host@user@password`.
3. Build or `compose up` after remove.
4. Execute this skill’s `samples/*`.
5. Use this skill for local remove or reinstall.

## Example

**Example 1 — Remove on T3**

- Input: “Create remove-on-docker-server for t3” (no stack name)
- Output: ask `stack_name` → scripts with ssh from `servers/t3.md`

**Example 2 — Placeholders**

- Input: SSH not filled
- Output: scripts written; report waiting on real `ssh` / `volume_dir`

**Example 3 — Wrong skill (reinstall)**

- Input: “Wipe and install again on the server”
- Output: point to `create-script-to-reinstall-on-docker-server`

**Example 4 — Wrong target (local)**

- Input: “Remove Docker on this PC”
- Output: point to `create-script-to-remove-on-docker-local`

**Example 5 — Shared network**

- Input: stack shares HAProxy network
- Output: remove stack resources only; do not delete shared network still in use
