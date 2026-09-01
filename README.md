# Devmin

Local apps manager for Armin's development projects on Windows.

## What it does

- Discovers projects under `GITHUB_ROOT` (default `C:/Users/armin/GitHub`)
- Supports split API/WebUI repos, combined folders, manifest-defined webapps, and Windows apps
- Main grid: **Stack**, **Application**, **Endpoints**
- Per-stack and per-application pages with four channels:
  - **Local** — Install / Uninstall / Update / Reinstall (native host)
  - **Local Docker** — Install / Uninstall / Update / Reinstall
  - **Server Docker** — Install / Uninstall / Update / Reinstall
  - **Server** — Install / Uninstall / Update / Reinstall
- Settings for local Docker, server Docker, and bare server targets
- Editable Docker params per project (`run-on-docker-local.yaml` / `run-on-docker-server.yaml`)

## Packages

| Package | Role |
|---------|------|
| [devmin-api](devmin-api/README.md) | Go/Gin API — discovery, actions, settings |
| [devmin-webui](devmin-webui/README.md) | Vue dashboard |

## Project manifest

Optional `.armin/devmin.yaml` at a repo root overrides discovery:

```yaml
stack: myproduct
type: split   # split | combined-api-webui | webapp | windows
applications:
  - id: myproduct-api
    role: api
    dir: myproduct-api
  - id: myproduct-webui
    role: webui
    dir: myproduct-webui
```

Legacy discovery still scans `*-api` + `*-webui` siblings when no manifest claims the stem.

## Scripts

Deploy PowerShell scripts are authored per repo under devmin (see `skills/create-script/`):

| Channel | Path |
|---------|------|
| Docker (local + server) | `scripts/docker/<repo_name>/` |
| Local / Windows / server | `scripts/local/<repo_name>/` |

Each folder holds action pairs (`install-*`, `update-*`, `remove-*`, `reinstall-*`) as `.ps1` + `.yaml`. YAML includes `target_repo` pointing at `C:/Users/armin/GitHub/<repo_name>`.

Devmin API still invokes per-project runners (`.armin/docker-scripts/run-on-docker-*.ps1`) until wired to these central scripts.

## Quick start

1. Start Postgres and API (see `devmin-api/README.md`)
2. Open WebUI at `http://127.0.0.1:5195/apps` (or local-docker port from compose)
3. Log in with default credentials from API README
