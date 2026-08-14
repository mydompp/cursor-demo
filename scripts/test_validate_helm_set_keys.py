#!/usr/bin/env python3
"""Unit tests for Helm set-path parsing and values.yaml lookups."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

_SPEC = importlib.util.spec_from_file_location(
    "validate_helm_set_keys_mod",
    Path(__file__).resolve().parent / "validate-helm-set-keys.py",
)
_MOD = importlib.util.module_from_spec(_SPEC)
assert _SPEC.loader is not None
_SPEC.loader.exec_module(_MOD)
split_helm_path = _MOD.split_helm_path
resolve_path = _MOD.resolve_path
extract_set_names = _MOD.extract_set_names
validate_set_keys = _MOD.validate_set_keys


class SplitHelmPathTests(unittest.TestCase):
    def test_dotted_path(self) -> None:
        self.assertEqual(
            split_helm_path("rbac.serviceAccount.create"),
            ["rbac", "serviceAccount", "create"],
        )

    def test_escaped_dot(self) -> None:
        self.assertEqual(
            split_helm_path(r"serviceAccount.annotations.eks\.amazonaws\.com/role-arn"),
            ["serviceAccount", "annotations", "eks.amazonaws.com/role-arn"],
        )

    def test_list_index(self) -> None:
        self.assertEqual(split_helm_path("env[0].name"), ["env", 0, "name"])


class ResolvePathTests(unittest.TestCase):
    def setUp(self) -> None:
        self.values = {
            "clusterName": None,
            "serviceAccount": {"create": True, "name": None, "annotations": {}},
            "syncSecret": {"enabled": False},
            "autoDiscovery": {"clusterName": None},
        }

    def test_existing_null_leaf(self) -> None:
        ok, _ = resolve_path(self.values, ["clusterName"])
        self.assertTrue(ok)

    def test_nested_key(self) -> None:
        ok, _ = resolve_path(self.values, ["serviceAccount", "create"])
        self.assertTrue(ok)

    def test_missing_key(self) -> None:
        ok, message = resolve_path(self.values, ["missing"])
        self.assertFalse(ok)
        self.assertIn("missing", message)

    def test_renamed_parent(self) -> None:
        ok, _ = resolve_path(self.values, ["rbac", "serviceAccount", "create"])
        self.assertFalse(ok)


class ExtractSetNamesTests(unittest.TestCase):
    def test_parses_set_blocks(self) -> None:
        tf = """
resource "helm_release" "example" {
  name = "example"
  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
}
"""
        with tempfile.NamedTemporaryFile("w", suffix=".tf", delete=False) as handle:
            handle.write(tf)
            path = Path(handle.name)
        try:
            names = extract_set_names(path)
            self.assertEqual(names, ["clusterName", "serviceAccount.create"])
            errors = validate_set_keys(
                path,
                {"clusterName": None, "serviceAccount": {"create": True}},
            )
            self.assertEqual(errors, [])
            errors = validate_set_keys(path, {"clusterName": None})
            self.assertEqual(len(errors), 1)
        finally:
            path.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
