# Deploy script status

Overview of projects that have install/remove/update/reinstall scripts dual-written under `devmin/deploy/<project>/<channel>/` and `<project>/.armin/deploy/<channel>/`. Agents and humans use this file to find ports, Worker URLs, stack names, and which channels exist.

Update this file whenever a `create-ps-script-for-*` skill generates or refreshes scripts for a project.

**Local port bands (authoring):** API/publish `8100`-`8999`, WebUI `5100`-`5999`, Postgres `5400`-`5499`. See `.cursor/skills/create-ps-script-port-selection.md`. Never reuse a port already listed below or listening on the host.

| Project | Channel | Stack / Workers | Ports / URLs | Script folders | Notes |
|---------|---------|-----------------|--------------|----------------|-------|
| asip | cloudflare | Workers: `asip-api`, `asip`; D1: `asip` (`0bd20123-61ba-494e-ada1-27eb4fdb971a`) | API: https://asip-api.armindashti.workers.dev - WebUI: https://asip.armindashti.workers.dev | `devmin/deploy/asip/cloudflare/` + `asip/.armin/deploy/cloudflare/` | API root `asip-api/cloudflare/`; WebUI root `asip-webui/` (`assets` → `dist`). Scripts: install/remove/update/reinstall-on-cloudflare. Legacy copies may still exist under `devmin-api/deploy/scripts/asip/`. Live remove not run from authoring. |
| roust | local | Stack: `roust` | api=8100 webui=5100 postgres=5400 | `devmin/deploy/roust/local/` + `roust/.armin/deploy/local/` | Rust API (`cargo run --bin roust-api -- --bind`) + Vue/Vite WebUI. Native Postgres container `roust-postgres-native`. Scripts: install/remove/update/reinstall-on-local-windows. Legacy copies may still exist under `devmin-api/deploy/scripts/roust/`. |

## Channels legend

| Channel folder | Scripts |
|----------------|---------|
| `local` | `*-on-local-windows.ps1` |
| `local-docker` | `*-on-local-docker.ps1` |
| `cloudflare` | `*-on-cloudflare.ps1` |
