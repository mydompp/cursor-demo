#!/usr/bin/env bash
# Fetch the target chart values.yaml and verify terraform helm_release set keys still exist.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PYTHONPATH="${ROOT}/scripts"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <chart-key> [version]" >&2
  exit 2
fi

CHART_KEY="$1"
VERSION="${2:-}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

if [[ -z "${VERSION}" ]]; then
  VERSION="$(python3 -c "from chart_catalog import current_pin_version; print(current_pin_version('${CHART_KEY}'))")"
fi

VALUES_FILE="${WORKDIR}/values.yaml"
python3 - "${CHART_KEY}" "${VERSION}" "${VALUES_FILE}" <<'PY'
import sys
from pathlib import Path
from chart_catalog import show_values

chart_key, version, dest = sys.argv[1], sys.argv[2], sys.argv[3]
Path(dest).write_text(show_values(chart_key, version), encoding="utf-8")
PY

exec python3 "${ROOT}/scripts/validate-helm-set-keys.py" --chart "${CHART_KEY}" --values "${VALUES_FILE}"
