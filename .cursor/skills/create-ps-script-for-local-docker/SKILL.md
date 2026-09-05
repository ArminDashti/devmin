---
name: create-ps-script-for-local-docker
description: >-
  Prepares local Docker settings in the target repo, dual-writes
  install/remove/update/reinstall PowerShell + YAML pairs under
  devmin/deploy/<project>/local-docker/ and <project>/.armin/deploy/local-docker/,
  chooses free safe host publish ports, then upserts devmin/deploy/status.md.
disable-model-invocation: false
metadata:
  version: "1.2.0"
  author: Armin Dashti
  category: devops
  tags: [powershell, local-docker, docker, compose, install, remove, update, reinstall, ports, dual-write]
  last_updated: "2026-09-04 14:54:00"
  uuid: 8b92c665-7de8-4958-b0ea-30e20aa3da8c
---

# Create PS Script for Local Docker

## When

- User asks for local Docker deploy scripts (install / remove / update / reinstall)
- User names this skill (`create-ps-script-for-local-docker`)
- Related: `../create-ps-script-for-local-windows/`, `../create-ps-script-for-cloudflare/`, `../create-ps-script-port-selection.md`, `../../skills/create-script/`, `../../skills/REFERENCE.md`
- Exclusions: native Windows; Cloudflare; server Docker (legacy `create-script-to-*-docker-server`)

## How

### Step 0: Require project and stack

1. If the user did not name the **project**, stop and ask once
2. `target_repo` = `C:/Users/armin/GitHub/<project>`
3. If `stack_name` is not stated this conversation, stop and ask (suggest stem without `-api`/`-webui`; never invent)
4. Inspect Dockerfile and compose under `target_repo`; create/update them in the **target** repo when missing — not under devmin

### Step 0b: Allocate free safe host ports (required)

1. Follow [create-ps-script-port-selection.md](../create-ps-script-port-selection.md) fully
2. Read `devmin/deploy/status.md` for ports already claimed
3. Check listening TCP ports on this machine
4. Assign `publish_port` in `8100`–`8999` (or `9100`–`9199` for an extra service); keep `internal_port` as the container listen port from the app when it need not be unique on the host
5. If Postgres (or another DB) is published to the host, assign that publish port in `5400`–`5499`
6. If the user named explicit publish ports, use them only when free; otherwise re-pick and tell the user
7. Confirm chosen ports in chat before finishing

### Step 0c: Prepare settings and params in the target repo

1. Ensure Dockerfile and compose files exist under `target_repo` (create/update there when missing)
2. Write compose/image/network/stack keys into YAML: `stack_name`, `compose_file`, `dockerfile`, `image_tag`, `docker_network`, `internal_port`, `publish_port` (and DB publish ports when used)
3. Ask before any package or image pull install that needs user approval (user install rule)

### Step 1: Dual-write output paths

Write the **same** eight files into **both** trees (create folders if missing):

| Tree | Path |
|------|------|
| Devmin | `devmin/deploy/<project>/local-docker/` |
| Target | `<project>/.armin/deploy/local-docker/` |

| File | Sample |
|------|--------|
| `install-on-local-docker.ps1` | [samples/install-on-local-docker.ps1](samples/install-on-local-docker.ps1) |
| `install-on-local-docker.yaml` | [samples/install-on-local-docker.yaml](samples/install-on-local-docker.yaml) |
| `remove-on-local-docker.ps1` | [samples/remove-on-local-docker.ps1](samples/remove-on-local-docker.ps1) |
| `remove-on-local-docker.yaml` | [samples/remove-on-local-docker.yaml](samples/remove-on-local-docker.yaml) |
| `update-on-local-docker.ps1` | [samples/update-on-local-docker.ps1](samples/update-on-local-docker.ps1) |
| `update-on-local-docker.yaml` | [samples/update-on-local-docker.yaml](samples/update-on-local-docker.yaml) |
| `reinstall-on-local-docker.ps1` | [samples/reinstall-on-local-docker.ps1](samples/reinstall-on-local-docker.ps1) |
| `reinstall-on-local-docker.yaml` | [samples/reinstall-on-local-docker.yaml](samples/reinstall-on-local-docker.yaml) |

1. Copy samples; adapt paths/stack; write the **chosen** `publish_port` (and any DB publish ports) into every YAML sibling in **both** trees
2. YAML may differ only for path relativity (`target_repo` absolute in the devmin copy; target copy may use repo-relative compose/dockerfile paths). Ports, stack, and behavior keys stay identical
3. YAML-only scripts; do not run this skill’s `samples/`
4. Reinstall calls sibling remove then install from `$PSScriptRoot` (works in either tree)

### Step 2: Runtime contract

| Script | Behavior |
|--------|----------|
| Install | If compose project / labeled containers already exist for `stack_name`, **error**. If `publish_port` (or other host ports) are listening, **error**. Else ensure network and `compose up --build -d` (**no wipe**) |
| Remove | `compose down -v`, remove project image, leftover labeled containers and volumes |
| Update | Rebuild/recreate containers **without** deleting volumes; keep the same YAML publish ports |
| Reinstall | Call `remove-on-local-docker.ps1` then `install-on-local-docker.ps1` |

**YAML keys:** `target_repo`, `stack_name`, `compose_file`, `dockerfile`, `image_tag`, `docker_network`, `internal_port`, `publish_port`

Compose `name:` and paths resolve against `target_repo`.

### Step 3: Status registry

Upsert `devmin/deploy/status.md` with publish/internal ports, stack name, both script folders, network, channel `local-docker`.

## Always

1. Dual-write all eight files to both `devmin/deploy/<project>/local-docker/` and `<project>/.armin/deploy/local-docker/`.
2. Prepare target-repo settings (Dockerfile/compose + YAML params) before writing scripts.
3. Allocate host publish ports via `create-ps-script-port-selection.md` before writing YAML.

## Never

1. Wipe volumes on install (install must fail if already present).
2. Delete volumes on update.
3. Invent `stack_name` without user confirmation.
4. Hard-code contested host ports (`80`/`443`/`8080`/`3000`/`5432`) without a free-port check.
5. Write only under `devmin-api/deploy/scripts/` or skip the target `.armin/deploy/local-docker/` tree.
6. Write these scripts into legacy `scripts/docker/` for this skill.

## Example

**Example 1 — Full set with auto publish port**

- Input: “Create local Docker scripts for `asip` with stack `asip`”
- Output: free `publish_port` in both `devmin/deploy/asip/local-docker/` and `asip/.armin/deploy/local-docker/` + status row

**Example 2 — Missing project**

- Input: “Local Docker install scripts”
- Output: ask for project; stop

**Example 3 — Missing stack_name**

- Input: “Local Docker scripts for radar-api”
- Output: ask for `stack_name` (hint: `radar`); stop until answered

**Example 4 — Publish port busy**

- Input: user wants publish `8080` but it is listening
- Output: next free in 8100–8999; report the substitute; write into both trees

**Example 5 — Reinstall**

- Input: reinstall
- Output: remove sibling then install sibling only
