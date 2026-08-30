# devmin-webui

Vue dashboard for the Devmin local apps manager.

## Run

### Native

1. Start `devmin-api` on port **8195**
2. `npm install`
3. `npm run dev` — http://127.0.0.1:5195/apps

### Docker dev

Started from `devmin-api` (`docker compose -f docker-compose.local.yml up --build`).

Default login: `armin` / `dopadopa123`

## Pages

| Path | Description |
|------|-------------|
| `/apps` | Main grid: Stack, Application, Endpoints |
| `/stacks/:stem` | Stack detail — channel actions for whole stack |
| `/apps/:appId` | Application detail — four channel cards + docker params editor |
| `/settings` | Local Docker, server Docker, and server settings |

Actions call `POST /api/v1/actions` and poll job status for script output.
