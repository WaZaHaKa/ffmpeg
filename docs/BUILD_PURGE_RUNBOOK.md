# Build Purge Runbook

## Why this exists
Build outputs, dependency caches, and OS/editor artifacts should never be tracked in git history. This runbook explains how to use the repository purge automation to remove tracked build artifacts, update `.gitignore`, and optionally rewrite history when large binaries have already been committed.

## How to run
### Dry-run (recommended first)
```powershell
python scripts/purge_build_repo.py --dry-run
```

### Apply (no history rewrite)
```powershell
python scripts/purge_build_repo.py
```

### Apply with history rewrite
```powershell
python scripts/purge_build_repo.py --apply-history-rewrite
```

## What it changes
- Injects/updates a managed block in `.gitignore` to ignore build artifacts, node_modules, caches, and OS/editor junk.
- Untracks any already-tracked build artifacts using `git rm -r --cached`.
- Optionally rewrites history using `git filter-repo` to remove historical artifacts.

## How to verify
- Check git status:
  ```powershell
  git status -sb
  ```
- Ensure no tracked build outputs remain:
  ```powershell
  git ls-files | findstr /i node_modules
  git ls-files | findstr /i "dist build out release"
  git ls-files | findstr /i ".vite .next .cache"
  ```
- Inspect history size if needed:
  ```powershell
  git rev-list --objects --all | Select-String -Pattern "node_modules|dist|build|out|release"
  ```

## Safety notes about history rewrite
- `git filter-repo` rewrites commit history. Anyone with existing clones must re-clone or hard reset.
- After a rewrite, use:
  ```powershell
  git push --force-with-lease --all
  git push --force-with-lease --tags
  ```

## If you already pushed binaries
1. Coordinate with collaborators to pause work.
2. Run the history rewrite:
   ```powershell
   python scripts/purge_build_repo.py --apply-history-rewrite
   ```
3. Force-push rewritten history:
   ```powershell
   git push --force-with-lease --all
   git push --force-with-lease --tags
   ```
4. Ask collaborators to re-clone or run:
   ```powershell
   git fetch --all
   git reset --hard origin/<branch>
   ```

## Troubleshooting
### pathspec did not match any files
This means the path you tried to remove is not currently tracked. Re-run the script in dry-run mode and confirm the paths to remove.

### git filter-repo not found / not on PATH
Install it with:
```powershell
python -m pip install git-filter-repo
```

### dirty working tree
Commit or stash changes before running, or re-run with `--allow-dirty` if you are aware of the risk.

### forced push consequences
Force pushes overwrite remote history. Coordinate with collaborators and ensure no one is pushing during the rewrite.
