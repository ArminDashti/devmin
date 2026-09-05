# Create-script skills — path conventions

Preferred channel skills (`create-ps-script-for-*`) live under `C:/Users/armin/GitHub/devmin/.cursor/skills/`.
Legacy `create-script-to-*` skills live under `C:/Users/armin/GitHub/devmin/skills/`.

## Inputs (every skill)

| Input | Rule |
|-------|------|
| `project` / `repo_name` | GitHub folder name under `C:/Users/armin/GitHub` (e.g. `asip`, `devmin`, `radar-api`) |
| `target_repo` | `C:/Users/armin/GitHub/<project>` — inspect app layout, Dockerfile, compose, wrangler here |
| `stack_name` | Compose project name (Docker); ask if not already stated this conversation |

## Preferred outputs (`create-ps-script-for-*`)

Skill folders: `.cursor/skills/create-ps-script-for-local-windows/`, `.cursor/skills/create-ps-script-for-local-docker/`, `.cursor/skills/create-ps-script-for-cloudflare/`. Port rules: `.cursor/skills/create-ps-script-port-selection.md`.

| Channel | Skill | Output directory |
|---------|-------|------------------|
| Local Windows | `create-ps-script-for-local-windows` | `devmin-api/deploy/scripts/<project>/` |
| Local Docker | `create-ps-script-for-local-docker` | `devmin-api/deploy/scripts/<project>/` |
| Cloudflare | `create-ps-script-for-cloudflare` | `devmin-api/deploy/scripts/<project>/` |

Each preferred skill writes the quartet: `install` / `remove` / `update` / `reinstall` (`.ps1` + sibling `.yaml`), flat in the project folder.

Contract:

| Script | Behavior |
|--------|----------|
| install | Error if already installed |
| remove | Full teardown including data |
| update | Code changes only; keep data |
| reinstall | Call remove then install siblings |

Status registry: `devmin-api/deploy/status.md` (ports, Worker URLs, stack names).

## Local port selection

For `create-ps-script-for-local-windows` and `create-ps-script-for-local-docker`, follow [../.cursor/skills/create-ps-script-port-selection.md](../.cursor/skills/create-ps-script-port-selection.md):

| Role | Band |
|------|------|
| API / publish | `8100`–`8999` |
| WebUI | `5100`–`5999` |
| Postgres publish | `5400`–`5499` |

Union `status.md` claimed ports with listening TCP ports; write free choices into all YAML siblings; record them in `status.md`.

## Legacy outputs (`create-script-to-*`)

| Channel | Output directory |
|---------|------------------|
| Docker (local + server) | `scripts/docker/<repo_name>/` |
| Local / Windows native | `scripts/local/<repo_name>/` |

Dockerfile and `docker-compose.yml` stay in **target_repo** (not under devmin).

## YAML keys (docker scripts)

| Key | Rule |
|-----|------|
| `target_repo` | Absolute path to the project repo |
| `stack_name` | Base stem only (never `-local` suffix) |
| `compose_file` | Path relative to `target_repo` |
| `dockerfile` | Path relative to `target_repo` |
| `image_tag`, `docker_network`, `internal_port`, `publish_port` | Per project |

## YAML keys (Cloudflare scripts)

| Key | Rule |
|-----|------|
| `api_worker_root`, `webui_worker_root` | Paths relative to `target_repo` |
| `api_worker_name`, `webui_worker_name` | Must match `wrangler.toml` `name` |
| `d1_database_name`, `d1_database_id` | Project D1 when used |
| `api_url`, `webui_url` | Public `*.armindashti.workers.dev` URLs |

## Run generated scripts

```powershell
# Preferred Cloudflare update example (asip)
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\armin\GitHub\devmin\devmin-api\deploy\scripts\asip\update-on-cloudflare.ps1

# Legacy Docker local install example (radar-api)
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\armin\GitHub\devmin\scripts\docker\radar-api\install-on-docker-local.ps1
```
