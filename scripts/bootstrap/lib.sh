#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MSP_REPO_ROOT="$(cd "${BOOTSTRAP_LIB_DIR}/../.." && pwd)"

log() {
  printf '[msp] %s\n' "$*"
}

warn() {
  printf '[msp][warn] %s\n' "$*" >&2
}

die() {
  printf '[msp][error] %s\n' "$*" >&2
  exit 1
}

require_command() {
  local cmd
  for cmd in "$@"; do
    command -v "${cmd}" >/dev/null 2>&1 || die "Required command not found: ${cmd}"
  done
}

require_file() {
  local path="$1"
  [[ -f "${path}" ]] || die "Required file not found: ${path}"
}

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

repo_root() {
  printf '%s\n' "${MSP_REPO_ROOT}"
}

clouds_yaml_value() {
  local key="$1"
  awk -v target="${key}" '
    $0 ~ "^[[:space:]]*" target ":[[:space:]]*" {
      line = $0
      sub("^[[:space:]]*" target ":[[:space:]]*", "", line)
      gsub(/^"/, "", line)
      gsub(/"$/, "", line)
      print line
      exit
    }
  ' "${OS_CLIENT_CONFIG_FILE}"
}

load_bootstrap_env() {
  local env_file="${MSP_REPO_ROOT}/.env"

  if [[ -f "${env_file}" ]]; then
    # shellcheck disable=SC1090
    source "${env_file}"
  fi

  export OS_CLOUD="${OS_CLOUD:-openstack}"
  export OS_CLIENT_CONFIG_FILE="${OS_CLIENT_CONFIG_FILE:-${MSP_REPO_ROOT}/infra/clouds.yaml}"

  export TF_VAR_cluster_name="${TF_VAR_cluster_name:-msp-cluster-prod}"
  export TF_VAR_cluster_template_name="${TF_VAR_cluster_template_name:-msp-k8s-v1-30}"
  export TF_VAR_cluster_image_name="${TF_VAR_cluster_image_name:-ubuntu-jammy-kube-v1.30.4-240828-1653}"
  export TF_VAR_external_network_name="${TF_VAR_external_network_name:-public}"
  export TF_VAR_fixed_network_name="${TF_VAR_fixed_network_name:-auto_allocated_network}"
  export TF_VAR_master_count="${TF_VAR_master_count:-1}"
  export TF_VAR_node_count="${TF_VAR_node_count:-1}"
  export TF_VAR_master_flavor="${TF_VAR_master_flavor:-m3.small}"
  export TF_VAR_node_flavor="${TF_VAR_node_flavor:-m3.medium}"
  export TF_VAR_dns_nameserver="${TF_VAR_dns_nameserver:-8.8.8.8}"
  export TF_VAR_docker_volume_size="${TF_VAR_docker_volume_size:-20}"
  export TF_VAR_docker_volume_type="${TF_VAR_docker_volume_type:-}"
  export TF_VAR_boot_volume_size="${TF_VAR_boot_volume_size:-0}"
  export TF_VAR_boot_volume_type="${TF_VAR_boot_volume_type:-}"
  export TF_VAR_etcd_volume_size="${TF_VAR_etcd_volume_size:-0}"
  export TF_VAR_etcd_volume_type="${TF_VAR_etcd_volume_type:-}"
  export TF_VAR_network_driver="${TF_VAR_network_driver:-calico}"
  export TF_VAR_volume_driver="${TF_VAR_volume_driver:-cinder}"
  export TF_VAR_docker_storage_driver="${TF_VAR_docker_storage_driver:-overlay2}"
  export TF_VAR_kube_tag="${TF_VAR_kube_tag:-v1.30.4}"
  export TF_VAR_floating_ip_enabled="${TF_VAR_floating_ip_enabled:-true}"
  export TF_VAR_master_lb_enabled="${TF_VAR_master_lb_enabled:-true}"
  export TF_VAR_create_timeout_minutes="${TF_VAR_create_timeout_minutes:-60}"
  export TF_VAR_monitoring_enabled="${TF_VAR_monitoring_enabled:-false}"
  export TF_VAR_influx_grafana_dashboard_enabled="${TF_VAR_influx_grafana_dashboard_enabled:-false}"
  export TF_VAR_cloud_provider_enabled="${TF_VAR_cloud_provider_enabled:-true}"
  export TF_VAR_cinder_csi_enabled="${TF_VAR_cinder_csi_enabled:-true}"
  export TF_VAR_auto_healing_enabled="${TF_VAR_auto_healing_enabled:-false}"
  export MSP_ARTIFACTS_DIR="${MSP_ARTIFACTS_DIR:-${MSP_REPO_ROOT}/.artifacts/bootstrap}"
  export MSP_KUBECONFIG_OUT="${MSP_KUBECONFIG_OUT:-${MSP_REPO_ROOT}/kubeconfig.yaml}"
  export MSP_SMOKE_APP_HOST="${MSP_SMOKE_APP_HOST:-smoke.cis240470.projects.jetstream-cloud.org}"
  export MSP_ESTIMATED_FLOATING_IPS="${MSP_ESTIMATED_FLOATING_IPS:-2}"
  export MSP_ESTIMATED_LOADBALANCERS="${MSP_ESTIMATED_LOADBALANCERS:-2}"
  export MSP_ESTIMATED_PORTS="${MSP_ESTIMATED_PORTS:-8}"
  export MSP_ESTIMATED_SECURITY_GROUPS="${MSP_ESTIMATED_SECURITY_GROUPS:-2}"
  export MSP_ESTIMATED_SECURITY_GROUP_RULES="${MSP_ESTIMATED_SECURITY_GROUP_RULES:-24}"
}

ensure_required_bootstrap_vars() {
  : "${TF_VAR_cluster_keypair_name:?Set TF_VAR_cluster_keypair_name in .env}"
  : "${TF_VAR_nova_availability_zone:?Set TF_VAR_nova_availability_zone in .env}"
  : "${TF_VAR_cinder_availability_zone:?Set TF_VAR_cinder_availability_zone in .env}"
}

current_artifact_dir() {
  local label="${1:-run}"
  local base_dir="${MSP_ARTIFACTS_DIR%/}"

  if [[ -n "${MSP_ACTIVE_ARTIFACT_DIR:-}" ]]; then
    mkdir -p "${MSP_ACTIVE_ARTIFACT_DIR}"
    printf '%s\n' "${MSP_ACTIVE_ARTIFACT_DIR}"
    return
  fi

  local dir="${base_dir}/$(date +%Y%m%d-%H%M%S)-${label}"
  mkdir -p "${dir}"
  printf '%s\n' "${dir}"
}

capture_cmd() {
  local outfile="$1"
  shift
  {
    printf '$'
    local arg
    for arg in "$@"; do
      printf ' %q' "${arg}"
    done
    printf '\n'
    "$@"
  } >"${outfile}" 2>&1 || true
}

openstack_supports() {
  "$@" --help >/dev/null 2>&1
}

require_openstack_plugin() {
  local description="$1"
  shift
  openstack_supports "$@" || die "OpenStack CLI support missing for ${description}. Install the required client plugin."
}

terraform_recovery_hint() {
  cat <<EOF
Terraform provider cache recovery:
  rm -rf ${MSP_REPO_ROOT}/infra/.terraform/providers
  terraform -chdir=${MSP_REPO_ROOT}/infra init -upgrade
  terraform -chdir=${MSP_REPO_ROOT}/infra validate
EOF
}
