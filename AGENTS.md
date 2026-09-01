## Learned User Preferences

- Prefer existing plugin skills (e.g. `run-all-apps-on-local-docker`) over creating duplicate skills when one already covers the task.
- When grouping `*-api` and `*-webui` under a parent folder, use a single parent git repo that tracks both project folders — not separate nested git repos or a parent that only gitignores children.
- Implement attached plans without editing the plan file; use pre-created todos and mark progress in place.
- All deploy and install actions should run through PowerShell scripts invoked by the API, not ad-hoc UI shell calls.
- Keep Update and Reinstall distinct: Update applies changes only; Reinstall must fully tear down channel artifacts before reinstalling.

## Learned Workspace Facts

- `devmin` is a Go API + Vue WebUI monorepo at `C:/Users/armin/GitHub/devmin` with `devmin-api/` and `devmin-webui/` as tracked subfolders (not separate git repos).
- Devmin discovers projects under `GITHUB_ROOT` (default `C:/Users/armin/GitHub`) via legacy `*-api`/`*-webui` sibling scan plus optional `.armin/devmin.yaml` manifests.
- Domain model: **Stack** = product stem/folder; **Application** = one runnable unit inside a stack; main grid rows are applications with Stack grouping.
- Supported project shapes: split API+WebUI siblings, combined API+WebUI folder, manifest webapp, and Windows desktop (native-only).
- Four deployment channels: local, local Docker, server Docker, and bare server — detail pages expose install/uninstall/update/reinstall per channel.
- Main dashboard grid columns are Stack, Application, and Endpoints only; mode toggles and actions live on stack/app detail pages.
- Docker params live in per-project `.armin/docker-scripts/run-on-docker-{local,server}.yaml` and are editable via the API/UI.
- Script authoring skills live in `devmin/skills/create-script-to-*` (router: `skills/create-script/`). Generated scripts go to `scripts/docker/<repo_name>/` or `scripts/local/<repo_name>/` with YAML `target_repo` set to the GitHub project path.
- Runtime deploy convention (API): `.armin/docker-scripts/run-on-docker-local.ps1`, `run-on-docker-server.ps1`, and `.armin/server-scripts/run-on-server.ps1` with `-Action Install|Uninstall|Update|Reinstall`.
- GitHub parent repo is `ArminDashti/devmin`; legacy `devmin-api` / `devmin-webui` remotes may still exist as leftovers.
