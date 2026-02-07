# MOV2WAV Architecture (Proposed + Initial Scaffold)

## Architecture summary
- **UI:** Electron + React (Vite) desktop client providing configuration, dry-run, live log tailing, and per-file results.
- **Engine:** PowerShell 5.1 compatible processing layer invoked by the UI via IPC; provides deterministic logging and per-run artifacts.
- **Packaging:** Portable distribution that includes a launcher executable plus a `tools` folder containing `ffmpeg.exe`, `ffprobe.exe`, and `bwfmetaedit.exe`.

## Project structure (new)
```
mov2wav/
  apps/
    desktop/
      electron/
      src/
      package.json
      vite.config.ts
      tsconfig.json
  engine/
    mov2wav.ps1
    modules/
      ResolveCsv.psm1
      Metadata.psm1
      Logging.psm1
  tools/
  config/
    defaults.json
  logs/
  docs/
```

## Implementation plan (step-by-step)
1. **Inventory legacy scripts** and map functions into engine modules (logging, preflight, conversion, metadata, hashing, reports).
2. **Build UI shell** with configuration panels and log/result views.
3. **Implement engine core** in PowerShell 5.1 with single-writer logging and run folder artifacts.
4. **Integrate ffprobe parsing** for timecode, reel, fps, and stream selection.
5. **Implement conversion** using ffmpeg with mapping and deterministic file naming.
6. **Implement metadata** via bwfmetaedit with optional iXML injection and verification mode.
7. **Emit CSV/hash/version artifacts** and integrate with UI results panel.
8. **Package** into portable folder and document distribution steps.

## Migration notes (legacy -> new)
- `scripts/env.bat` -> `config/defaults.json` + UI settings.
- `scripts/main.bat` / `diag_wrapper.bat` -> `engine/mov2wav.ps1` run coordinator with single-writer log.
- `scripts/step_versions.ps1` -> `engine/modules/Logging.psm1` (versions capture).
- `scripts/step_convert.ps1` -> `engine/modules/Metadata.psm1` + `engine/mov2wav.ps1` conversion pipeline.
- `scripts/step_hashes.ps1` -> `engine/modules/ResolveCsv.psm1` + hashing routine.

## Build instructions (initial scaffold)
- Install Node.js 18+.
- From `mov2wav/apps/desktop`:
  - `npm install`
  - `npm run dev`

## Test plan (initial)
- MOV files with embedded timecode.
- DF/NDF timecode detection.
- Missing `bwfmetaedit.exe` handling.
- Multiple audio streams.
- Filenames containing spaces and special characters.
