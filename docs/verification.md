# Verification checklist

## Local commands
### Pipeline checks
```powershell
# Preflight + tool checks + repo hygiene scan
./tools/mov2wav.ps1 doctor

# Conversion pipeline (MOV → WAV)
./tools/mov2wav.ps1 convert --in "D:\Media\MOV" --out "D:\Media\WAV"

# Legacy plug-and-play run
./tools/mov2wav.ps1 run
```
Expected:
- Logs created under `.runlogs/`.
- WAVs + reports copied to the output directory after conversion.

### Desktop CLI bridge
```powershell
npm run mov2wav:doctor
npm run mov2wav:convert -- --in "D:\Media\MOV" --out "D:\Media\WAV"
```
Expected:
- The CLI bridge delegates to `tools/mov2wav.ps1` from any working directory.

## Repo hygiene checks
```powershell
# No tracked build artifacts
./tools/mov2wav.ps1 doctor

# Status should be clean after running tools (runtime outputs are ignored)
git status

# Windows check for tracked outputs (if you suspect artifacts)
git ls-files | findstr /i "node_modules dist build out release .runlogs out_wav logs renamed_mov tools"
```
Expected:
- No build artifacts show up in `git status`.
- `git ls-files` does not list ignored build outputs.
