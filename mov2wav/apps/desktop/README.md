# MOV2WAV Desktop (Windows-first)

MOV2WAV converts MOV files into Resolve-ready WAVs with metadata and reports using the legacy plug-and-play scripts. The workflow is Windows-first and uses PowerShell + batch scripts for repeatable conversion, hashing, and version reporting. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/main.bat†L1-L63】【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/step_convert.ps1†L237-L468】

## Supported OS
- **Windows (primary)**: tested assumptions include PowerShell, batch scripting, and portable tools. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/step_preflight.bat†L23-L33】【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/step_ensure_tools.ps1†L44-L124】
- **macOS/Linux (limited)**: the legacy pipeline is Windows-centric; use the desktop UI for configuration only, or run via Windows VM if needed.

## Prerequisites
- **PowerShell** available in PATH. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/step_preflight.bat†L23-L33】
- **FFmpeg + ffprobe** (portable tools are downloaded automatically on Windows). 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/step_ensure_tools.ps1†L44-L93】
- **BWF MetaEdit (optional but recommended)** for BWF/iXML metadata injection (also downloaded automatically). 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/step_ensure_tools.ps1†L94-L124】
- **Python 3** only if you run `mov2wav_resolve_conform.bat` directly. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/mov2wav_resolve_conform.bat†L28-L55】

## Install
```powershell
npm install
```

## Configuration
The single source of configuration lives at:
```
mov2wav/apps/desktop/mov2wav_pnp/config/mov2wav.config.json
```
Update the `conversion` and `injection` sections as needed (paths can be absolute or relative to repo root). 【F:mov2wav/apps/desktop/mov2wav_pnp/config/mov2wav.config.json†L1-L19】

## Usage
### Doctor (preflight + tool checks)
```powershell
./tools/mov2wav.ps1 doctor
```
Runs the legacy preflight and tool checks, plus a repo-hygiene scan for tracked build outputs. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/step_preflight.bat†L1-L90】【F:tools/mov2wav.ps1†L118-L219】

### Convert (MOV → WAV)
```powershell
./tools/mov2wav.ps1 convert --in "D:\Media\MOV" --out "D:\Media\WAV"
```
This delegates to the legacy `main.bat` conversion pipeline and then copies the output WAVs/reports into the requested output folder. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/main.bat†L1-L63】【F:tools/mov2wav.ps1†L221-L286】

### Run (legacy plug-and-play)
```powershell
./tools/mov2wav.ps1 run
```
Executes `RUN_MOV2WAV_PLUGPLAY.bat` in the configured input directory for a portable, one-shot run. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/RUN_MOV2WAV_PLUGPLAY.bat†L1-L240】【F:tools/mov2wav.ps1†L288-L317】

### Desktop CLI bridge
The desktop app is wired with a CLI bridge so you can trigger the same pipeline via npm scripts:
```powershell
npm run mov2wav:doctor
npm run mov2wav:convert -- --in "D:\Media\MOV" --out "D:\Media\WAV"
```
The bridge script calls `tools/mov2wav.ps1` from any working directory. 【F:mov2wav/apps/desktop/scripts/mov2wav-cli.cjs†L1-L35】【F:mov2wav/apps/desktop/package.json†L5-L12】

## Troubleshooting
- **PATH issues**: `doctor` will report missing PowerShell or portable tools and log the resolved paths. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/step_preflight.bat†L23-L81】【F:tools/mov2wav.ps1†L170-L219】
- **Missing tools**: ensure downloads succeed (network access required for portable tool fetch). 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/step_ensure_tools.ps1†L44-L124】
- **FFmpeg failures**: check the run log in `.runlogs/` and the legacy logs in `mov2wav/apps/desktop/mov2wav_pnp/logs`. 【F:tools/mov2wav.ps1†L52-L115】【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/step_convert.ps1†L313-L365】
- **Metadata missing**: install/allow `bwfmetaedit.exe` or inspect warnings in the logs. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/step_convert.ps1†L353-L425】

## Logs
- Structured logs: `.runlogs/mov2wav_<command>_<timestamp>.log`. 【F:tools/mov2wav.ps1†L52-L115】
- Legacy logs: `mov2wav/apps/desktop/mov2wav_pnp/logs/`. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/env.bat†L12-L21】

## Repo hygiene
Build outputs and runtime artifacts are ignored to keep the repo clean. This includes:
- `node_modules/`, `dist/`, `build/`, `out/`, `release/`, `.vite/`, `.turbo/`, `.cache/`
- Legacy runtime folders like `.runlogs/`, `logs/`, `out_wav/`, `renamed_mov/`, and `tools/`.

See `.gitignore` for the full list. 【F:.gitignore†L23-L77】
