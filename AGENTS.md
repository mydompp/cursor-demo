# AGENTS.md

## Cursor Cloud specific instructions

This repo is a Helm chart update automation project. There is no long-running
application/server to start; the "products" are CLI/CI checks plus Terraform
configs. The update script installs the Python deps; Helm and Terraform CLIs are
also required and are documented below.

### Services / checks and how to run them

- **Python unit tests** (`scripts/`): `python3 scripts/test_validate_helm_set_keys.py`.
  Depends on `python-hcl2` and `PyYAML` (see `scripts/requirements.txt`).
- **Set-key validator** (`scripts/validate-chart-set-keys.sh <chart-key>`):
  fetches the pinned chart's upstream `values.yaml` via Helm and checks that every
  Terraform `helm_release` `set { name = ... }` path still exists. Requires the
  `helm` CLI and network egress to public Helm repos.
- **values.yaml diff** (`scripts/diff-chart-values.sh <chart-key> --skip-comment --output-dir <dir>`):
  renders the diff between pinned versions. Use `--skip-comment` locally so it does
  not try to post a GitHub PR comment. Requires `helm`.
- **Terraform** (`terraform/ecr`, `terraform/helm`): validate with
  `terraform init -backend=false && terraform validate`. `terraform/helm/locals.tf`
  reads pinned versions straight from `helm-pins/<chart>/Chart.yaml` via `yamldecode`;
  you can inspect them without AWS creds using `terraform console` with dummy
  `-var` values (e.g. `echo 'local.chart_versions' | terraform console -var 'aws_account_id=123456789012' -var 'aws_region=us-east-1' -var 'cluster_name=demo' -var 'cluster_endpoint=https://example' -var 'cluster_ca_certificate='`).
  A real `terraform plan`/`apply` needs AWS credentials and a live EKS cluster.

Valid chart keys are defined in `helm-pins/catalog.yaml`:
`aws-load-balancer-controller`, `secrets-store-csi-driver`, `cluster-autoscaler`.

### Required CLIs not covered by the update script

- **Helm 3** and **Terraform** must be on `PATH`. Installing to `/usr/local/bin`
  needs `sudo`. Helm: `curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash`.
  Terraform: download the `linux_amd64` zip from releases.hashicorp.com and move the
  binary into `/usr/local/bin`.
- **AWS CLI** is only needed for `scripts/push-chart-to-ecr.sh` (publishing to ECR)
  and for real `terraform apply`; it is not required for tests, validation, or diffs.

### Gotchas

- `scripts/requirements.txt` installs into the system Python; use
  `pip install --break-system-packages -r scripts/requirements.txt` on this VM
  (PEP 668 externally-managed environment).
- The `secrets-store-csi-driver` entry in `helm-pins/catalog.yaml` points at
  `https://kubernetes-sigs.github.io/secrets-store-csi-driver`, which currently
  returns HTTP 404 from upstream (the index now lives under `.../secrets-store-csi-driver/charts`).
  This makes `validate-chart-set-keys.sh secrets-store-csi-driver` and its
  `diff-chart-values.sh` fail with a repo-not-reachable error. This is an upstream
  data issue in the repo config, not a local setup/egress problem — the other two
  charts and the correct `/charts/` URL resolve fine.
- `git` is required by `scripts/detect-changed-charts.py` and `diff-chart-values.py`
  (they call `git diff`/`git show` against `BASE_SHA`); with no `BASE_SHA` the detect
  script returns all catalog charts.
