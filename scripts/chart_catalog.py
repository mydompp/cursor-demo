"""Shared helpers for Helm pin catalog, Chart.yaml versions, and Helm CLI."""

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Any

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
CATALOG_PATH = REPO_ROOT / "helm-pins" / "catalog.yaml"


def load_catalog() -> dict[str, dict[str, str]]:
    with CATALOG_PATH.open(encoding="utf-8") as handle:
        data = yaml.safe_load(handle)
    charts = data.get("charts") or {}
    if not charts:
        raise SystemExit(f"No charts defined in {CATALOG_PATH}")
    return charts


def chart_spec(chart_key: str) -> dict[str, str]:
    charts = load_catalog()
    if chart_key not in charts:
        known = ", ".join(sorted(charts))
        raise SystemExit(f"Unknown chart '{chart_key}'. Known: {known}")
    return charts[chart_key]


def pin_chart_yaml(chart_key: str, root: Path | None = None) -> Path:
    spec = chart_spec(chart_key)
    base = root if root is not None else REPO_ROOT
    return base / spec["pin_dir"] / "Chart.yaml"


def dependency_version(chart_yaml: Path, chart_name: str) -> str | None:
    if not chart_yaml.is_file():
        return None
    with chart_yaml.open(encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    for dep in data.get("dependencies") or []:
        if dep.get("name") == chart_name:
            version = dep.get("version")
            return str(version) if version is not None else None
    return None


def current_pin_version(chart_key: str, root: Path | None = None) -> str:
    spec = chart_spec(chart_key)
    version = dependency_version(pin_chart_yaml(chart_key, root), spec["helm_chart_name"])
    if not version:
        raise SystemExit(f"No dependency version for {chart_key} in Chart.yaml")
    return version


def helm(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    try:
        result = subprocess.run(
            ["helm", *args],
            check=False,
            text=True,
            capture_output=True,
        )
    except FileNotFoundError as exc:
        raise SystemExit("helm is not installed or not on PATH") from exc
    if check and result.returncode != 0:
        detail = (result.stderr or result.stdout or "").strip()
        raise SystemExit(f"helm {' '.join(args)} failed: {detail}")
    return result


def ensure_helm_repo(repo_name: str, repo_url: str) -> None:
    listed = helm("repo", "list", check=False)
    existing = listed.stdout if listed.returncode == 0 else ""
    if repo_name in {line.split()[0] for line in existing.splitlines()[1:] if line.split()}:
        helm("repo", "update", repo_name)
        return
    helm("repo", "add", repo_name, repo_url)
    helm("repo", "update", repo_name)


def show_values(chart_key: str, version: str) -> str:
    spec = chart_spec(chart_key)
    ensure_helm_repo(spec["helm_repo_name"], spec["helm_repo_url"])
    result = helm(
        "show",
        "values",
        f"{spec['helm_repo_name']}/{spec['helm_chart_name']}",
        "--version",
        version,
    )
    return result.stdout


def parse_yaml(text: str) -> Any:
    return yaml.safe_load(text) or {}
