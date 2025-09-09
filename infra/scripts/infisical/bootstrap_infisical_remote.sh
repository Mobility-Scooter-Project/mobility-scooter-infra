#!bin/bash

# update package lists
sudo apt update

# install k3s
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -
sudo usermod -aG k3s ubuntu
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# install infisical helm chart
helm repo add infisical-helm-charts 'https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/'
helm repo update

helm upgrade --install infisical infisical-helm-charts/infisical-standalone \
    --set infisical.image.tag=v0.148.1 \
    --set ingress.nginx.enabled=true \
    --set ingress.nginx.hostName=infisical.cis240470.projects.jetstream-cloud.org \
    --namespace infisical \
    --create-namespace

# create bootstrap secrets
kubectl create secret generic infisical-secrets -n infisical \
    --from-literal=AUTH_SECRET=$(openssl rand -base64 32) \
    --from-literal=ENCRYPTION_KEY=$(openssl rand -hex 16) \
    --from-literal=SITE_URL="http://infisical.cis240470.projects.jetstream-cloud.org"