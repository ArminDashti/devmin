## Learned User Preferences

- Prefer existing plugin skills (e.g. `run-all-apps-on-local-docker`) over creating duplicate skills when one already covers the task.
- When grouping `*-api` and `*-webui` under a parent folder, use a single parent git repo that tracks both project folders — not separate nested git repos or a parent that only gitignores children.
- Implement attached plans without editing the plan file; use pre-created todos and mark progress in place.
- All deploy and install actions should run through PowerShell scripts invoked by the API, not ad-hoc UI shell calls.
- Keep Update and Reinstall distinct: Update applies changes only; Reinstall must fully tear down channel artifacts before reinstalling.
- Prefer heavy caching of the apps/main grid page so navigating away and back does not force a full slow refresh.

## Learned Workspace Facts

- `devmin` is a Go API + Vue WebUI monorepo at `C:/Users/armin/GitHub/devmin` with `devmin-api/` and `devmin-webui/` as tracked subfolders (not separate git repos).
- Devmin discovers projects under `GITHUB_ROOT` (default `C:/Users/armin/GitHub`) via legacy `*-api`/`*-webui` sibling scan plus optional `.armin/devmin.yaml` manifests.
- Domain model: **Stack** = product stem/folder; **Application** = one runnable unit inside a stack; main grid rows are applications with Stack grouping.
- Supported project shapes: split API+WebUI siblings, combined API+WebUI folder, manifest webapp, and Windows desktop (native-only).
- Deployment endpoint modes on the main grid: Hot-reload (local non-Docker with hot reload), Local (local non-Docker without hot reload), Local Docker, Server Docker, and Server (bare server); show a red indicator when a mode is not running; install/update/reinstall actions stay on stack/app detail pages.
- Docker params live in per-project `.armin/docker-scripts/run-on-docker-{local,server}.yaml` and are editable via the API/UI.
- Preferred script authoring skills live under `.cursor/skills/create-ps-script-for-{local-windows,local-docker,cloudflare}` (+ `.cursor/skills/create-ps-script-port-selection.md`). They prepare settings/params in the target repo, then dual-write install/remove/update/reinstall PS1+YAML pairs to `devmin/deploy/<project>/{local,local-docker,cloudflare}/` and `<project>/.armin/deploy/{local,local-docker,cloudflare}/` (install errors if present; remove wipes data; update keeps data; reinstall calls remove+install). Status registry: `devmin/deploy/status.md`. Legacy copies may still exist under `devmin-api/deploy/scripts/<project>/`. Legacy `create-script-to-*` still live under `skills/` and write to `scripts/docker/<repo_name>/` or `scripts/local/<repo_name>/`. Router: `skills/create-script/`.
- Runtime deploy convention (API): `.armin/docker-scripts/run-on-docker-local.ps1`, `run-on-docker-server.ps1`, and `.armin/server-scripts/run-on-server.ps1` with `-Action Install|Uninstall|Update|Reinstall`.
- GitHub parent repo is `ArminDashti/devmin`; legacy `devmin-api` / `devmin-webui` remotes may still exist as leftovers.
