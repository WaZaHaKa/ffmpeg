param(
  [switch]$DryRun,
  [switch]$AllowDirty,
  [switch]$ApplyHistoryRewrite
)

$ErrorActionPreference = 'Stop'

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
  Write-Host "[ERR] Not inside a git repository." -ForegroundColor Red
  exit 1
}

$scriptPath = Join-Path $repoRoot 'scripts/purge_build_repo.py'
if (-not (Test-Path -LiteralPath $scriptPath)) {
  Write-Host "[ERR] Missing $scriptPath" -ForegroundColor Red
  exit 1
}

$argsList = @()
if ($DryRun) { $argsList += '--dry-run' }
if ($AllowDirty) { $argsList += '--allow-dirty' }
if ($ApplyHistoryRewrite) { $argsList += '--apply-history-rewrite' }

Write-Host "Running purge_build_repo.py from $repoRoot" -ForegroundColor Cyan
python $scriptPath @argsList

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  - Review git status" -ForegroundColor Cyan
Write-Host "  - Commit updated .gitignore and removals" -ForegroundColor Cyan
if ($ApplyHistoryRewrite) {
  Write-Host "  - Force push (git push --force-with-lease --all && git push --force-with-lease --tags)" -ForegroundColor Yellow
}
