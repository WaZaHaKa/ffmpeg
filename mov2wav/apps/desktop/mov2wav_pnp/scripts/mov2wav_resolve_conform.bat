@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM mov2wav_resolve_conform.bat
REM Run this .bat INSIDE a folder containing .mov files.
REM It will:
REM  - convert .mov -> .wav (PCM 24-bit) using ffmpeg
REM  - extract timecode + fps via ffprobe
REM  - write BWF(BEXT) fields + richer iXML via bwfmetaedit (recommended)
REM  - mirror filename/reel into BWF fields
REM  - generate a CSV report for Resolve conform
REM ============================================================

REM ----- Configuration (edit if you want) -----
set "OUTDIR=out_wav"
set "SAMPLE_RATE=48000"
set "CHANNELS=2"
set "RECURSIVE=1"
REM -------------------------------------------

REM ----- Resolve working directory (folder where this bat is run) -----
set "WORKDIR=%CD%"
set "OUTPATH=%WORKDIR%\%OUTDIR%"

if not exist "%OUTPATH%" mkdir "%OUTPATH%" >nul 2>nul

REM ----- Check required tools -----
where python >nul 2>nul
if errorlevel 1 (
  echo [ERROR] python not found in PATH. Install Python 3 and ensure "python" works in cmd.
  pause
  exit /b 2
)

where ffmpeg >nul 2>nul
if errorlevel 1 (
  echo [ERROR] ffmpeg not found in PATH. Install FFmpeg and add it to PATH.
  pause
  exit /b 2
)

where ffprobe >nul 2>nul
if errorlevel 1 (
  echo [ERROR] ffprobe not found in PATH. Install FFmpeg and add it to PATH.
  pause
  exit /b 2
)

where bwfmetaedit >nul 2>nul
if errorlevel 1 (
  echo [WARN] bwfmetaedit not found in PATH. Conversions will work, but BWF/iXML metadata may NOT be embedded.
  echo        Recommended: install "BWF MetaEdit" (MediaArea) and add to PATH.
)

REM ----- Create an embedded python script in %TEMP% -----
set "PYFILE=%TEMP%\mov2wav_resolve_conform_%RANDOM%%RANDOM%.py"

> "%PYFILE%" (
  echo # -*- coding: utf-8 -*-
  echo import argparse, csv, datetime as dt, json, os, re, shutil, subprocess, sys, tempfile
  echo from pathlib import Path
  echo from typing import Optional, List, Dict, Any, Tuple
  echo
  echo TIMECODE_RE = re.compile(r"^(?P^<h^>\d{2}):(?P^<m^>\d{2}):(?P^<s^>\d{2})([:;])(?P^<f^>\d{2})$")
  echo
  echo def which(exe: str) ^-> Optional[str]:
  echo     return shutil.which(exe)
  echo
  echo def run(cmd: List[str], check: bool = True) ^-> subprocess.CompletedProcess:
  echo     return subprocess.run(cmd, capture_output=True, text=True, check=check)
  echo
  echo def ffprobe_json(in_path: Path) ^-> dict:
  echo     cmd = ["ffprobe","-v","error","-print_format","json","-show_format","-show_streams",str(in_path)]
  echo     cp = run(cmd, check=True)
  echo     return json.loads(cp.stdout)
  echo
  echo def parse_rate(rate_str: str) ^-> Optional[float]:
  echo     try:
  echo         if not rate_str or rate_str == "0/0":
  echo             return None
  echo         if "/" in rate_str:
  echo             a,b = rate_str.split("/",1)
  echo             a=float(a.strip()); b=float(b.strip())
  echo             if b==0: return None
  echo             return a/b
  echo         return float(rate_str)
  echo     except Exception:
  echo         return None
  echo
  echo def pick_video_fps(probe: dict) ^-> Optional[float]:
  echo     for st in probe.get("streams", []):
  echo         if st.get("codec_type") == "video":
  echo             fps = parse_rate(st.get("avg_frame_rate","")) or parse_rate(st.get("r_frame_rate",""))
  echo             if fps and fps ^> 0.1:
  echo                 return fps
  echo     return None
  echo
  echo def _collect_all_tags(probe: dict) ^-> Dict[str,str]:
  echo     tags: Dict[str,str] = {}
  echo     fmt = probe.get("format", {}) or {}
  echo     fmt_tags = (fmt.get("tags", {}) or {})
  echo     for k,v in fmt_tags.items():
  echo         if isinstance(v,str):
  echo             tags[str(k).lower()] = v
  echo     for st in probe.get("streams", []) or []:
  echo         st_tags = (st.get("tags", {}) or {})
  echo         for k,v in st_tags.items():
  echo             if isinstance(v,str):
  echo                 lk=str(k).lower()
  echo                 if lk not in tags:
  echo                     tags[lk] = v
  echo     return tags
  echo
  echo def extract_timecode(probe: dict) ^-> Optional[str]:
  echo     tags = _collect_all_tags(probe)
  echo     for key in ["timecode","com.apple.quicktime.timecode","smpte_tc","tc"]:
  echo         v = tags.get(key)
  echo         if isinstance(v,str) and TIMECODE_RE.match(v.strip()):
  echo             return v.strip()
  echo     for v in tags.values():
  echo         vv = v.strip()
  echo         if TIMECODE_RE.match(vv):
  echo             return vv
  echo     return None
  echo
  echo def extract_creation_time_utc(probe: dict) ^-> Optional[dt.datetime]:
  echo     tags = _collect_all_tags(probe)
  echo     ct = tags.get("creation_time")
  echo     if not isinstance(ct,str):
  echo         return None
  echo     try:
  echo         s=ct.strip()
  echo         if s.endswith("Z"): s=s[:-1] + "+00:00"
  echo         return dt.datetime.fromisoformat(s).astimezone(dt.timezone.utc)
  echo     except Exception:
  echo         return None
  echo
  echo def extract_reel_name(probe: dict, fallback: str) ^-> str:
  echo     tags = _collect_all_tags(probe)
  echo     candidates = ["reel_name","reel","tape","roll","camera_roll","com.apple.quicktime.reel","com.apple.quicktime.tape","com.apple.quicktime.roll"]
  echo     for k in candidates:
  echo         v = tags.get(k)
  echo         if isinstance(v,str) and v.strip():
  echo             return v.strip()
  echo     return fallback
  echo
  echo def timecode_to_seconds(tc: str, fps: float) ^-> Optional[float]:
  echo     m = TIMECODE_RE.match(tc.strip())
  echo     if not m or not fps or fps ^<= 0:
  echo         return None
  echo     h=int(m.group("h")); mi=int(m.group("m")); s=int(m.group("s")); f=int(m.group("f"))
  echo     return (h*3600) + (mi*60) + s + (f/fps)
  echo
  echo def seconds_to_bwf_time_reference_samples(seconds_since_midnight: float, sample_rate: int) ^-> int:
  echo     if seconds_since_midnight ^< 0: seconds_since_midnight = 0
  echo     return int(round(seconds_since_midnight * sample_rate))
  echo
  echo def ensure_dir(p: Path) ^-> None:
  echo     p.mkdir(parents=True, exist_ok=True)
  echo
  echo def convert_to_wav(in_path: Path, out_path: Path, sample_rate: int, channels: int) ^-> None:
  echo     cmd = ["ffmpeg","-y","-hide_banner","-loglevel","error","-i",str(in_path),"-vn","-ac",str(channels),"-ar",str(sample_rate),"-c:a","pcm_s24le",str(out_path)]
  echo     run(cmd, check=True)
  echo
  echo def escape_xml(s: str) ^-> str:
  echo     return s.replace("^&","^&amp;").replace("^<","^&lt;").replace("^>","^&gt;").replace('"',"^&quot;").replace("'","^&apos;")
  echo
  echo def build_ixml(file_name: str, reel_name: str, timecode: Optional[str], fps: Optional[float], sample_rate: int, channels: int, origination_utc: Optional[dt.datetime]) ^-> str:
  echo     tc_str = timecode or "00:00:00:00"
  echo     fps_str = (f"{fps:.6f}".rstrip("0").rstrip(".")) if fps else ""
  echo     date_str = origination_utc.strftime("%%Y-%%m-%%d") if origination_utc else ""
  echo     time_str = origination_utc.strftime("%%H:%%M:%%S") if origination_utc else ""
  echo     flag = "DF" if (timecode and ";" in timecode) else "NDF"
  echo     return f"""^<?xml version="1.0" encoding="UTF-8"^?>
  echo ^<IXML_VERSION^>1.5^</IXML_VERSION^>
  echo ^<IXML^>
  echo   ^<PROJECT^>Resolve_Conform^</PROJECT^>
  echo   ^<TAPE^>{escape_xml(reel_name)}^</TAPE^>
  echo   ^<FILE_NAME^>{escape_xml(file_name)}^</FILE_NAME^>
  echo   ^<SPEED^>
  echo     ^<TIMECODE_RATE^>{escape_xml(fps_str)}^</TIMECODE_RATE^>
  echo     ^<TIMECODE_FLAG^>{flag}^</TIMECODE_FLAG^>
  echo   ^</SPEED^>
  echo   ^<TIMECODE^>
  echo     ^<TIMECODE_START^>{escape_xml(tc_str)}^</TIMECODE_START^>
  echo   ^</TIMECODE^>
  echo   ^<BWF^>
  echo     ^<BWF_SAMPLE_RATE^>{sample_rate}^</BWF_SAMPLE_RATE^>
  echo     ^<BWF_CHANNEL_COUNT^>{channels}^</BWF_CHANNEL_COUNT^>
  echo     ^<BWF_ORIGINATION_DATE^>{escape_xml(date_str)}^</BWF_ORIGINATION_DATE^>
  echo     ^<BWF_ORIGINATION_TIME^>{escape_xml(time_str)}^</BWF_ORIGINATION_TIME^>
  echo   ^</BWF^>
  echo   ^<TRACK_LIST^>
  echo     ^<TRACK_COUNT^>{channels}^</TRACK_COUNT^>
  echo   ^</TRACK_LIST^>
  echo ^</IXML^>
  echo """
  echo
  echo def try_bwfmetaedit(args: List[str]) ^-> Tuple[bool,str]:
  echo     try:
  echo         cp = run(["bwfmetaedit"] + args, check=True)
  echo         return True, (cp.stdout or "").strip()
  echo     except subprocess.CalledProcessError as e:
  echo         msg = ((e.stderr or "") + "\n" + (e.stdout or "")).strip()
  echo         return False, msg
  echo     except Exception as e:
  echo         return False, str(e)
  echo
  echo def write_bwf_and_ixml(wav_path: Path, file_name: str, reel_name: str, origination_dt_utc: Optional[dt.datetime], time_reference_samples: Optional[int], ixml_xml: Optional[str]) ^-> Tuple[bool,str]:
  echo     if not which("bwfmetaedit"):
  echo         return False, "bwfmetaedit not found"
  echo     desc = f"{file_name} ^| REEL={reel_name}"
  echo     originator_ref = reel_name
  echo     a: List[str] = []
  echo     if origination_dt_utc:
  echo         a += ["--OriginationDate=" + origination_dt_utc.strftime("%%Y-%%m-%%d")]
  echo         a += ["--OriginationTime=" + origination_dt_utc.strftime("%%H:%%M:%%S")]
  echo     if time_reference_samples is not None:
  echo         a += ["--TimeReference=" + str(time_reference_samples)]
  echo     a += ["--Description=" + desc]
  echo     a += ["--OriginatorReference=" + originator_ref]
  echo     ok,msg = try_bwfmetaedit(a + [str(wav_path)])
  echo     if not ok:
  echo         return False, "BWF write failed: " + msg
  echo     if ixml_xml:
  echo         with tempfile.NamedTemporaryFile("w", suffix=".xml", delete=False, encoding="utf-8") as tf:
  echo             tf.write(ixml_xml)
  echo             tf_path = tf.name
  echo         variants = [f"--inxml={tf_path}", f"--iXML={tf_path}", f"--IXML={tf_path}", f"--ixml={tf_path}"]
  echo         iok=False; imsg=""
  echo         for flag in variants:
  echo             ok2,msg2 = try_bwfmetaedit([flag, str(wav_path)])
  echo             if ok2:
  echo                 iok=True; imsg=msg2; break
  echo             else:
  echo                 imsg=msg2
  echo         try:
  echo             os.unlink(tf_path)
  echo         except Exception:
  echo             pass
  echo         if not iok:
  echo             return True, "BWF ok; iXML write failed/not supported: " + imsg
  echo     return True, "BWF+iXML ok"
  echo
  echo def gather_movs(root: Path, recursive: bool) ^-> List[Path]:
  echo     if recursive:
  echo         return [p for p in root.rglob("*.mov")]
  echo     return [p for p in root.glob("*.mov")]
  echo
  echo def main() ^-> int:
  echo     ap = argparse.ArgumentParser()
  echo     ap.add_argument("--root", required=True)
  echo     ap.add_argument("--out", required=True)
  echo     ap.add_argument("--sr", type=int, default=48000)
  echo     ap.add_argument("--ch", type=int, default=2)
  echo     ap.add_argument("--recursive", action="store_true")
  echo     ap.add_argument("--csv", required=True)
  echo     ap.add_argument("--no-bwf", action="store_true")
  echo     ap.add_argument("--no-ixml", action="store_true")
  echo     ap.add_argument("--verbose", action="store_true")
  echo     args = ap.parse_args()
  echo
  echo     root = Path(args.root).resolve()
  echo     outdir = Path(args.out).resolve()
  echo     outdir.mkdir(parents=True, exist_ok=True)
  echo     movs = gather_movs(root, args.recursive)
  echo     if not movs:
  echo         print("No .mov files found.")
  echo         return 1
  echo
  echo     rows: List[Dict[str,Any]] = []
  echo     for mov in movs:
  echo         row: Dict[str,Any] = {
  echo             "input_mov": str(mov),
  echo             "output_wav": "",
  echo             "file_name": mov.name,
  echo             "reel_name": "",
  echo             "creation_time_utc": "",
  echo             "timecode": "",
  echo             "fps": "",
  echo             "sample_rate": args.sr,
  echo             "channels": args.ch,
  echo             "bwf_time_reference_samples": "",
  echo             "metadata_written": False,
  echo             "metadata_message": "",
  echo         }
  echo         try:
  echo             probe = ffprobe_json(mov)
  echo             fps = pick_video_fps(probe)
  echo             tc = extract_timecode(probe)
  echo             creation_utc = extract_creation_time_utc(probe)
  echo             reel = extract_reel_name(probe, fallback=mov.stem)
  echo
  echo             out_wav = outdir / (mov.stem + ".wav")
  echo             convert_to_wav(mov, out_wav, args.sr, args.ch)
  echo
  echo             time_ref = None
  echo             if tc and fps:
  echo                 secs = timecode_to_seconds(tc, fps)
  echo                 if secs is not None:
  echo                     time_ref = seconds_to_bwf_time_reference_samples(secs, args.sr)
  echo
  echo             ixml_xml = None
  echo             if not args.no_ixml:
  echo                 ixml_xml = build_ixml(mov.name, reel, tc, fps, args.sr, args.ch, creation_utc)
  echo
  echo             wrote=False; msg=""
  echo             if not args.no_bwf:
  echo                 wrote,msg = write_bwf_and_ixml(out_wav, mov.name, reel, creation_utc, time_ref, ixml_xml)
  echo
  echo             row["output_wav"] = str(out_wav)
  echo             row["reel_name"] = reel
  echo             row["creation_time_utc"] = creation_utc.isoformat() if creation_utc else ""
  echo             row["timecode"] = tc or ""
  echo             row["fps"] = (f"{fps:.6f}".rstrip("0").rstrip(".")) if fps else ""
  echo             row["bwf_time_reference_samples"] = str(time_ref) if time_ref is not None else ""
  echo             row["metadata_written"] = bool(wrote)
  echo             row["metadata_message"] = msg
  echo             rows.append(row)
  echo
  echo             if args.verbose:
  echo                 print(str(out_wav))
  echo         except subprocess.CalledProcessError as e:
  echo             emsg = (e.stderr or e.stdout or str(e)).strip()
  echo             row["metadata_message"] = "ERROR: " + emsg
  echo             rows.append(row)
  echo             print(f"[ERROR] {mov}: {emsg}", file=sys.stderr)
  echo         except Exception as e:
  echo             row["metadata_message"] = "ERROR: " + str(e)
  echo             rows.append(row)
  echo             print(f"[ERROR] {mov}: {e}", file=sys.stderr)
  echo
  echo     # CSV report
  echo     fieldnames = ["input_mov","output_wav","file_name","reel_name","creation_time_utc","timecode","fps","sample_rate","channels","bwf_time_reference_samples","metadata_written","metadata_message"]
  echo     with open(args.csv, "w", newline="", encoding="utf-8") as f:
  echo         w = csv.DictWriter(f, fieldnames=fieldnames)
  echo         w.writeheader()
  echo         for r in rows:
  echo             w.writerow(r)
  echo
  echo     print(args.csv)
  echo     return 0
  echo
  echo if __name__ == "__main__":
  echo     raise SystemExit(main())
)

REM ----- Choose recursive flag -----
set "RECFLAG="
if "%RECURSIVE%"=="1" set "RECFLAG=--recursive"

REM ----- CSV report path (timestamped) -----
for /f "tokens=1-3 delims=/:. " %%a in ("%date% %time%") do (
  set "d1=%%a"
  set "d2=%%b"
  set "d3=%%c"
)
REM safer timestamp via powershell
for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%t"
set "CSVPATH=%OUTPATH%\resolve_conform_report_%TS%.csv"

echo.
echo [INFO] Working folder : "%WORKDIR%"
echo [INFO] Output folder  : "%OUTPATH%"
echo [INFO] CSV report     : "%CSVPATH%"
echo [INFO] Sample rate    : %SAMPLE_RATE%
echo [INFO] Channels       : %CHANNELS%
echo [INFO] Recursive      : %RECURSIVE%
echo.

REM ----- Run conversion over current folder -----
python "%PYFILE%" ^
  --root "%WORKDIR%" ^
  --out "%OUTPATH%" ^
  --sr %SAMPLE_RATE% ^
  --ch %CHANNELS% ^
  %RECFLAG% ^
  --csv "%CSVPATH%"

set "EXITCODE=%ERRORLEVEL%"

REM ----- Cleanup embedded python -----
del "%PYFILE%" >nul 2>nul

echo.
if not "%EXITCODE%"=="0" (
  echo [DONE WITH ERRORS] Exit code: %EXITCODE%
  echo Check messages above. CSV still may have partial results: "%CSVPATH%"
  pause
  exit /b %EXITCODE%
)

echo [DONE] WAVs in: "%OUTPATH%"
echo [DONE] CSV: "%CSVPATH%"
if /i "%NO_PAUSE%"=="1" goto :nopause
pause
:nopause
exit /b 0
