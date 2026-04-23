#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_bootstrap_env
ensure_required_bootstrap_vars

require_command terraform openstack python3
require_file "${OS_CLIENT_CONFIG_FILE}"
require_openstack_plugin "Heat stack inspection" openstack stack list
require_openstack_plugin "Octavia load balancer inspection" openstack loadbalancer list
require_openstack_plugin "availability zone inspection" openstack availability zone list
require_command magnum

ARTIFACT_DIR="$(current_artifact_dir provision)"
export MSP_ACTIVE_ARTIFACT_DIR="${ARTIFACT_DIR}"
export TF_LOG=DEBUG
export TF_LOG_PATH="${ARTIFACT_DIR}/terraform-debug.log"

log "Artifact directory: ${ARTIFACT_DIR}"

run_preflight() {
  log "Validating OpenStack authentication..."
  openstack token issue -f json >"${ARTIFACT_DIR}/token.json"

  log "Capturing quota and flavor metadata..."
  openstack quota show --all --usage -f json >"${ARTIFACT_DIR}/quota-usage.json"
  openstack flavor show "${TF_VAR_master_flavor}" -f json >"${ARTIFACT_DIR}/master-flavor.json"
  openstack flavor show "${TF_VAR_node_flavor}" -f json >"${ARTIFACT_DIR}/node-flavor.json"
  openstack availability zone list --compute -f json >"${ARTIFACT_DIR}/nova-availability-zones.json"
  openstack availability zone list --volume -f json >"${ARTIFACT_DIR}/cinder-availability-zones.json"

  if [[ "${TF_VAR_nova_availability_zone}" != "${TF_VAR_cinder_availability_zone}" ]]; then
    die "Refusing cross-AZ bootstraps: nova=${TF_VAR_nova_availability_zone}, cinder=${TF_VAR_cinder_availability_zone}"
  fi

  python3 - "${ARTIFACT_DIR}" <<'PY'
import json
import os
import pathlib
import sys

artifact_dir = pathlib.Path(sys.argv[1])
nova_az = pathlib.Path(artifact_dir / "nova-availability-zones.json")
cinder_az = pathlib.Path(artifact_dir / "cinder-availability-zones.json")

selected_nova = os.environ["TF_VAR_nova_availability_zone"]
selected_cinder = os.environ["TF_VAR_cinder_availability_zone"]

def zone_names(path):
    data = json.loads(path.read_text())
    if isinstance(data, dict):
        data = [data]
    names = set()
    for item in data:
        if isinstance(item, dict):
            for key, value in item.items():
                if "zone" in key.lower() and isinstance(value, str):
                    names.add(value)
    return names

nova_names = zone_names(nova_az)
cinder_names = zone_names(cinder_az)

if selected_nova not in nova_names:
    raise SystemExit(f"Nova availability zone '{selected_nova}' not found in {sorted(nova_names)}")
if selected_cinder not in cinder_names:
    raise SystemExit(f"Cinder availability zone '{selected_cinder}' not found in {sorted(cinder_names)}")
PY

  log "Checking quota headroom..."
  python3 - "${ARTIFACT_DIR}" <<'PY'
import json
import os
import pathlib
import sys

artifact_dir = pathlib.Path(sys.argv[1])
quota_data = json.loads((artifact_dir / "quota-usage.json").read_text())
master_flavor = json.loads((artifact_dir / "master-flavor.json").read_text())
node_flavor = json.loads((artifact_dir / "node-flavor.json").read_text())

if isinstance(quota_data, list):
    quota_data = {entry["Resource"]: entry for entry in quota_data if isinstance(entry, dict) and "Resource" in entry}

resource_aliases = {
    "instances": ("instances", "servers"),
    "cores": ("cores",),
    "ram": ("ram",),
    "ports": ("ports",),
    "floating_ips": ("floating-ips", "floating_ips"),
    "volumes": ("volumes",),
    "gigabytes": ("gigabytes",),
    "security_groups": ("secgroups", "security-groups", "security_groups"),
    "security_group_rules": ("secgroup-rules", "security-group-rules", "security_group_rules"),
    "load_balancers": ("load-balancers", "load_balancers", "loadbalancers"),
}

def find_quota(name):
    for candidate in resource_aliases[name]:
        if candidate in quota_data:
            return quota_data[candidate]
    return None

def quota_available(entry):
    if entry is None:
        return None
    if isinstance(entry, dict):
        limit = entry.get("limit")
        used = entry.get("in_use", 0) + entry.get("reserved", 0)
        if limit in (-1, "-1", None):
            return None
        return int(limit) - int(used)
    return None

master_count = int(os.environ["TF_VAR_master_count"])
node_count = int(os.environ["TF_VAR_node_count"])
instance_count = master_count + node_count

docker_volume_size = int(os.environ["TF_VAR_docker_volume_size"])
boot_volume_size = int(os.environ["TF_VAR_boot_volume_size"])
etcd_volume_size = int(os.environ["TF_VAR_etcd_volume_size"])

estimated_volume_count = 0
estimated_gigabytes = 0

if docker_volume_size > 0:
    estimated_volume_count += instance_count
    estimated_gigabytes += instance_count * docker_volume_size
if boot_volume_size > 0:
    estimated_volume_count += instance_count
    estimated_gigabytes += instance_count * boot_volume_size
if etcd_volume_size > 0:
    estimated_volume_count += master_count
    estimated_gigabytes += master_count * etcd_volume_size

requirements = {
    "instances": instance_count,
    "cores": master_count * int(master_flavor["vcpus"]) + node_count * int(node_flavor["vcpus"]),
    "ram": master_count * int(master_flavor["ram"]) + node_count * int(node_flavor["ram"]),
    "ports": int(os.environ["MSP_ESTIMATED_PORTS"]),
    "floating_ips": int(os.environ["MSP_ESTIMATED_FLOATING_IPS"]),
    "volumes": estimated_volume_count,
    "gigabytes": estimated_gigabytes,
    "security_groups": int(os.environ["MSP_ESTIMATED_SECURITY_GROUPS"]),
    "security_group_rules": int(os.environ["MSP_ESTIMATED_SECURITY_GROUP_RULES"]),
    "load_balancers": int(os.environ["MSP_ESTIMATED_LOADBALANCERS"]),
}

report = []
for resource, needed in requirements.items():
    if needed <= 0:
        continue
    available = quota_available(find_quota(resource))
    report.append({"resource": resource, "required": needed, "available": available})
    if available is not None and available < needed:
        raise SystemExit(f"Quota preflight failed for {resource}: need {needed}, available {available}")

(artifact_dir / "quota-preflight.json").write_text(json.dumps(report, indent=2))
PY
}

run_terraform() {
  log "Running terraform init..."
  terraform -chdir="${MSP_REPO_ROOT}/infra" init -upgrade >"${ARTIFACT_DIR}/terraform-init.log" 2>&1

  log "Running terraform validate..."
  if ! terraform -chdir="${MSP_REPO_ROOT}/infra" validate >"${ARTIFACT_DIR}/terraform-validate.log" 2>&1; then
    warn "terraform validate failed."
    terraform_recovery_hint >&2
    return 1
  fi

  log "Applying Terraform..."
  if ! terraform -chdir="${MSP_REPO_ROOT}/infra" apply -auto-approve -input=false >"${ARTIFACT_DIR}/terraform-apply.log" 2>&1; then
    warn "terraform apply failed, collecting debug bundle..."
    "${SCRIPT_DIR}/collect_openstack_debug.sh" "${TF_VAR_cluster_name}" "${ARTIFACT_DIR}" || true
    return 1
  fi
}

run_preflight
run_terraform

log "Provisioning finished successfully."
