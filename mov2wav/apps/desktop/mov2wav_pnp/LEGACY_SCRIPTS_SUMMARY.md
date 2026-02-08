# Legacy mov2wav PnP automation summary

## Entrypoints (what users run first)
- `RUN_MOV2WAV_PLUGPLAY.bat`: one-shot portable pipeline that bootstraps tools, converts MOVs to WAVs, embeds metadata, and writes reports in the current working directory. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/RUN_MOV2WAV_PLUGPLAY.bat†L1-L240】
- `main.bat`: modular pipeline entry that runs preflight → tools → versions → convert → hashes. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/main.bat†L1-L63】
- `diag_wrapper.bat`: wrapper that creates a per-run log folder and captures all output from `main.bat`. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/diag_wrapper.bat†L1-L93】
- `mov2wav_resolve_conform.bat` (and `*_WRAPPER_LOGGER.bat`): legacy Resolve-style pipeline using embedded Python, with optional wrapper logging. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/mov2wav_resolve_conform.bat†L1-L222】【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/mov2wav_resolve_conform_WRAPPER_LOGGER.bat†L1-L59】
- `main_injection.bat`: injection pipeline orchestrator (rename → report → hashes → versions). 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/main_injection.bat†L1-L64】
- Scaffold creators: `CREATE_MOV2WAV_PNP_SCAFFOLD.bat`, `CREATE_INJECTION_SCAFFOLD*.bat`, and placeholder fixer `FIX_MOV2WAV_PNP_PS1_PLACEHOLDERS.bat`. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/CREATE_MOV2WAV_PNP_SCAFFOLD.bat†L1-L113】【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/CREATE_INJECTION_SCAFFOLD.bat†L1-L102】【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/CREATE_INJECTION_SCAFFOLD_V2.bat†L1-L101】【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/FIX_MOV2WAV_PNP_PS1_PLACEHOLDERS.bat†L1-L57】

## Environment variables (consumed/produced)
- Core conversion vars (set by `env.bat`): `PROJ`, `TOOLS`, `LOGS`, `OUT_WAV`, `DIST`, `BUILD`, `SRC`, `INPUT_DIR`, `AUDIO_SR`, `AUDIO_CH`, `AUDIO_CODEC`, `DO_METADATA`, `DO_IXML`, `DO_CSV`, `DO_HASH`, `DO_VERSIONS`. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/env.bat†L9-L52】
- Injection vars (set by `inject_config.bat` after reading JSON): `INJECT_ROOT`, `INJECT_GLOB`, `RENAMED_DIR`, `LOG_DIR`, `NAME_TEMPLATE`, `DO_RENAME`, `DO_CSV`, `DO_HASH`, `DO_VERSIONS`, `TOOLS_DIR`. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/inject_config.bat†L5-L66】

## Expected folder layout
- Conversion pipeline writes to `tools/`, `logs/`, `out_wav/`, `dist/`, `build/`, `src/` under the project root (`PROJ`). 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/env.bat†L12-L21】
- Injection scaffold expects `tools/`, `logs/`, `dist/`, `build/`, `src/`, `renamed_mov/` folders. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/CREATE_INJECTION_SCAFFOLD_V2.bat†L14-L17】

## Tool dependencies
- PowerShell is required for the core pipeline and downloaders. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/step_preflight.bat†L23-L33】
- `ffmpeg.exe` + `ffprobe.exe` (portable download) and `bwfmetaedit.exe` for metadata injection are fetched in `step_ensure_tools.ps1`. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/step_ensure_tools.ps1†L44-L124】
- The Resolve-style batch (`mov2wav_resolve_conform.bat`) relies on Python + PATH-resolved `ffmpeg`, `ffprobe`, and optionally `bwfmetaedit`. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/mov2wav_resolve_conform.bat†L28-L55】

## Placeholder tokens and injection points
- Injection naming uses a `NAME_TEMPLATE` with token placeholders like `{date}`, `{time}`, `{n}`, `{stem}`. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/inject_config.bat†L29-L37】
- The injection steps are split across `inject_rename.bat` (rename logic), `inject_report.ps1` (CSV report), `inject_hashes.ps1` (hashes), and `inject_versions.ps1` (tool versions). 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/inject_rename.bat†L1-L6】【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/inject_report.ps1†L1-L20】【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/inject_hashes.ps1†L1-L17】【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/inject_versions.ps1†L1-L18】

## Outputs generated
- Conversion outputs: WAVs in `out_wav/`, Resolve-compatible CSV report, and run logs. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/step_convert.ps1†L237-L264】【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/step_convert.ps1†L430-L468】
- Hash manifest: `wav_hashes_*.csv` in `out_wav/`. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/step_hashes.ps1†L20-L55】
- Versions snapshot: `versions_*.json` in `logs/`. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/step_versions.ps1†L50-L101】
- Wrapper artifacts: per-run `logs/run_*` folders plus copied artifacts from `diag_wrapper.bat`. 【F:mov2wav/apps/desktop/mov2wav_pnp/scripts/diag_wrapper.bat†L21-L83】
