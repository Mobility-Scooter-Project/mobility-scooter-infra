#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_bootstrap_env
ensure_required_bootstrap_vars

require_command openstack python3
require_file "${OS_CLIENT_CONFIG_FILE}"
require_openstack_plugin "Heat stack inspection" openstack stack list

CLUSTER_REF="${1:-${TF_VAR_cluster_name}}"
ARTIFACT_DIR="${2:-$(current_artifact_dir debug)}"

mkdir -p "${ARTIFACT_DIR}"

log "Collecting debug bundle for cluster reference: ${CLUSTER_REF}"

capture_cmd "${ARTIFACT_DIR}/openstack-stack-list.log" \
  openstack stack list --nested --long -f json
capture_cmd "${ARTIFACT_DIR}/openstack-server-list.log" \
  openstack server list --long -f json
capture_cmd "${ARTIFACT_DIR}/openstack-port-list.log" \
  openstack port list --long -f json
capture_cmd "${ARTIFACT_DIR}/openstack-floating-ip-list.log" \
  openstack floating ip list --long -f json
capture_cmd "${ARTIFACT_DIR}/openstack-volume-list.log" \
  openstack volume list --long -f json
capture_cmd "${ARTIFACT_DIR}/openstack-network-list.log" \
  openstack network list --long -f json

if command -v magnum >/dev/null 2>&1; then
  capture_cmd "${ARTIFACT_DIR}/magnum-cluster-show.log" \
    magnum cluster-show "${CLUSTER_REF}" -f json
  capture_cmd "${ARTIFACT_DIR}/magnum-cluster-template-list.log" \
    magnum cluster-template-list -f json
fi

if openstack_supports openstack loadbalancer list; then
  capture_cmd "${ARTIFACT_DIR}/octavia-loadbalancer-list.log" \
    openstack loadbalancer list -f json
fi

python3 - "${ARTIFACT_DIR}" "${CLUSTER_REF}" <<'PY'
import json
import pathlib
import subprocess
import sys

artifact_dir = pathlib.Path(sys.argv[1])
cluster_ref = sys.argv[2]

def safe_json(path):
    try:
        text = path.read_text()
        lines = [line for line in text.splitlines() if not line.startswith("$ ")]
        payload = "\n".join(lines).strip()
        return json.loads(payload) if payload else []
    except Exception:
        return []

def run_to_file(path, command):
    with path.open("w") as fh:
        fh.write("$ " + " ".join(command) + "\n")
        subprocess.run(command, stdout=fh, stderr=subprocess.STDOUT, check=False, text=True)

stack_id = None
magnum_show = artifact_dir / "magnum-cluster-show.log"
if magnum_show.exists():
    lines = [line for line in magnum_show.read_text().splitlines() if not line.startswith("$ ")]
    payload = "\n".join(lines).strip()
    if payload:
        try:
            data = json.loads(payload)
            stack_id = data.get("stack_id")
        except Exception:
            stack_id = None

if stack_id:
    run_to_file(artifact_dir / "openstack-stack-show.log", ["openstack", "stack", "show", stack_id, "-f", "json"])
    run_to_file(artifact_dir / "openstack-stack-resource-list.log", ["openstack", "stack", "resource", "list", stack_id, "-f", "json"])
    run_to_file(artifact_dir / "openstack-stack-event-list.log", ["openstack", "stack", "event", "list", stack_id, "-f", "json"])

servers = safe_json(artifact_dir / "openstack-server-list.log")
if isinstance(servers, dict):
    servers = [servers]

for server in servers:
    if not isinstance(server, dict):
        continue
    name = str(server.get("Name", server.get("name", "")))
    server_id = str(server.get("ID", server.get("id", "")))
    if cluster_ref not in name:
        continue
    slug = server_id or name.replace("/", "-")
    run_to_file(artifact_dir / f"server-{slug}-show.log", ["openstack", "server", "show", server_id, "-f", "json"])
    run_to_file(artifact_dir / f"server-{slug}-console.log", ["openstack", "console", "log", "show", server_id])

loadbalancers = safe_json(artifact_dir / "octavia-loadbalancer-list.log")
if isinstance(loadbalancers, dict):
    loadbalancers = [loadbalancers]

for lb in loadbalancers:
    if not isinstance(lb, dict):
        continue
    lb_name = str(lb.get("name", lb.get("Name", "")))
    lb_id = str(lb.get("id", lb.get("ID", "")))
    if not lb_id:
        continue
    if cluster_ref not in lb_name and cluster_ref not in json.dumps(lb):
        continue
    run_to_file(artifact_dir / f"loadbalancer-{lb_id}-show.log", ["openstack", "loadbalancer", "show", lb_id, "-f", "json"])
    run_to_file(artifact_dir / f"loadbalancer-{lb_id}-listener-list.log", ["openstack", "loadbalancer", "listener", "list", "--loadbalancer", lb_id, "-f", "json"])
    run_to_file(artifact_dir / f"loadbalancer-{lb_id}-pool-list.log", ["openstack", "loadbalancer", "pool", "list", "--loadbalancer", lb_id, "-f", "json"])
    run_to_file(artifact_dir / f"loadbalancer-{lb_id}-amphora-list.log", ["openstack", "loadbalancer", "amphora", "list", "--loadbalancer", lb_id, "-f", "json"])
PY

log "Debug bundle written to ${ARTIFACT_DIR}"
