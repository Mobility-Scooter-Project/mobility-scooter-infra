#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_bootstrap_env

require_command openstack kubectl python3
require_openstack_plugin "Octavia load balancer inspection" openstack loadbalancer list

TARGET="${1:?Pass a Kubernetes service ref (namespace/name) or Magnum cluster name / load balancer ID.}"
ARTIFACT_DIR="${2:-$(current_artifact_dir lb)}"
mkdir -p "${ARTIFACT_DIR}"

export KUBECONFIG="${KUBECONFIG:-${MSP_KUBECONFIG_OUT}}"

resolve_lb_id() {
  python3 - "${TARGET}" "${ARTIFACT_DIR}" <<'PY'
import json
import subprocess
import sys
import time
from urllib.parse import urlparse

target = sys.argv[1]
artifact_dir = sys.argv[2]

def run_json(cmd):
    return json.loads(subprocess.check_output(cmd, text=True))

def lb_list():
    data = run_json(["openstack", "loadbalancer", "list", "-f", "json"])
    return data if isinstance(data, list) else [data]

lbs = lb_list()

def find_lb(predicate):
    for lb in lbs:
        if predicate(lb):
            lb_id = lb.get("id") or lb.get("ID")
            if lb_id:
                return str(lb_id)
    return ""

if "/" in target:
    namespace, name = target.split("/", 1)
    address = ""
    for _ in range(90):
        service = run_json(["kubectl", "-n", namespace, "get", "svc", name, "-o", "json"])
        ingress = service.get("status", {}).get("loadBalancer", {}).get("ingress", [])
        if ingress:
            address = ingress[0].get("ip") or ingress[0].get("hostname") or ""
        if address:
            break
        time.sleep(10)
    if address:
        lb_id = find_lb(lambda lb: address in json.dumps(lb))
        if lb_id:
            print(lb_id)
            sys.exit(0)
    lb_id = find_lb(lambda lb: name in json.dumps(lb))
    if lb_id:
        print(lb_id)
        sys.exit(0)
    sys.exit("Unable to resolve a load balancer for service " + target)

try:
    cluster = run_json(["magnum", "cluster-show", target, "-f", "json"])
    api_address = cluster.get("api_address", "")
    host = urlparse(api_address).hostname if "://" in api_address else api_address.split(":")[0]
    if host:
        lb_id = find_lb(lambda lb: host in json.dumps(lb))
        if lb_id:
            print(lb_id)
            sys.exit(0)
except Exception:
    pass

lb_id = find_lb(lambda lb: target == str(lb.get("id") or lb.get("ID") or "") or target == str(lb.get("name") or lb.get("Name") or ""))
if lb_id:
    print(lb_id)
    sys.exit(0)

sys.exit("Unable to resolve a load balancer for target " + target)
PY
}

LB_ID="$(resolve_lb_id)"
log "Resolved load balancer ${LB_ID} for ${TARGET}"

capture_details() {
  capture_cmd "${ARTIFACT_DIR}/loadbalancer-${LB_ID}-show.log" \
    openstack loadbalancer show "${LB_ID}" -f json
  capture_cmd "${ARTIFACT_DIR}/loadbalancer-${LB_ID}-listener-list.log" \
    openstack loadbalancer listener list --loadbalancer "${LB_ID}" -f json
  capture_cmd "${ARTIFACT_DIR}/loadbalancer-${LB_ID}-pool-list.log" \
    openstack loadbalancer pool list --loadbalancer "${LB_ID}" -f json

  local pool_ids
  pool_ids="$(python3 - "${ARTIFACT_DIR}/loadbalancer-${LB_ID}-pool-list.log" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
lines = [line for line in path.read_text().splitlines() if not line.startswith("$ ")]
payload = "\n".join(lines).strip()
if not payload:
    sys.exit(0)

try:
    data = json.loads(payload)
except Exception:
    sys.exit(0)

if isinstance(data, dict):
    data = [data]

for item in data:
    pool_id = item.get("id") or item.get("ID")
    if pool_id:
        print(pool_id)
PY
)"

  if [[ -n "${pool_ids}" ]]; then
    while IFS= read -r pool_id; do
      [[ -z "${pool_id}" ]] && continue
      capture_cmd "${ARTIFACT_DIR}/loadbalancer-${LB_ID}-pool-${pool_id}-members.log" \
        openstack loadbalancer member list "${pool_id}" -f json
    done <<<"${pool_ids}"
  fi

  if openstack_supports openstack loadbalancer amphora list; then
    capture_cmd "${ARTIFACT_DIR}/loadbalancer-${LB_ID}-amphora-list.log" \
      openstack loadbalancer amphora list --loadbalancer "${LB_ID}" -f json
  fi

  if [[ "${TARGET}" == */* ]]; then
    local namespace="${TARGET%/*}"
    local name="${TARGET#*/}"
    capture_cmd "${ARTIFACT_DIR}/service-${namespace}-${name}.log" \
      kubectl -n "${namespace}" get svc "${name}" -o yaml
  fi
}

TIMEOUT_SECONDS="${MSP_LB_VERIFY_TIMEOUT_SECONDS:-900}"
START_TS="$(date +%s)"

while true; do
  LB_STATUS_JSON="$(openstack loadbalancer show "${LB_ID}" -f json)"
  PROVISIONING_STATUS="$(python3 - "${LB_STATUS_JSON}" <<'PY'
import json
import sys
print(json.loads(sys.argv[1]).get("provisioning_status", ""))
PY
)"
  OPERATING_STATUS="$(python3 - "${LB_STATUS_JSON}" <<'PY'
import json
import sys
print(json.loads(sys.argv[1]).get("operating_status", ""))
PY
)"

  log "Load balancer ${LB_ID}: provisioning=${PROVISIONING_STATUS} operating=${OPERATING_STATUS}"

  if [[ "${PROVISIONING_STATUS}" == "ACTIVE" && "${OPERATING_STATUS}" == "ONLINE" ]]; then
    capture_details
    exit 0
  fi

  if (( $(date +%s) - START_TS > TIMEOUT_SECONDS )); then
    warn "Timed out waiting for load balancer ${LB_ID} to reach ACTIVE/ONLINE"
    capture_details
    exit 1
  fi

  sleep 10
done
