k3d cluster delete msp-dev || true
k3d cluster create msp-dev --agents 1 --image rancher/k3s:v1.30.14-k3s2-amd64

kubectl apply -k cluster/bootstrap
echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
echo "ArgoCD is ready. Installing helm charts..."
kubectl apply -k cluster/helm --server-side
echo "Cluster bootstrapped successfully."