#!bin/bash
START=$(date +%s)
echo "Bootstrapping cluster..."
. ./.env

sh scripts/bootstrap/apply_terraform.sh

sh scripts/bootstrap/get_kubeconfig.sh
export KUBECONFIG=kubeconfig.yaml

# run it twice, once to download CRDs, second time to apply everything else
sh scripts/bootstrap/apply_cluster_manifests.sh
sh scripts/bootstrap/apply_cluster_manifests.sh

echo "Cluster bootstrapped successfully after $(( $(date +%s) - $START )) seconds."