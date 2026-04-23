#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_bootstrap_env
ensure_required_bootstrap_vars

ARTIFACT_DIR="${MSP_ACTIVE_ARTIFACT_DIR:-$(current_artifact_dir bootstrap)}"
export MSP_ACTIVE_ARTIFACT_DIR="${ARTIFACT_DIR}"

log "Bootstrapping hosted cluster flow..."

"${SCRIPT_DIR}/provision_cluster.sh"
"${SCRIPT_DIR}/export_kubeconfig.sh"
"${SCRIPT_DIR}/verify_octavia_lb.sh" "${TF_VAR_cluster_name}" "${ARTIFACT_DIR}"
"${SCRIPT_DIR}/bootstrap_platform.sh"
"${SCRIPT_DIR}/smoke_test_app.sh"

log "Full bootstrap succeeded. Artifacts: ${ARTIFACT_DIR}"
