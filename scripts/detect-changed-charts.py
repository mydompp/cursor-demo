#!/usr/bin/env python3
"""Emit the catalog chart keys that changed on a PR (JSON array)."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from chart_catalog import REPO_ROOT, load_catalog


GLOBAL_PREFIXES = (
    "scripts/",
    ".github/workflows/",
    "helm-pins/catalog.yaml",
)


def git_changed_files(base_sha: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", f"{base_sha}...HEAD"],
        cwd=REPO_ROOT,
        check=True,
        text=True,
        capture_output=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def matching_charts(changed: list[str]) -> list[str]:
    catalog = load_catalog()
    selected: set[str] = set()

    if any(
        path.startswith(prefix) or path == prefix.rstrip("/")
        for path in changed
        for prefix in GLOBAL_PREFIXES
    ):
        return sorted(catalog)

    for chart_key, spec in catalog.items():
        pin_prefix = spec["pin_dir"].rstrip("/") + "/"
        tf_file = spec["terraform_file"]
        for path in changed:
            if path.startswith(pin_prefix) or path == spec["pin_dir"] or path == tf_file:
                selected.add(chart_key)
    return sorted(selected)


def write_output(charts: list[str]) -> None:
    encoded = json.dumps(charts)
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with Path(github_output).open("a", encoding="utf-8") as handle:
            handle.write(f"charts={encoded}\n")
    print(encoded)


def main() -> int:
    base_sha = os.environ.get("BASE_SHA", "").strip()
    catalog_keys = sorted(load_catalog())
    if not base_sha:
        write_output(catalog_keys)
        return 0
    try:
        changed = git_changed_files(base_sha)
    except subprocess.CalledProcessError as exc:
        print(exc.stderr or exc.stdout or str(exc), file=sys.stderr)
        write_output(catalog_keys)
        return 0
    charts = matching_charts(changed) or catalog_keys
    write_output(charts)
    return 0


if __name__ == "__main__":
    sys.exit(main())
