k3d cluster delete msp-dev || true
k3d cluster create msp-dev --agents 1 --image rancher/k3s:v1.30.14-k3s2-amd64

sh scripts/bootstrap_cluster.sh