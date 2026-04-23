#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_bootstrap_env
ensure_required_bootstrap_vars

require_command terraform

KUBECONFIG_PATH="${MSP_KUBECONFIG_OUT}"
mkdir -p "$(dirname "${KUBECONFIG_PATH}")"

terraform -chdir="${MSP_REPO_ROOT}/infra" output -raw kubeconfig >"${KUBECONFIG_PATH}"
chmod 600 "${KUBECONFIG_PATH}"

log "Wrote kubeconfig to ${KUBECONFIG_PATH}"
