---
name: create-script-to-reinstall-on-docker-server
description: >-
  Creates a remote Docker reinstall script pair under scripts/docker/<repo_name> that
  removes this stack completely on the server then installs it again, then tests
  when SSH is set.
disable-model-invocation: false
metadata:
  version: "1.0.0"
  author: Armin Dashti
  category: devops
  tags: [docker, powershell, reinstall, server, ssh, wipe]
  last_updated: "2026-09-01 09:45:00"
  uuid: bf89c111-6388-4c89-8692-bfff4132a271
---

# Create Script to Reinstall on Docker Server

## When

- User asks for a remote/server Docker reinstall (remove completely then install again)
- User names this skill (`create-script-to-reinstall-on-docker-server`)
- Related: `../create-script-to-remove-on-docker-server/`, `../create-script-to-install-on-docker-server/`, `../create-script-to-reinstall-on-docker-local/`, `../REFERENCE.md`
- Exclusions: remove-only; volume-preserving update; local-only reinstall

## How


### Step 0a: Ask for repo name (required)

1. If the user did not name the target GitHub repo folder, **stop and ask** for `repo_name` (e.g. `radar-api`, `devmin`)
2. `target_repo` = `C:/Users/armin/GitHub/<repo_name>`
3. Inspect Dockerfile, compose, and app layout under `target_repo`

### Step 0: Ask for stack name (required)

Stop and ask if not already stated this conversation.

### Step 1: Dockerfile + Compose + SSH

Same as install-on-docker-server. Fill `ssh` / `volume_dir` from `servers/<id>.md` when named.

### Step 2: Create server reinstall scripts

Target under `scripts/docker/<repo_name>/`:

| Path | Sample |
|------|--------|
| `reinstall-on-docker-server.ps1` | [samples/reinstall-on-docker-server.ps1](samples/reinstall-on-docker-server.ps1) |
| `reinstall-on-docker-server.yaml` | [samples/reinstall-on-docker-server.yaml](samples/reinstall-on-docker-server.yaml) |

**Reinstall = remove completely, then install again** on the remote (wipe keys `"yes"`, then build/up).

### Step 3: Test (required)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\docker\<repo_name>\reinstall-on-docker-server.ps1
```

Run only when `ssh` and `volume_dir` are not placeholders. Never echo SSH passwords.

## Always

1. Ask for `stack_name` before create/run work.
2. Put scripts under `./scripts/docker/<repo_name>/reinstall-on-docker-server.*`.
3. Remove completely before install on the remote.
4. Pull `ssh` / `volume_dir` only from `servers/<id>.md` or user-supplied values.

## Never

1. Invent `stack_name` or SSH credentials.
2. Skip the remove phase.
3. Preserve volumes by default on reinstall.
4. Print SSH passwords.
5. Execute this skill’s `samples/*`.
6. Use this skill for local reinstall or remove-only.

## Example

**Example 1 — Reinstall on T3**

- Input: “Reinstall myapp on t3”
- Output: ask `stack_name` → `scripts/docker/<repo_name>/reinstall-on-docker-server.*` with ssh from `servers/t3.md`

**Example 2 — Versus update**

- Input: “Redeploy but keep remote DB”
- Output: point to `create-script-to-update-on-docker-server`

**Example 3 — Versus remove**

- Input: “Just delete the remote stack”
- Output: point to `create-script-to-remove-on-docker-server`

**Example 4 — Placeholders**

- Input: SSH not filled
- Output: scripts written; waiting on real `ssh` / `volume_dir`

**Example 5 — Wrong target**

- Input: “Reinstall on this PC’s Docker”
- Output: point to `create-script-to-reinstall-on-docker-local`
