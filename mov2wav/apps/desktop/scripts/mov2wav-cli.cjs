const { execFileSync } = require("child_process");
const path = require("path");

function resolveRepoRoot() {
  try {
    const output = execFileSync("git", ["-C", __dirname, "rev-parse", "--show-toplevel"], {
      encoding: "utf8"
    });
    return output.trim();
  } catch {
    return path.resolve(__dirname, "../../../../");
  }
}

const args = process.argv.slice(2);
const command = args.length > 0 ? args[0] : "convert";
const forwardArgs = command === "convert" ? args : args.slice(1);

const repoRoot = resolveRepoRoot();
const ps1 = path.join(repoRoot, "tools", "mov2wav.ps1");

const psArgs = [
  "-NoProfile",
  "-ExecutionPolicy",
  "Bypass",
  "-File",
  ps1,
  command,
  ...forwardArgs
];

try {
  execFileSync("powershell", psArgs, { stdio: "inherit" });
} catch (error) {
  process.exit(error.status ?? 1);
}
