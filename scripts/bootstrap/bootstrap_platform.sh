#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_bootstrap_env
ensure_required_bootstrap_vars

require_command kubectl openstack python3
require_file "${OS_CLIENT_CONFIG_FILE}"

export KUBECONFIG="${KUBECONFIG:-${MSP_KUBECONFIG_OUT}}"
require_file "${KUBECONFIG}"

ARTIFACT_DIR="${MSP_ACTIVE_ARTIFACT_DIR:-$(current_artifact_dir platform)}"
mkdir -p "${ARTIFACT_DIR}"

create_namespace() {
  local namespace="$1"
  kubectl create namespace "${namespace}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

create_bootstrap_secrets() {
  local auth_url="${OS_AUTH_URL:-$(clouds_yaml_value auth_url)}"
  local app_cred_id="${OS_APPLICATION_CREDENTIAL_ID:-$(clouds_yaml_value application_credential_id)}"
  local app_cred_secret="${OS_APPLICATION_CREDENTIAL_SECRET:-$(clouds_yaml_value application_credential_secret)}"
  local project_id="${OS_PROJECT_ID:-$(clouds_yaml_value project_id)}"
  local region_name="${OS_REGION_NAME:-$(clouds_yaml_value region_name)}"
  local auth_type="${OS_AUTH_TYPE:-$(clouds_yaml_value auth_type)}"
  local domain_name="${OS_DOMAIN_NAME:-$(clouds_yaml_value project_domain_name)}"

  create_namespace cert-manager
  create_namespace external-dns

  kubectl create secret generic os-application-credentials \
    --namespace cert-manager \
    --from-literal=OS_APPLICATION_CREDENTIAL_ID="${app_cred_id}" \
    --from-literal=OS_APPLICATION_CREDENTIAL_SECRET="${app_cred_secret}" \
    --from-literal=OS_PROJECT_ID="${project_id}" \
    --from-literal=OS_REGION_NAME="${region_name}" \
    --from-literal=OS_AUTH_URL="${auth_url}" \
    --from-literal=OS_AUTH_TYPE="${auth_type:-v3applicationcredential}" \
    --from-literal=OS_DOMAIN_NAME="${domain_name}" \
    --dry-run=client -o yaml | kubectl apply -f -

  kubectl create secret generic oscloudsyaml \
    --namespace external-dns \
    --from-file=clouds.yaml="${OS_CLIENT_CONFIG_FILE}" \
    --dry-run=client -o yaml | kubectl apply -f -
}

wait_for_application_crd() {
  kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=10m
}

wait_for_sync() {
  local namespace="$1"
  local resource="$2"
  local timeout_seconds="${3:-900}"
  local start_ts
  start_ts="$(date +%s)"

  while true; do
    local sync_status
    local health_status
    sync_status="$(kubectl -n "${namespace}" get application "${resource}" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    health_status="$(kubectl -n "${namespace}" get application "${resource}" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
    if [[ "${sync_status}" == "Synced" && "${health_status}" == "Healthy" ]]; then
      return 0
    fi
    if (( $(date +%s) - start_ts > timeout_seconds )); then
      die "Timed out waiting for Argo application ${resource} to become Healthy/Synced"
    fi
    sleep 10
  done
}

log "Waiting for all nodes to be Ready before bootstrap..."
kubectl wait --for=condition=Ready node --all --timeout=20m

create_bootstrap_secrets

log "Installing Argo CD bootstrap..."
kubectl apply -k "${MSP_REPO_ROOT}/cluster/bootstrap" --server-side --force-conflicts >"${ARTIFACT_DIR}/argocd-bootstrap.log" 2>&1
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=20m
wait_for_application_crd

log "Applying core platform applications..."
kubectl apply -k "${MSP_REPO_ROOT}/cluster/apps/platform-core" --server-side >"${ARTIFACT_DIR}/platform-applications.log" 2>&1

wait_for_sync argocd cert-manager
wait_for_sync argocd external-secrets
wait_for_sync argocd designate-certmanager-webhook
wait_for_sync argocd traefik
wait_for_sync argocd external-dns

kubectl wait --for=condition=available deployment --all -n cert-manager --timeout=20m
kubectl wait --for=condition=available deployment --all -n external-secrets --timeout=20m
kubectl wait --for=condition=available deployment --all -n traefik-system --timeout=20m
kubectl wait --for=condition=available deployment --all -n external-dns --timeout=20m

log "Applying cluster issuers and revocable admin RBAC..."
kubectl apply -k "${MSP_REPO_ROOT}/cluster/base/cert-manager" --server-side >"${ARTIFACT_DIR}/cluster-issuers.log" 2>&1
kubectl apply -k "${MSP_REPO_ROOT}/cluster/base/rbac" --server-side >"${ARTIFACT_DIR}/rbac.log" 2>&1

kubectl wait --for=condition=Ready clusterissuer/letsencrypt-staging --timeout=15m
kubectl wait --for=condition=Ready clusterissuer/letsencrypt-prod --timeout=15m

"${SCRIPT_DIR}/verify_octavia_lb.sh" "traefik-system/traefik" "${ARTIFACT_DIR}"

log "Core platform bootstrap finished successfully."
