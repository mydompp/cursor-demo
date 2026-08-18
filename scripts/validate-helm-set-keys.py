#!/usr/bin/env python3
"""Fail if Terraform helm_release set paths are missing from a chart values.yaml."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Iterable

import hcl2
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from chart_catalog import REPO_ROOT, chart_spec

SET_BLOCK_KEYS = ("set", "set_sensitive", "set_list")
LOCAL_REF_RE = re.compile(r"^\$\{\s*local\.([A-Za-z_][A-Za-z0-9_-]*)\s*\}$")


def split_helm_path(path: str) -> list[str | int]:
    """Split a Helm --set path into keys, honoring backslash-escaped dots and [index]."""
    tokens: list[str | int] = []
    current: list[str] = []
    i = 0
    while i < len(path):
        char = path[i]
        if char == "\\" and i + 1 < len(path):
            current.append(path[i + 1])
            i += 2
            continue
        if char == ".":
            if current:
                tokens.append("".join(current))
                current = []
            i += 1
            continue
        if char == "[":
            if current:
                tokens.append("".join(current))
                current = []
            end = path.find("]", i)
            if end == -1:
                raise ValueError(f"Unclosed [ in Helm set path: {path}")
            raw_index = path[i + 1 : end]
            tokens.append(int(raw_index) if raw_index.isdigit() else raw_index)
            i = end + 1
            if i < len(path) and path[i] == ".":
                i += 1
            continue
        current.append(char)
        i += 1
    if current:
        tokens.append("".join(current))
    return tokens


def format_tokens(tokens: Iterable[str | int]) -> str:
    parts: list[str] = []
    for token in tokens:
        if isinstance(token, int):
            if not parts:
                parts.append(f"[{token}]")
            else:
                parts[-1] = f"{parts[-1]}[{token}]"
        else:
            parts.append(str(token))
    return ".".join(parts)


def resolve_path(values: Any, tokens: list[str | int]) -> tuple[bool, str]:
    current = values
    walked: list[str | int] = []
    for index, token in enumerate(tokens):
        walked.append(token)
        is_last = index == len(tokens) - 1
        if isinstance(token, int):
            if not isinstance(current, list):
                return False, (
                    f"{format_tokens(walked)} is not a list in values.yaml "
                    f"(found {type(current).__name__})"
                )
            if token >= len(current) or token < 0:
                return False, f"{format_tokens(walked)} index is out of range in values.yaml"
            current = current[token]
            continue

        if not isinstance(current, dict):
            return False, (
                f"{format_tokens(walked[:-1]) or '<root>'} is not a map; "
                f"cannot apply {format_tokens(walked)}"
            )
        if token not in current:
            parent = format_tokens(walked[:-1]) or "<root>"
            return False, f"key '{token}' is missing under {parent} in the new chart values.yaml"
        current = current[token]
        if current is None and not is_last:
            return False, (
                f"{format_tokens(walked)} is null in values.yaml; nested override "
                f"{format_tokens(tokens)} is not valid"
            )
    return True, ""


def _as_list(node: Any) -> list[Any]:
    if node is None:
        return []
    if isinstance(node, list):
        return node
    return [node]


def _unquote(value: Any) -> Any:
    if isinstance(value, str) and len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        return value[1:-1]
    return value


def _lookup(mapping: dict[str, Any], key: str) -> Any:
    if key in mapping:
        return mapping[key]
    quoted = f'"{key}"'
    if quoted in mapping:
        return mapping[quoted]
    return None


def iter_helm_releases(hcl_data: Any) -> Iterable[tuple[str, dict[str, Any]]]:
    root = _lookup(hcl_data, "resource") if isinstance(hcl_data, dict) else None
    for resource_block in _as_list(root):
        if not isinstance(resource_block, dict):
            continue
        for release_block in _as_list(_lookup(resource_block, "helm_release")):
            if not isinstance(release_block, dict):
                continue
            for name, body in release_block.items():
                for item in _as_list(body):
                    if isinstance(item, dict):
                        yield str(_unquote(name)), item


def _collect_locals(hcl_data: Any) -> dict[str, Any]:
    """Merge every top-level `locals {}` block in a parsed .tf file into one map."""
    merged: dict[str, Any] = {}
    for block in _as_list(_lookup(hcl_data, "locals") if isinstance(hcl_data, dict) else None):
        if not isinstance(block, dict):
            continue
        for key, value in block.items():
            merged[str(_unquote(key))] = value
    return merged


def _iter_set_items(
    body: dict[str, Any], locals_map: dict[str, Any]
) -> Iterable[tuple[str, dict[str, Any]]]:
    """Yield (set_block_kind, item_dict) for both static set blocks and dynamic ones
    whose for_each references a local list of `{ name, value }` objects."""
    for key in SET_BLOCK_KEYS:
        for item in _as_list(_lookup(body, key)):
            if isinstance(item, dict):
                yield key, item

    for dyn_block in _as_list(_lookup(body, "dynamic")):
        if not isinstance(dyn_block, dict):
            continue
        for raw_kind, dyn_body in dyn_block.items():
            kind = str(_unquote(raw_kind))
            if kind not in SET_BLOCK_KEYS:
                continue
            for dyn_item in _as_list(dyn_body):
                if not isinstance(dyn_item, dict):
                    continue
                for_each = _lookup(dyn_item, "for_each")
                if not isinstance(for_each, str):
                    continue
                match = LOCAL_REF_RE.match(for_each.strip())
                if not match:
                    continue
                target = locals_map.get(match.group(1))
                for local_item in _as_list(target):
                    if isinstance(local_item, dict):
                        yield kind, local_item


def extract_set_names(tf_path: Path) -> list[str]:
    with tf_path.open(encoding="utf-8") as handle:
        parsed = hcl2.load(handle)
    locals_map = _collect_locals(parsed)
    names: list[str] = []
    for _release, body in iter_helm_releases(parsed):
        for _kind, item in _iter_set_items(body, locals_map):
            raw_name = _lookup(item, "name")
            if raw_name:
                names.append(str(_unquote(raw_name)))
    return names


def validate_set_keys(tf_path: Path, values: Any) -> list[str]:
    errors: list[str] = []
    names = extract_set_names(tf_path)
    if not names:
        errors.append(f"No set/set_list/set_sensitive names found in {tf_path}")
        return errors
    for name in names:
        try:
            tokens = split_helm_path(name)
        except ValueError as exc:
            errors.append(str(exc))
            continue
        ok, message = resolve_path(values, tokens)
        if not ok:
            errors.append(f"set name '{name}': {message}")
    return errors


def load_values(path: Path) -> Any:
    with path.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chart", help="Catalog chart key (loads terraform_file from catalog)")
    parser.add_argument("--terraform", type=Path, help="helm_release .tf file to parse")
    parser.add_argument("--values", type=Path, required=True, help="Chart values.yaml to validate against")
    parser.add_argument("--json", action="store_true", help="Print machine-readable result")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.chart:
        spec = chart_spec(args.chart)
        tf_path = REPO_ROOT / spec["terraform_file"]
    elif args.terraform:
        tf_path = args.terraform
    else:
        print("error: provide --chart or --terraform", file=sys.stderr)
        return 2

    if not tf_path.is_file():
        print(f"error: terraform file not found: {tf_path}", file=sys.stderr)
        return 2
    if not args.values.is_file():
        print(f"error: values file not found: {args.values}", file=sys.stderr)
        return 2

    values = load_values(args.values)
    errors = validate_set_keys(tf_path, values)
    result = {
        "terraform": str(tf_path),
        "values": str(args.values),
        "set_names": extract_set_names(tf_path),
        "ok": not errors,
        "errors": errors,
    }
    if args.json:
        print(json.dumps(result, indent=2))
    elif errors:
        print(f"Invalid helm_release set keys in {tf_path}:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
    else:
        print(f"All {len(result['set_names'])} set keys in {tf_path} exist in the new chart values.yaml")

    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
