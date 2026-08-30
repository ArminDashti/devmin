# devmin-api

Gin API for discovering local dev projects and running systematic deploy actions via PowerShell scripts.

## Run

### Native (Postgres in Docker, API + WebUI on host)

1. Start Postgres: `docker compose up -d`
2. Copy `.env.example` → `.env`
3. `go run ./cmd/server`

### Docker dev (hot reload)

```powershell
docker network create t3-net   # if missing
docker compose -f docker-compose.local.yml up --build
```

- WebUI: http://127.0.0.1:5195/apps
- API: http://127.0.0.1:8195/health

**Note:** Deploy actions require Windows PowerShell on the host. Listing and auth work from Linux containers with read-only mounts.

Default login: `armin` / `dopadopa123`

## API

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/stacks` | Stacks with applications and endpoints |
| `GET` | `/api/v1/stacks/:stem` | Stack detail |
| `GET` | `/api/v1/applications/:appId` | Application detail |
| `POST` | `/api/v1/actions` | Run action `{ stem?, appId?, channel, action }` |
| `GET` | `/api/v1/actions/:id` | Poll action job |
| `GET` | `/api/v1/settings` | Platform settings |
| `PUT` | `/api/v1/settings` | Update settings |
| `GET/PATCH` | `/api/v1/projects/:stem/docker-params?target=local\|server` | Docker YAML params |
| `GET` | `/api/v1/apps` | Legacy grid (backward compatible) |
| `PATCH` | `/api/v1/apps/:stem` | Legacy enable/disable |

### Channels

- `hotReload` — actions: `enable`, `disable`
- `localDocker` — `install`, `uninstall`, `update`, `reinstall`
- `serverDocker` — same
- `server` — same (uses `.armin/server-scripts/run-on-server.ps1`)

Legacy `runMode` values `local` → `hotReload`, `server` → `serverDocker`.

## Discovery

1. `.armin/devmin.yaml` manifest at repo root (see monorepo root example)
2. Legacy `*-api` + `*-webui` sibling folders under `GITHUB_ROOT`
