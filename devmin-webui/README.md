# devmin-webui

Vue + shadcn dashboard for local API–WebUI Docker stacks.

## Run

### Native

1. Start sibling `devmin-api` on port **8195**
2. `npm install`
3. `npm run dev` — WebUI at http://127.0.0.1:5195/apps

### Docker dev (hot reload)

Started from the API repo (`docker compose -f docker-compose.local.yml up --build`). The WebUI container bind-mounts this repo root (`src/`, `public/`, config files) for Vite HMR.

- WebUI: http://127.0.0.1:5195/apps
- API (proxied): `/api`, `/health` → `http://api:8195` inside compose

Default login: `armin` / `dopadopa123`

## Pages

- `/apps` — full-width grid: Stack, App, Internal port (`127.0.0.1`), External port (LAN IP), Enable/Disable. Each pair is two rows (API then WebUI; stack name on the first row only).
