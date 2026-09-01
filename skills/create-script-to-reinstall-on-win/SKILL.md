---
name: create-script-to-reinstall-on-win
description: >-
  Creates scripts/local/<repo_name>/reinstall-on-win.ps1 that completely removes
  then reinstalls only the Windows app belonging to that same project.
disable-model-invocation: false
metadata:
  version: "2.0.0"
  author: Armin Dashti
  category: devops
  tags: [powershell, reinstall, windows, installer, uninstall, scripts]
  last_updated: "2026-09-01 09:45:00"
  uuid: 68ed37a7-7813-4b48-bf0d-276a10161dcc
---

# Create Script to Reinstall on Win

## When

- User asks to create `reinstall-on-win.ps1` for a Windows desktop / agent app
- User asks for uninstall-then-install, clean reinstall, or remove completely then install again
- User names this skill (`create-script-to-reinstall-on-win`)
- Related: project `build-installer.ps1`, Inno Setup `.iss`, MSI / Setup.exe under `release/` or `dist/`; `C:/Users/armin/.cursor/skills/create-script-to-export-exe/`
- Exclusions: Docker reinstall (use `create-script-to-reinstall-on-docker-local` / `-server`); winget of third-party apps; Android APK reinstall

## How

### Step 1: Detect this project’s install contract

From the **current repo root only**, collect:

| Signal | Use as |
|--------|--------|
| `installer/*.iss` → `AppName` / `#define MyAppName` | Display name to match in Uninstall registry |
| `AppId={{…}}` in `.iss` | Prefer matching uninstall key containing that GUID |
| `build-installer.ps1` / `release\*Setup.exe` / `dist\*Setup.exe` | Installer path under **this** repo |
| Existing product name in docs / `metadata.json` | Fallback display name for **this** product |

If the product name or installer path cannot be inferred, ask the user once. Do not invent a different product name.

### Step 2: Write `scripts/local/<repo_name>/reinstall-on-win.ps1`

| Path | Sample |
|------|--------|
| `scripts/local/<repo_name>/reinstall-on-win.ps1` | [samples/reinstall-on-win.ps1](samples/reinstall-on-win.ps1) |

1. Create `scripts/local/<repo_name>/` if missing
2. If legacy repo-root `reinstall.ps1` exists → cut/align into `scripts/local/<repo_name>/reinstall-on-win.ps1`
3. Start from the sample; replace placeholders with **this** project’s values
4. `#Requires -Version 5.1` and `$ErrorActionPreference = "Stop"`
5. Resolve **project root** as three levels up from `$PSScriptRoot` (`scripts/local/<repo_name>` → repo root). Scope lock: bake `$ProductName` / `$AppIdGuid`; resolve installer **only** under project root

**Runtime contract (reinstall = remove completely, then install again):**

1. `Set-Location` to project root
2. Optionally run this repo’s `build-installer.ps1` when `-Build` is set
3. Search Uninstall registry for only this project’s baked-in `$ProductName` / `$AppIdGuid`
4. If found: silent uninstall of that match only; wait until gone
5. If not installed: print that nothing was removed; continue to install
6. Install this project’s Setup.exe / MSI from under project root only
7. Exit non-zero on install failure

### Step 3: Confirm to the user

- Path of `scripts/local/<repo_name>/reinstall-on-win.ps1`
- Product name and installer path
- How to run: `.\scripts\local\<repo_name>\reinstall-on-win.ps1` (and `-Build` when supported)

## Always

1. Put the file under `./scripts/local/<repo_name>/reinstall-on-win.ps1`.
2. Uninstall **before** install whenever an installed match for this product exists (full remove then install).
3. Prefer silent uninstall / silent install flags.
4. Keep product identity fixed to the project that owns the script.

## Never

1. Uninstall or install a different product, another repo, or a user-supplied product name.
2. Expose `-ProductName` / `-AppIdGuid` params that could retarget another app.
3. Accept an installer path outside the project root.
4. Skip uninstall when a matching installed version of this product exists.
5. Hard-code another machine’s absolute paths.
6. Use this skill for Docker stack reinstall.

## Example

**Example 1 — Inno Setup app**

- Input: “Create reinstall-on-win.ps1 for this Windows agent”
- Output: `scripts/local/<repo_name>/reinstall-on-win.ps1` with product constants; uninstall/install only that product

**Example 2 — Already installed**

- Input: user runs the script
- Output: finds product → silent uninstall → Setup.exe → success

**Example 3 — Not installed yet**

- Input: clean PC
- Output: “No installed version found” → install only

**Example 4 — Rebuild then reinstall**

- Input: `.\scripts\local\<repo_name>\reinstall-on-win.ps1 -Build`
- Output: `build-installer.ps1`, then remove-if-present, then install

**Example 5 — Legacy repo-root file**

- Input: project has `./reinstall.ps1`
- Output: cut/align to `scripts/local/<repo_name>/reinstall-on-win.ps1`

**Example 6 — Wrong skill**

- Input: “reinstall the Docker stack”
- Output: point to `create-script-to-reinstall-on-docker-local` / `-server`
