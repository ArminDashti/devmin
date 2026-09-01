---
name: create-script-to-export-exe
description: >-
  Creates or edits scripts/local/<repo_name>/export-exe.ps1 that stops the app,
  builds a Windows .exe, and installs it with dependencies into ./release.
disable-model-invocation: false
metadata:
  version: "2.0.0"
  author: Armin Dashti
  category: devops
  tags: [powershell, export, windows, exe, packaging, scripts]
  last_updated: "2026-09-01 09:45:00"
  uuid: 4e6413b7-064c-4280-8aaf-880a0642b06a
---

# Create Script to Export Exe

## When

- User asks to create or edit `export-exe.ps1` (or legacy `export-app.ps1`) for packaging a Windows app
- User asks to export / package / build a Windows `.exe` with install-into-release flow
- User names this skill (`create-script-to-export-exe`)
- Related: `C:/Users/armin/GitHub/devmin/skills`
- Exclusions: Docker image export; MSI/Inno reinstall-only scripts (use `create-script-to-reinstall-on-win`); Android APK packaging

## How

### Step 1: Detect this project’s export contract

From the **current repo root only**:

| Signal | Use as |
|--------|--------|
| `*.csproj` / `package.json` / `Cargo.toml` / `pyproject.toml` | Build toolchain |
| Existing `export-exe.ps1` / `export-app.ps1` (repo root or `scripts/local/<repo_name>/`) | Align rather than invent a second script |
| `./release` or `./dist` | Output / install target (prefer `./release`) |
| App process name / main exe name | Stop-before-build target |

If the exe name or build command cannot be inferred, ask the user once.

### Step 2: Write `scripts/local/<repo_name>/export-exe.ps1`

1. Create `scripts/local/<repo_name>/` if missing
2. Path: **`<repo-root>/scripts/local/<repo_name>/export-exe.ps1`**
3. If only legacy repo-root `export-app.ps1` / `export-exe.ps1` exists → cut/align into the new path
4. `#Requires -Version 5.1` and `$ErrorActionPreference = "Stop"`
5. Resolve project root as three levels up from `$PSScriptRoot`; work only under that project root

**Runtime contract:**

1. `Set-Location` to project root
2. Stop the running app process for **this** product only (if present)
3. Build the Windows `.exe` with this project’s toolchain
4. Install the exe and required dependencies into `./release`
5. Exit non-zero on build or copy failure

### Step 3: Confirm to the user

- Path of `scripts/local/<repo_name>/export-exe.ps1`
- Exe name and `./release` output path
- How to run: `.\scripts\local\<repo_name>\export-exe.ps1`

## Always

1. Put the script under `./scripts/local/<repo_name>/export-exe.ps1`.
2. Stop the app before rebuilding when a matching process is running.
3. Keep product identity fixed to the project that owns the script.

## Never

1. Export or overwrite another repo’s app.
2. Accept build or output paths outside the project root.
3. Hard-code another machine’s absolute paths.
4. Use this skill for Docker deploy scripts or reinstall-on-win installer flows.

## Example

**Example 1 — New export script**

- Input: “Create export-exe.ps1 for this Windows app”
- Output: `scripts/local/<repo_name>/export-exe.ps1` that stops, builds, installs into `./release`

**Example 2 — Legacy repo-root name**

- Input: project has `export-app.ps1` at repo root
- Output: cut/align to `scripts/local/<repo_name>/export-exe.ps1`

**Example 3 — App running**

- Input: user runs the script while the exe is open
- Output: stops this product’s process, then builds into `./release`

**Example 4 — Missing toolchain**

- Input: no clear build file
- Output: ask once for build command / exe name

**Example 5 — Wrong skill**

- Input: “Reinstall the installed Setup.exe”
- Output: point to `create-script-to-reinstall-on-win`

**Example 6 — Docker export**

- Input: “Export the Docker image”
- Output: point to docker install/update script skills
