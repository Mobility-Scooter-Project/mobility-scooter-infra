#!bin/bash
sh scripts/get_kubeconfig.sh
export KUBECONFIG=./kubeconfig.yaml

kubectl apply -k cluster/bootstrap
echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
echo "ArgoCD is ready. Installing helm charts..."
kubectl apply -k cluster/helm --server-side
echo "Cluster bootstrapped successfully."
kubectl label nodes msp-cluster-prod-pf7tmralo3ip-default-worker-qz5bf-jzqr5 nvidia.com/gpu.deploy.operands=false