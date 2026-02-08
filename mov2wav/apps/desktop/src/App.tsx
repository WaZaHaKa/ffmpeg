import { useMemo, useState } from "react";
import "./app.css";

type AudioStreamOption = "stream0" | "stream1" | "all";

type ResultRow = {
  source: string;
  output: string;
  timecode: string;
  reel: string;
  status: "Ready" | "Dry run" | "Missing metadata" | "Error";
};

const mockSources = [
  "camera_A_001.mov",
  "mixdown_final.mp4",
  "sceneB_take3.mxf"
];

const now = () => new Date().toLocaleTimeString("en-US", { hour12: false });

export function App() {
  const [inputFolder, setInputFolder] = useState("");
  const [outputFolder, setOutputFolder] = useState("");
  const [filterMode, setFilterMode] = useState("mov");
  const [audioStream, setAudioStream] = useState<AudioStreamOption>("stream0");
  const [sampleRate, setSampleRate] = useState("48000");
  const [bitDepth, setBitDepth] = useState("pcm_s24le");
  const [channels, setChannels] = useState("stereo");
  const [normalize, setNormalize] = useState(false);
  const [embedIXML, setEmbedIXML] = useState(false);
  const [dryRun, setDryRun] = useState(false);
  const [running, setRunning] = useState(false);
  const [logLines, setLogLines] = useState<string[]>([
    "[00:00:00] Ready. Waiting for configuration..."
  ]);
  const [results, setResults] = useState<ResultRow[]>([]);

  const canRun = useMemo(() => {
    return inputFolder.trim().length > 0 && outputFolder.trim().length > 0;
  }, [inputFolder, outputFolder]);

  const startRun = () => {
    if (!canRun || running) {
      setLogLines((prev) => [
        ...prev,
        `[${now()}] Please select input and output folders before running.`
      ]);
      return;
    }

    setRunning(true);
    const logPrefix = dryRun ? "DRY RUN" : "RUN";
    const baseLogs = [
      `[${now()}] ${logPrefix} started for ${inputFolder}.`,
      `[${now()}] Output path: ${outputFolder}.`,
      `[${now()}] Format filter: ${filterMode === "mov" ? "MOV only" : "All supported"}.`,
      `[${now()}] Audio: ${sampleRate} Hz, ${channels}, ${bitDepth}.`,
      `[${now()}] Normalize: ${normalize ? "on" : "off"}.`,
      `[${now()}] Embed iXML: ${embedIXML ? "on" : "off"}.`,
      `[${now()}] Audio stream selection: ${audioStream}.`
    ];

    setLogLines((prev) => [...prev, ...baseLogs]);

    const nextResults = mockSources.map((source, index) => ({
      source,
      output: source.replace(/\.[^.]+$/, ".wav"),
      timecode: index === 1 ? "00:59:58:12" : "01:00:00:00",
      reel: index === 1 ? "MXD1" : "A001",
      status: dryRun ? "Dry run" : index === 1 ? "Missing metadata" : "Ready"
    }));

    setResults(nextResults);
    setLogLines((prev) => [
      ...prev,
      `[${now()}] ${dryRun ? "Probed" : "Converted"} ${nextResults.length} files.`,
      `[${now()}] ${logPrefix} complete.`
    ]);
    setRunning(false);
  };

  const stopRun = () => {
    if (!running) {
      setLogLines((prev) => [...prev, `[${now()}] No active run to stop.`]);
      return;
    }
    setRunning(false);
    setLogLines((prev) => [...prev, `[${now()}] Run stopped by user.`]);
  };

  return (
    <div className="app">
      <header className="app__header">
        <div>
          <h1>MOV2WAV</h1>
          <p>Offline conform pipeline for Resolve-ready WAV + metadata</p>
        </div>
        <div className="wallet">
          <span className="wallet__label">Wallet Connect</span>
          <button type="button">Mock Connect</button>
        </div>
      </header>

      <section className="grid">
        <div className="panel">
          <h2>Sources</h2>
          <div className="field">
            <label>Input folder</label>
            <div className="row">
              <input
                placeholder="Select input folder"
                value={inputFolder}
                onChange={(event) => setInputFolder(event.target.value)}
              />
              <button type="button">Browse</button>
            </div>
          </div>
          <div className="field">
            <label>Output folder</label>
            <div className="row">
              <input
                placeholder="Select output folder"
                value={outputFolder}
                onChange={(event) => setOutputFolder(event.target.value)}
              />
              <button type="button">Browse</button>
            </div>
          </div>
          <div className="field">
            <label>Format filters</label>
            <select value={filterMode} onChange={(event) => setFilterMode(event.target.value)}>
              <option value="mov">MOV only</option>
              <option value="all">All supported formats</option>
            </select>
          </div>
          <div className="field">
            <label>Audio stream selection</label>
            <select
              value={audioStream}
              onChange={(event) => setAudioStream(event.target.value as AudioStreamOption)}
            >
              <option value="stream0">Stream 0 (default)</option>
              <option value="stream1">Stream 1</option>
              <option value="all">All streams to multichannel WAV</option>
            </select>
          </div>
        </div>

        <div className="panel">
          <h2>Audio + Metadata</h2>
          <div className="field">
            <label>Sample rate</label>
            <select value={sampleRate} onChange={(event) => setSampleRate(event.target.value)}>
              <option value="48000">48kHz</option>
              <option value="44100">44.1kHz</option>
              <option value="96000">96kHz</option>
            </select>
          </div>
          <div className="field">
            <label>Bit depth</label>
            <select value={bitDepth} onChange={(event) => setBitDepth(event.target.value)}>
              <option value="pcm_s24le">pcm_s24le</option>
              <option value="pcm_s16le">pcm_s16le</option>
              <option value="pcm_s32le">pcm_s32le</option>
            </select>
          </div>
          <div className="field">
            <label>Channels</label>
            <select value={channels} onChange={(event) => setChannels(event.target.value)}>
              <option value="stereo">Stereo</option>
              <option value="mono">Mono</option>
            </select>
          </div>
          <div className="field check">
            <label>
              <input
                type="checkbox"
                checked={normalize}
                onChange={(event) => setNormalize(event.target.checked)}
              />{" "}
              Normalize audio (off by default)
            </label>
          </div>
          <div className="field check">
            <label>
              <input
                type="checkbox"
                checked={embedIXML}
                onChange={(event) => setEmbedIXML(event.target.checked)}
              />{" "}
              Embed iXML chunk
            </label>
          </div>
        </div>

        <div className="panel">
          <h2>Run</h2>
          <div className="field check">
            <label>
              <input
                type="checkbox"
                checked={dryRun}
                onChange={(event) => setDryRun(event.target.checked)}
              />{" "}
              Dry run (probe only)
            </label>
          </div>
          <div className="row">
            <button
              type="button"
              className="primary"
              onClick={startRun}
              disabled={!canRun || running}
            >
              {running ? "Running..." : "Start Run"}
            </button>
            <button type="button" onClick={stopRun}>
              Stop
            </button>
          </div>
          <div className="logs">
            <div className="logs__header">Live Logs</div>
            <pre>
              {logLines.map((line) => (
                <span key={line}>
                  {line}
                  {"\n"}
                </span>
              ))}
            </pre>
          </div>
        </div>
      </section>

      <section className="panel results">
        <div className="results__header">
          <h2>Results</h2>
          <span>{results.length} files</span>
        </div>
        <table>
          <thead>
            <tr>
              <th>Source</th>
              <th>Output</th>
              <th>Timecode</th>
              <th>Reel</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {results.length === 0 ? (
              <tr>
                <td colSpan={5} className="results__empty">
                  No results yet. Configure input/output folders and start a run.
                </td>
              </tr>
            ) : (
              results.map((row) => (
                <tr key={row.source}>
                  <td>{row.source}</td>
                  <td>{row.output}</td>
                  <td>{row.timecode}</td>
                  <td>{row.reel}</td>
                  <td className={`status ${row.status === "Error" ? "error" : row.status === "Missing metadata" ? "warn" : "ok"}`}>
                    {row.status}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </section>
    </div>
  );
}
