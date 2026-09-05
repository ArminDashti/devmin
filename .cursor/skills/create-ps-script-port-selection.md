# Local port selection (create-ps-script-for-local-*)

Used by `create-ps-script-for-local-windows` and `create-ps-script-for-local-docker` when authoring YAML ports.

## Goals

1. Pick ports that are **free on this machine now**
2. Avoid ports already listed in `devmin/deploy/status.md`
3. Stay in **safe high bands** (not privileged / not common system services)

## Preferred bands

| Role | Band | Prefer start |
|------|------|--------------|
| API / backend publish | `8100`–`8999` | `8100` |
| WebUI / frontend | `5100`–`5999` | `5100` |
| Postgres (native or published) | `5400`–`5499` | `5400` |
| Extra Docker publish | `9100`–`9199` | `9100` |

`internal_port` (container listen) may stay at the app default (e.g. `8080`, `3000`) when only **host** publish needs uniqueness.

## Unsafe / never allocate

Do not choose: `1`–`1023`, `3389`, `445`, `135`, `139`, `53`, `67`, `68`, `123`, `161`, `162`, `389`, `636`, `1433`, `1521`, `3306`, `5432`, `6379`, `27017`, `2375`, `2376`, `5000`–`5001` (often Windows), `7000`–`7001`.

Prefer not: bare `80`, `443`, `8080`, `3000`, `5173`, `8000` unless the user explicitly requested them **and** they are free.

## Authoring algorithm (agent)

1. Parse every **Ports / URLs** cell in `devmin/deploy/status.md` for numeric host ports already claimed by any project/channel
2. On Windows, list listening TCP ports (`Get-NetTCPConnection -State Listen` or `netstat -ano`)
3. Union both sets = **occupied**
4. For each role needed (api, webui, postgres/publish), walk the preferred band from Prefer start, skip occupied, take the first free port
5. Write the same chosen values into **all** YAML siblings for that channel in **both** trees (`devmin/deploy/<project>/<channel>/` and `<project>/.armin/deploy/<channel>/`)
6. Upsert `devmin/deploy/status.md` with the chosen ports so the next project does not collide

## Runtime (generated scripts)

- **Install:** if any YAML host port is already listening, exit non-zero (treat as conflict / already installed)
- **Update / reinstall:** use the YAML ports as written; do not silently re-pick ports at runtime (re-author scripts if ports must change)
- Optional helper (copy into scripts):

```powershell
function Test-TcpPortFree([int]$Port) {
    $inUse = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    return -not [bool]$inUse
}

function Find-FreeTcpPort([int]$Start, [int]$End, [int[]]$Reserved = @()) {
    for ($p = $Start; $p -le $End; $p++) {
        if ($Reserved -contains $p) { continue }
        if (Test-TcpPortFree $p) { return $p }
    }
    throw "No free TCP port in range $Start-$End"
}
```

## Confirm to user

After choosing, report the allocated ports in chat and in `status.md` (e.g. `api=8123 webui=5123 postgres=5423`).
