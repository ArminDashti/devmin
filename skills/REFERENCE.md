# Create-script skills — path conventions

All `create-script-to-*` skills live under `C:/Users/armin/GitHub/devmin/skills/`.

## Inputs (every skill)

| Input | Rule |
|-------|------|
| `repo_name` | GitHub folder name under `C:/Users/armin/GitHub` (e.g. `radar-api`, `devmin`) |
| `target_repo` | `C:/Users/armin/GitHub/<repo_name>` — inspect Dockerfile, compose, and stack here |
| `stack_name` | Compose project name; ask if not already stated this conversation |

## Outputs (devmin repo)

| Channel | Output directory |
|---------|------------------|
| Docker (local + server) | `C:/Users/armin/GitHub/devmin/scripts/docker/<repo_name>/` |
| Local / Windows native | `C:/Users/armin/GitHub/devmin/scripts/local/<repo_name>/` |

Dockerfile and `docker-compose.yml` stay in **target_repo** (not under devmin).

## YAML keys (docker scripts)

| Key | Rule |
|-----|------|
| `target_repo` | Absolute path to the project repo |
| `stack_name` | Base stem only (never `-local` suffix) |
| `compose_file` | Path relative to `target_repo` |
| `dockerfile` | Path relative to `target_repo` |
| `image_tag`, `docker_network`, `internal_port`, `publish_port` | Per project |

PowerShell in `scripts/docker/<repo_name>/` resolves `compose_file` and `dockerfile` against `target_repo`, not against the script folder.

## Run generated scripts

```powershell
# Docker local install example (radar-api)
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\armin\GitHub\devmin\scripts\docker\radar-api\install-on-docker-local.ps1
```
