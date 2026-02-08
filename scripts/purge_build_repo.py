#!/usr/bin/env python3
"""Purge tracked build artifacts and update ignore rules.

Logging format is adapted from mov2wav/apps/desktop/mov2wav_pnp/scripts/step_ensure_tools.ps1
(timestamped lines) to keep consistency with existing tooling.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import fnmatch
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple

MANAGED_BLOCK_BEGIN = "### BEGIN: purge_build_repo.py managed ###"
MANAGED_BLOCK_END = "### END: purge_build_repo.py managed ###"

STANDARD_IGNORE_RULES = [
    "**/node_modules/",
    "**/.pnp.*",
    "**/.yarn/*",
    "**/.pnpm-store/",
    "**/dist/",
    "**/build/",
    "**/out/",
    "**/release/",
    "**/coverage/",
    "**/.cache/",
    "**/.vite/",
    "**/.turbo/",
    "**/.parcel-cache/",
    "**/.next/",
    "**/.nuxt/",
    "**/.svelte-kit/",
    "**/app/dist/",
    "**/app/build/",
    "**/electron/dist/",
    "**/electron/out/",
    "*.log",
    "Thumbs.db",
    ".DS_Store",
    "__pycache__/",
    "*.pyc",
    ".venv/",
    "venv/",
    ".vscode/",
    ".idea/",
]

STANDARD_REMOVE_PATTERNS = [
    "**/node_modules/**",
    "**/dist/**",
    "**/build/**",
    "**/out/**",
    "**/release/**",
    "**/.vite/**",
    "**/.next/**",
    "**/.cache/**",
    "**/.turbo/**",
    "**/.parcel-cache/**",
    "**/.nuxt/**",
    "**/.svelte-kit/**",
]


class CommandError(RuntimeError):
    pass


def log_line(message: str) -> None:
    ts = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    print(f"[{ts}] {message}")


def run_cmd(cmd: Sequence[str], cwd: Path | None = None, check: bool = True) -> str:
    try:
        result = subprocess.run(
            cmd,
            cwd=str(cwd) if cwd else None,
            check=check,
            text=True,
            capture_output=True,
        )
    except subprocess.CalledProcessError as exc:
        raise CommandError(exc.stderr.strip() or str(exc)) from exc
    return result.stdout


def repo_root() -> Path:
    output = run_cmd(["git", "rev-parse", "--show-toplevel"]).strip()
    if not output:
        raise CommandError("Unable to detect repo root via git rev-parse.")
    return Path(output)


def read_optional_text(path: Path) -> str | None:
    if path.exists():
        return path.read_text(encoding="utf-8", errors="ignore")
    return None


def parse_rm_txt(contents: str) -> List[str]:
    patterns: List[str] = []
    for raw in contents.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith(";"):
            continue
        line = re.sub(r"^[*-]\s+", "", line).strip()
        if line:
            patterns.append(line)
    return patterns


def normalize_tree_line(line: str) -> str | None:
    stripped = line.strip()
    if not stripped:
        return None
    stripped = re.sub(r"^[├└│\s\\+\-]+", "", stripped)
    stripped = stripped.strip("/")
    if not stripped or stripped in {".", ".."}:
        return None
    return stripped


def parse_tree_txt(contents: str) -> List[str]:
    paths: List[str] = []
    for raw in contents.splitlines():
        normalized = normalize_tree_line(raw)
        if normalized:
            paths.append(normalized)
    return paths


def is_dirty(repo: Path) -> bool:
    output = run_cmd(["git", "status", "--porcelain"], cwd=repo, check=True)
    return bool(output.strip())


def update_gitignore(repo: Path, rules: Sequence[str]) -> Tuple[bool, List[str]]:
    gitignore = repo / ".gitignore"
    existing = gitignore.read_text(encoding="utf-8", errors="ignore") if gitignore.exists() else ""
    managed_block = "\n".join([MANAGED_BLOCK_BEGIN, *rules, MANAGED_BLOCK_END])

    if MANAGED_BLOCK_BEGIN in existing and MANAGED_BLOCK_END in existing:
        pattern = re.compile(
            rf"{re.escape(MANAGED_BLOCK_BEGIN)}.*?{re.escape(MANAGED_BLOCK_END)}",
            re.DOTALL,
        )
        updated = pattern.sub(managed_block, existing)
    else:
        separator = "" if existing.endswith("\n") or not existing else "\n"
        updated = f"{existing}{separator}{managed_block}\n"

    changed = updated != existing
    if changed:
        gitignore.write_text(updated, encoding="utf-8")
    return changed, list(rules)


def load_tracked_files(repo: Path) -> List[str]:
    output = run_cmd(["git", "ls-files", "-z"], cwd=repo)
    files = [p for p in output.split("\x00") if p]
    return files


def match_any(path: str, patterns: Iterable[str]) -> bool:
    for pattern in patterns:
        if fnmatch.fnmatchcase(path, pattern):
            return True
        if fnmatch.fnmatchcase(f"{path}/", pattern):
            return True
    return False


def derive_removals(
    tracked_files: Sequence[str],
    rm_patterns: Sequence[str],
    tree_paths: Sequence[str],
) -> List[str]:
    patterns = list(STANDARD_REMOVE_PATTERNS)
    patterns.extend(rm_patterns)

    derived_paths: List[str] = []
    for tree_path in tree_paths:
        if match_any(tree_path, patterns):
            derived_paths.append(tree_path)

    candidates = set()
    for path in tracked_files:
        if match_any(path, patterns):
            candidates.add(path)
    for path in derived_paths:
        if path in tracked_files:
            candidates.add(path)
        else:
            for tracked in tracked_files:
                if tracked.startswith(path.rstrip("/") + "/"):
                    candidates.add(tracked)
    return sorted(candidates)


def git_rm_cached(repo: Path, paths: Sequence[str], dry_run: bool) -> None:
    if not paths:
        log_line("No tracked build artifacts detected for removal.")
        return

    log_line(f"Tracked artifacts to untrack: {len(paths)}")
    for path in paths:
        log_line(f"  - {path}")

    if dry_run:
        log_line("Dry-run enabled; not running git rm --cached.")
        return

    chunk: List[str] = []
    max_chunk = 200
    for path in paths:
        chunk.append(path)
        if len(chunk) >= max_chunk:
            run_cmd(["git", "rm", "-r", "--cached", "--", *chunk], cwd=repo)
            chunk = []
    if chunk:
        run_cmd(["git", "rm", "-r", "--cached", "--", *chunk], cwd=repo)


def detect_filter_repo() -> bool:
    try:
        run_cmd([sys.executable, "-m", "pip", "show", "git-filter-repo"], check=True)
        return True
    except CommandError:
        pass
    try:
        run_cmd(["git", "filter-repo", "--version"], check=True)
        return True
    except CommandError:
        return False


def apply_history_rewrite(repo: Path, patterns: Sequence[str], dry_run: bool) -> None:
    if not detect_filter_repo():
        log_line("git-filter-repo not found.")
        log_line("Install with: python -m pip install git-filter-repo")
        raise SystemExit(2)

    if dry_run:
        log_line("Dry-run enabled; skipping history rewrite.")
        return

    cmd = ["git", "filter-repo"]
    for pattern in patterns:
        cmd.extend(["--path-glob", pattern])
    cmd.append("--invert-paths")

    log_line("Running git filter-repo to purge historical artifacts...")
    run_cmd(cmd, cwd=repo)

    log_line("History rewrite complete.")
    log_line("Next steps:")
    log_line("  git push --force-with-lease --all")
    log_line("  git push --force-with-lease --tags")
    log_line("Warn collaborators to re-clone or hard reset.")


def confirm_or_exit(action: str) -> None:
    if os.environ.get("PURGE_BUILD_REPO_ASSUME_YES") == "1":
        log_line("PURGE_BUILD_REPO_ASSUME_YES=1 set; skipping confirmation.")
        return
    response = input(f"Type APPLY to proceed with {action}: ").strip()
    if response != "APPLY":
        raise SystemExit("Confirmation not received. Aborting.")


def report_large_blobs(repo: Path, threshold_bytes: int = 50 * 1024 * 1024) -> List[Tuple[str, int, str]]:
    try:
        rev_list = run_cmd(["git", "rev-list", "--objects", "--all"], cwd=repo)
    except CommandError as exc:
        log_line(f"[WARN] Unable to list objects: {exc}")
        return []

    objects = [line.split() for line in rev_list.splitlines() if line.strip()]
    if not objects:
        return []

    blob_info: List[Tuple[str, int, str]] = []
    batch_input = "\n".join(obj[0] for obj in objects) + "\n"
    try:
        batch = subprocess.run(
            ["git", "cat-file", "--batch-check=%(objectname) %(objecttype) %(objectsize)"],
            cwd=str(repo),
            input=batch_input,
            text=True,
            capture_output=True,
            check=True,
        )
    except subprocess.CalledProcessError as exc:
        log_line(f"[WARN] Unable to inspect objects: {exc.stderr.strip()}")
        return []

    size_map = {}
    for line in batch.stdout.splitlines():
        parts = line.split()
        if len(parts) != 3:
            continue
        obj_name, obj_type, obj_size = parts
        if obj_type != "blob":
            continue
        size_map[obj_name] = int(obj_size)

    for obj_hash, *rest in objects:
        size = size_map.get(obj_hash)
        if size is None or size < threshold_bytes:
            continue
        path = rest[0] if rest else "(unknown)"
        blob_info.append((obj_hash, size, path))

    return blob_info


def verification_checks(repo: Path) -> bool:
    tracked = run_cmd(["git", "ls-files"], cwd=repo)
    checks = {
        "node_modules": re.compile(r"node_modules", re.IGNORECASE),
        "dist/build/out/release": re.compile(r"(dist|build|out|release)", re.IGNORECASE),
        ".vite/.next/.cache": re.compile(r"\.(vite|next|cache)", re.IGNORECASE),
    }
    all_passed = True
    for label, pattern in checks.items():
        if pattern.search(tracked):
            log_line(f"[FAIL] Tracked files still include {label}.")
            all_passed = False
        else:
            log_line(f"[PASS] No tracked files include {label}.")
    if all_passed:
        log_line("PASS: Verification checks completed.")
    else:
        log_line("FAIL: Verification checks reported issues.")
    return all_passed


def main() -> int:
    parser = argparse.ArgumentParser(description="Purge tracked build outputs and update .gitignore.")
    parser.add_argument("--dry-run", action="store_true", help="Report actions without changes.")
    parser.add_argument("--allow-dirty", action="store_true", help="Allow a dirty working tree.")
    parser.add_argument(
        "--apply-history-rewrite",
        action="store_true",
        help="Rewrite history using git-filter-repo.",
    )
    args = parser.parse_args()

    repo = repo_root()
    log_line(f"Repo root: {repo}")

    if is_dirty(repo) and not args.allow_dirty:
        log_line("Working tree is dirty.")
        log_line("Commit or stash changes, or re-run with --allow-dirty.")
        return 1
    if is_dirty(repo) and args.allow_dirty:
        log_line("[WARN] Working tree is dirty; proceeding due to --allow-dirty.")

    rm_txt = read_optional_text(repo / "rm.txt")
    tree_txt = read_optional_text(repo / "tree.txt")
    diag_a = read_optional_text(repo / "current state of the repo.txt")
    diag_b = read_optional_text(repo / "new 2.txt")

    rm_patterns = parse_rm_txt(rm_txt) if rm_txt else []
    tree_paths = parse_tree_txt(tree_txt) if tree_txt else []

    if rm_txt is None:
        log_line("rm.txt not found; using standard remove patterns only.")
    if tree_txt is None:
        log_line("tree.txt not found; using tracked file scan only.")
    if diag_a or diag_b:
        log_line("Optional diagnostic logs detected (current state of the repo.txt / new 2.txt).")

    changed, rules_added = update_gitignore(repo, STANDARD_IGNORE_RULES)
    if changed:
        log_line(".gitignore updated with managed block.")
    else:
        log_line(".gitignore managed block already up to date.")

    tracked_files = load_tracked_files(repo)
    to_untrack = derive_removals(tracked_files, rm_patterns, tree_paths)

    if not args.dry_run:
        confirm_or_exit("removing tracked build artifacts")

    git_rm_cached(repo, to_untrack, args.dry_run)

    large_blobs = report_large_blobs(repo)
    if large_blobs:
        log_line("Large blobs detected (history rewrite may be needed):")
        for obj_hash, size, path in large_blobs:
            log_line(f"  - {path} ({size} bytes, {obj_hash})")
    else:
        log_line("No large blobs detected above threshold.")

    if args.apply_history_rewrite:
        confirm_or_exit("history rewrite")
        patterns = list(STANDARD_REMOVE_PATTERNS)
        patterns.extend(rm_patterns)
        apply_history_rewrite(repo, patterns, args.dry_run)

    verification_checks(repo)
    log_line("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
