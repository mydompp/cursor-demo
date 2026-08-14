#!/usr/bin/env python3
"""Diff default values.yaml between the base and head pin versions of a chart."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from chart_catalog import (
    REPO_ROOT,
    chart_spec,
    current_pin_version,
    dependency_version,
    pin_chart_yaml,
    show_values,
)

COMMENT_MARKER_PREFIX = "<!-- helm-values-diff:"
MAX_COMMENT_CHARS = 60000


def git_show(sha: str, path: Path) -> str | None:
    rel = path.relative_to(REPO_ROOT).as_posix()
    result = subprocess.run(
        ["git", "show", f"{sha}:{rel}"],
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        return None
    return result.stdout


def unified_diff(old_label: str, old_text: str, new_label: str, new_text: str) -> str:
    with tempfile.TemporaryDirectory() as tmp:
        old_path = Path(tmp) / "old-values.yaml"
        new_path = Path(tmp) / "new-values.yaml"
        old_path.write_text(old_text, encoding="utf-8")
        new_path.write_text(new_text, encoding="utf-8")
        result = subprocess.run(
            ["diff", "-u", "--label", old_label, "--label", new_label, str(old_path), str(new_path)],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode not in (0, 1):
            raise SystemExit(result.stderr or f"diff failed with code {result.returncode}")
        return result.stdout


def post_pr_comment(chart_key: str, body: str) -> None:
    token = os.environ.get("GITHUB_TOKEN")
    repo = os.environ.get("GITHUB_REPOSITORY")
    pr_number = os.environ.get("PR_NUMBER")
    if not token or not repo or not pr_number:
        print("Skipping PR comment (GITHUB_TOKEN, GITHUB_REPOSITORY, or PR_NUMBER not set)")
        return

    marker = f"{COMMENT_MARKER_PREFIX}{chart_key} -->"
    env = os.environ.copy()
    env["GH_TOKEN"] = token
    payload_body = f"{marker}\n{body}"

    find = subprocess.run(
        [
            "gh",
            "api",
            f"repos/{repo}/issues/{pr_number}/comments",
            "--jq",
            f'.[] | select(.body | contains("{marker}")) | .id',
        ],
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )
    comment_id = find.stdout.strip().splitlines()[0] if find.returncode == 0 and find.stdout.strip() else None
    payload = json.dumps({"body": payload_body})

    if comment_id:
        subprocess.run(
            ["gh", "api", "-X", "PATCH", f"repos/{repo}/issues/comments/{comment_id}", "--input", "-"],
            env=env,
            input=payload,
            text=True,
            check=True,
        )
        print(f"Updated PR comment {comment_id} for {chart_key}")
        return

    subprocess.run(
        ["gh", "api", f"repos/{repo}/issues/{pr_number}/comments", "--input", "-"],
        env=env,
        input=payload,
        text=True,
        check=True,
    )
    print(f"Posted PR comment for {chart_key}")


def render_comment(chart_key: str, old_version: str | None, new_version: str, diff_text: str) -> str:
    title = f"### values.yaml diff: `{chart_key}`"
    versions = (
        f"Comparing **{old_version}** (base) → **{new_version}** (head)."
        if old_version
        else f"No previous pin on the base branch. Showing default values for **{new_version}**."
    )
    if old_version == new_version:
        versions = f"Pin version is unchanged (**{new_version}**). Diff is empty unless the upstream chart mutated in place."
    if not diff_text.strip():
        body = f"{title}\n\n{versions}\n\nNo differences in default `values.yaml`."
    else:
        clipped = diff_text
        truncated = ""
        if len(diff_text) > MAX_COMMENT_CHARS:
            clipped = diff_text[:MAX_COMMENT_CHARS]
            truncated = "\n\n_Diff truncated for GitHub comment size; see the workflow artifact._"
        body = (
            f"{title}\n\n{versions}\n\n"
            f"<details>\n<summary>Unified diff</summary>\n\n```diff\n{clipped}\n```\n</details>"
            f"{truncated}"
        )
    return body


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("chart", help="Catalog chart key")
    parser.add_argument("--old-version", help="Override base pin version")
    parser.add_argument("--new-version", help="Override head pin version")
    parser.add_argument("--output-dir", type=Path, default=Path("values-diff"))
    parser.add_argument("--skip-comment", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    spec = chart_spec(args.chart)
    new_version = args.new_version or current_pin_version(args.chart)
    old_version = args.old_version
    base_sha = os.environ.get("BASE_SHA", "").strip()
    if old_version is None and base_sha:
        old_yaml = git_show(base_sha, pin_chart_yaml(args.chart))
        if old_yaml:
            with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False, encoding="utf-8") as tmp:
                tmp.write(old_yaml)
                tmp_path = Path(tmp.name)
            try:
                old_version = dependency_version(tmp_path, spec["helm_chart_name"])
            finally:
                tmp_path.unlink(missing_ok=True)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    new_values = show_values(args.chart, new_version)
    new_file = args.output_dir / f"{args.chart}-{new_version}-values.yaml"
    new_file.write_text(new_values, encoding="utf-8")

    if old_version:
        old_values = show_values(args.chart, old_version)
        old_file = args.output_dir / f"{args.chart}-{old_version}-values.yaml"
        old_file.write_text(old_values, encoding="utf-8")
        diff_text = unified_diff(
            f"{args.chart}-{old_version}/values.yaml",
            old_values,
            f"{args.chart}-{new_version}/values.yaml",
            new_values,
        )
    else:
        diff_text = unified_diff(
            "/dev/null",
            "",
            f"{args.chart}-{new_version}/values.yaml",
            new_values,
        )

    diff_file = args.output_dir / f"{args.chart}.diff"
    diff_file.write_text(diff_text, encoding="utf-8")
    print(diff_text or f"No values.yaml differences for {args.chart}")

    if not args.skip_comment:
        post_pr_comment(args.chart, render_comment(args.chart, old_version, new_version, diff_text))
    return 0


if __name__ == "__main__":
    sys.exit(main())
