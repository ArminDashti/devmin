---
name: create-script-to-update-on-docker-server
description: >-
  Creates or aligns a remote Docker update/redeploy script pair under
  scripts/docker/<repo_name> for an existing stack, then tests when SSH is set.
disable-model-invocation: false
metadata:
  version: "2.0.0"
  author: Armin Dashti
  category: devops
  tags: [docker, powershell, update, server, ssh]
  last_updated: "2026-09-01 09:45:00"
  uuid: ecb43695-d035-4f9f-bee0-66853029e323
---

# Create Script to Update on Docker Server

## When

- User asks for a remote/server Docker update / redeploy / rebuild script
- User asks to align existing server update scripts to the current contract
- User names this skill (`create-script-to-update-on-docker-server`)
- Related: `../create-script-to-install-on-docker-server/`, `../create-script-to-update-on-docker-local/`, `../create-script-to-remove-on-docker-server/`, `../REFERENCE.md`, `C:/Users/armin/.cursor/skills/publish-on-t3/`
- Exclusions: first-time server install; local-only update; full remove/reinstall

## How


### Step 0a: Ask for repo name (required)

1. If the user did not name the target GitHub repo folder, **stop and ask** for `repo_name` (e.g. `radar-api`, `devmin`)
2. `target_repo` = `C:/Users/armin/GitHub/<repo_name>`
3. Inspect Dockerfile, compose, and app layout under `target_repo`

### Step 0: Ask for stack name (required)

Stop and ask if not already stated this conversation.

### Step 1: Require existing Docker files

1. Must have `dockerfile` / `Dockerfile` and `docker-compose.yml`
2. If missing → stop and point to `create-script-to-install-on-docker-server`

### Step 2: Create server update scripts

Target under `scripts/docker/<repo_name>/`:

| Path | Sample |
|------|--------|
| `update-on-docker-server.ps1` | [samples/update-on-docker-server.ps1](samples/update-on-docker-server.ps1) |
| `update-on-docker-server.yaml` | [samples/update-on-docker-server.yaml](samples/update-on-docker-server.yaml) |

1. Cut legacy `.armin/docker-scripts/` into this folder (keep volumes)
2. Fill `ssh` / `volume_dir` from `servers/<id>.md` when named
3. `delete_image: "yes"`, `delete_volume: "no"`; paths relative to `scripts/docker/<repo_name>/`

### Step 3: Test (required)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\docker\<repo_name>\update-on-docker-server.ps1
```

Run only when `ssh` and `volume_dir` are not placeholders. Never echo SSH passwords.

## Always

1. Ask for `stack_name` before create/run work.
2. Preserve volumes (`delete_volume: "no"`) unless the user explicitly asks to wipe.
3. Pull remote `ssh` / `volume_dir` only from `servers/<id>.md` or user-supplied values.
4. Use the confirmed `stack_name` / network consistently with the install scripts.

## Never

1. Invent `stack_name` without user confirmation.
2. Create a first-time Dockerfile/compose set when missing.
3. Wipe volumes by default on update.
4. Invent SSH hosts, aliases, passwords, or key paths.
5. Print the password segment of `host@user@password`.
6. Execute this skill’s `samples/*`.
7. Treat a failed redeploy as success.
8. Use this skill for local update or first-time server install.

## Example

**Example 1 — Redeploy on T3**

- Input: “Create server Docker update script for t3” (no stack name)
- Output: ask `stack_name` → `scripts/docker/<repo_name>/update-on-docker-server.*` with `delete_volume: "no"`

**Example 2 — Legacy path**

- Input: `.armin/docker-scripts/update-on-docker-server.*`
- Output: cut/align to `scripts/docker/<repo_name>/`

**Example 3 — Missing compose**

- Input: no compose file
- Output: stop; point to `create-script-to-install-on-docker-server`

**Example 4 — Placeholders**

- Input: SSH not filled
- Output: scripts written; report waiting on real `ssh` / `volume_dir`

**Example 5 — Wrong target**

- Input: “Only update Docker on this PC”
- Output: point to `create-script-to-update-on-docker-local`
