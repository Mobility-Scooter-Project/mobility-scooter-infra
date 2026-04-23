# Mobility Scooter Infra

Terraform and GitOps bootstrap for the Mobility Scooter Project Kubernetes
cluster on OpenStack Jetstream.

## What This Repo Owns

- Jetstream Magnum cluster creation through Terraform in `infra/`
- Core hosted platform bootstrap through Argo CD manifests in `cluster/`
- Reusable Helm charts for GHCR-hosted workloads in `charts/`
- Debug and bootstrap workflow in `scripts/bootstrap/`

## Local Contract

This repo now assumes two local-only files:

1. `infra/clouds.yaml`
2. `.env`

Both are ignored by Git.

Start from:

- [.env.example](/home/logarrett/mobility-scooter-infra/.env.example)
- [infra/clouds.yaml.example](/home/logarrett/mobility-scooter-infra/infra/clouds.yaml.example)

`.env` is the operational contract for the bootstrap scripts. It carries:

- `TF_VAR_*` values for Terraform
- `OS_CLOUD` / `OS_CLIENT_CONFIG_FILE` for OpenStack CLI auth
- optional bootstrap overrides such as artifact paths and smoke hostname

`infra/clouds.yaml` is the local OpenStack client config used by Terraform and
by the bootstrap scripts when they materialize Kubernetes bootstrap secrets.

## Required Tooling

The scripts assume these commands are available:

- `terraform`
- `openstack`
- `magnum`
- `kubectl`
- `helm`
- `python3`

For hosted debugging you also need Heat and Octavia CLI plugins. The devcontainer
installs them through `.devcontainer/post-create.sh`.

## Bootstrap Workflow

### 1. Provision and debug the Magnum cluster

```bash
./scripts/bootstrap/provision_cluster.sh
```

This does:

- OpenStack auth validation
- quota and availability-zone preflight checks
- `terraform init` and `terraform validate`
- `terraform apply` with debug logging
- automatic OpenStack debug bundle collection on failure

Artifacts land under `.artifacts/bootstrap/`.

### 2. Export kubeconfig

```bash
./scripts/bootstrap/export_kubeconfig.sh
```

This writes a local `kubeconfig.yaml` and sets file mode to `0600`.

### 3. Bootstrap the hosted platform

```bash
./scripts/bootstrap/bootstrap_platform.sh
```

This stage-gates:

- Argo CD bootstrap
- cert-manager
- external-secrets
- designate cert-manager webhook
- Traefik as an explicit `LoadBalancer`
- external-dns
- revocable admin RBAC

It also creates the local-only bootstrap secrets that cert-manager and
external-dns need so the platform no longer depends on Infisical for the first
hosted path.

### 4. Deploy the smoke app

```bash
./scripts/bootstrap/smoke_test_app.sh
```

This applies one explicit Argo CD `Application` from this repo and waits for:

- Argo sync
- smoke deployment readiness
- ingress address assignment
- certificate readiness when cert-manager creates it

The explicit platform and smoke Argo applications target the GitHub `main`
branch, so push the corresponding repo changes before running the hosted smoke
path against a fresh cluster.

### 5. Full flow

```bash
./scripts/bootstrap/bootstrap_cluster.sh
```

This runs the full sequence:

1. provision
2. kubeconfig export
3. Magnum API load balancer verification
4. platform bootstrap
5. Traefik load balancer verification
6. smoke app deployment

## Debug Bundle Contents

`collect_openstack_debug.sh` captures:

- Magnum cluster details when the CLI is available
- Heat stacks, resources, and events
- Nova server state and console logs
- Neutron networks, ports, and floating IPs
- Cinder volumes
- Octavia load balancers, listeners, pools, members, and amphorae when available

## Terraform Provider Cache Recovery

If `terraform validate` fails with provider handshake or schema-loading errors,
reset the local provider cache and re-init:

```bash
rm -rf infra/.terraform/providers
terraform -chdir=infra init -upgrade
terraform -chdir=infra validate
```

## Current Hosted Scope

The initial hosted bootstrap intentionally excludes:

- Infisical
- Kargo
- Istio
- CNPG
- monitoring stack
- GitHub Actions Runner Controller
- oauth2-proxy

Those can be layered back in after the core Magnum and hosted ingress path is
reliable.
