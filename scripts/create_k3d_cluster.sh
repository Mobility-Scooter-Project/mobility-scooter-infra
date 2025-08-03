k3d cluster delete msp-dev || true
k3d cluster create msp-dev --agents 1 -p "80:80@loadbalancer" -p "443:443@loadbalancer" 

kubectl apply -k cluster/bootstrap
echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
echo "ArgoCD is ready. Installing helm charts..."
kubectl apply -k cluster/helm
echo "Cluster bootstrapped successfully."