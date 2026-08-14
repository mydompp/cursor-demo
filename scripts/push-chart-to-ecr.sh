#!/usr/bin/env bash
# Pull a community Helm chart at the pinned version and push it to private ECR as OCI.
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

AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:?AWS_ACCOUNT_ID is required}"
AWS_REGION="${AWS_REGION:?AWS_REGION is required}"
REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

eval "$(
  python3 - "${CHART_KEY}" "${VERSION}" <<'PY'
import sys
from chart_catalog import chart_spec, current_pin_version

chart_key = sys.argv[1]
version = sys.argv[2] or current_pin_version(chart_key)
spec = chart_spec(chart_key)
print(f"HELM_REPO_NAME={spec['helm_repo_name']}")
print(f"HELM_REPO_URL={spec['helm_repo_url']}")
print(f"HELM_CHART_NAME={spec['helm_chart_name']}")
print(f"CHART_VERSION={version}")
PY
)"

echo "Publishing ${HELM_CHART_NAME} ${CHART_VERSION} to oci://${REGISTRY}"

if ! aws ecr describe-repositories --repository-names "${HELM_CHART_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "Creating ECR repository ${HELM_CHART_NAME}"
  aws ecr create-repository \
    --repository-name "${HELM_CHART_NAME}" \
    --region "${AWS_REGION}" \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256 >/dev/null
fi

helm repo add "${HELM_REPO_NAME}" "${HELM_REPO_URL}" >/dev/null
helm repo update "${HELM_REPO_NAME}" >/dev/null

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

helm pull "${HELM_REPO_NAME}/${HELM_CHART_NAME}" \
  --version "${CHART_VERSION}" \
  --destination "${WORKDIR}"

PACKAGE="$(find "${WORKDIR}" -maxdepth 1 -name "${HELM_CHART_NAME}-*.tgz" | head -n 1)"
if [[ -z "${PACKAGE}" ]]; then
  echo "helm pull did not produce ${HELM_CHART_NAME}-*.tgz" >&2
  exit 1
fi

aws ecr get-login-password --region "${AWS_REGION}" \
  | helm registry login --username AWS --password-stdin "${REGISTRY}"

helm push "${PACKAGE}" "oci://${REGISTRY}"
echo "Pushed ${HELM_CHART_NAME}:${CHART_VERSION} to oci://${REGISTRY}/${HELM_CHART_NAME}"
