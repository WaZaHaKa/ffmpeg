import "./app.css";

export function App() {
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
              <input placeholder="Select input folder" />
              <button type="button">Browse</button>
            </div>
          </div>
          <div className="field">
            <label>Output folder</label>
            <div className="row">
              <input placeholder="Select output folder" />
              <button type="button">Browse</button>
            </div>
          </div>
          <div className="field">
            <label>Format filters</label>
            <select>
              <option>MOV only</option>
              <option>All supported formats</option>
            </select>
          </div>
          <div className="field">
            <label>Audio stream selection</label>
            <select>
              <option>Stream 0 (default)</option>
              <option>Stream 1</option>
              <option>All streams to multichannel WAV</option>
            </select>
          </div>
        </div>

        <div className="panel">
          <h2>Audio + Metadata</h2>
          <div className="field">
            <label>Sample rate</label>
            <select>
              <option>48kHz</option>
              <option>44.1kHz</option>
              <option>96kHz</option>
            </select>
          </div>
          <div className="field">
            <label>Bit depth</label>
            <select>
              <option>pcm_s24le</option>
              <option>pcm_s16le</option>
              <option>pcm_s32le</option>
            </select>
          </div>
          <div className="field">
            <label>Channels</label>
            <select>
              <option>Stereo</option>
              <option>Mono</option>
            </select>
          </div>
          <div className="field check">
            <label>
              <input type="checkbox" /> Normalize audio (off by default)
            </label>
          </div>
          <div className="field check">
            <label>
              <input type="checkbox" /> Embed iXML chunk
            </label>
          </div>
        </div>

        <div className="panel">
          <h2>Run</h2>
          <div className="field check">
            <label>
              <input type="checkbox" /> Dry run (probe only)
            </label>
          </div>
          <div className="row">
            <button type="button" className="primary">
              Start Run
            </button>
            <button type="button">Stop</button>
          </div>
          <div className="logs">
            <div className="logs__header">Live Logs</div>
            <pre>
[00:00:00] Ready. Waiting for configuration...
[00:00:02] Portable tools detected in .\tools
[00:00:03] Dry run enabled: no conversion will occur.
            </pre>
          </div>
        </div>
      </section>

      <section className="panel results">
        <h2>Results</h2>
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
            <tr>
              <td>camera_A_001.mov</td>
              <td>camera_A_001.wav</td>
              <td>01:00:00:00</td>
              <td>A001</td>
              <td className="status ok">Ready</td>
            </tr>
            <tr>
              <td>mixdown_final.mp4</td>
              <td>mixdown_final.wav</td>
              <td>00:59:58:12</td>
              <td>MXD1</td>
              <td className="status warn">Missing metadata</td>
            </tr>
          </tbody>
        </table>
      </section>
    </div>
  );
}
