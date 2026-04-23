#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_bootstrap_env

require_command kubectl

export KUBECONFIG="${KUBECONFIG:-${MSP_KUBECONFIG_OUT}}"
require_file "${KUBECONFIG}"

ARTIFACT_DIR="${MSP_ACTIVE_ARTIFACT_DIR:-$(current_artifact_dir smoke)}"
mkdir -p "${ARTIFACT_DIR}"

wait_for_smoke_application() {
  local timeout_seconds="${1:-900}"
  local start_ts
  start_ts="$(date +%s)"

  while true; do
    local sync_status
    local health_status
    sync_status="$(kubectl -n argocd get application smoke-web -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    health_status="$(kubectl -n argocd get application smoke-web -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
    if [[ "${sync_status}" == "Synced" && "${health_status}" == "Healthy" ]]; then
      return 0
    fi
    if (( $(date +%s) - start_ts > timeout_seconds )); then
      die "Timed out waiting for smoke-web Argo application to become Healthy/Synced"
    fi
    sleep 10
  done
}

wait_for_service_endpoints() {
  local namespace="$1"
  local name="$2"
  local timeout_seconds="${3:-600}"
  local start_ts
  start_ts="$(date +%s)"

  while true; do
    local addresses
    addresses="$(kubectl -n "${namespace}" get endpoints "${name}" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
    if [[ -n "${addresses}" ]]; then
      return 0
    fi
    if (( $(date +%s) - start_ts > timeout_seconds )); then
      die "Timed out waiting for endpoints on ${namespace}/${name}"
    fi
    sleep 10
  done
}

log "Deploying explicit smoke Argo application..."
kubectl apply -k "${MSP_REPO_ROOT}/cluster/apps/smoke" --server-side >"${ARTIFACT_DIR}/smoke-application.log" 2>&1

wait_for_smoke_application
kubectl wait --for=condition=available deployment/smoke-web-deployment -n smoke-web --timeout=20m
wait_for_service_endpoints smoke-web smoke-web-service

kubectl get ingress smoke-web-ingress -n smoke-web -o yaml >"${ARTIFACT_DIR}/smoke-ingress.yaml"
kubectl get service smoke-web-service -n smoke-web -o yaml >"${ARTIFACT_DIR}/smoke-service.yaml"
kubectl get endpoints smoke-web-service -n smoke-web -o yaml >"${ARTIFACT_DIR}/smoke-endpoints.yaml"

if kubectl get certificate smoke-web-tls -n smoke-web >/dev/null 2>&1; then
  kubectl wait --for=condition=Ready certificate/smoke-web-tls -n smoke-web --timeout=20m
  kubectl get certificate smoke-web-tls -n smoke-web -o yaml >"${ARTIFACT_DIR}/smoke-certificate.yaml"
fi

log "Smoke app is deployed. Expected host: ${MSP_SMOKE_APP_HOST}"
