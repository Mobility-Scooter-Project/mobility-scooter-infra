#!bin/bash

# update package lists
sudo apt update

# install k3s
curl -sfL https://get.k3s.io | sh -
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
    --set ingress.nginx.enabled=false \
    --set ingress.ingressClassName=traefik \
    --set ingress.hostName=infisical.cis240470.projects.jetstream-cloud.org \
    --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod \
    --set ingress.annotations."traefik\.ingress\.kubernetes\.io/router\.entrypoints"=websecure \
    --set "ingress.tls[0].hosts[0]=infisical.cis240470.projects.jetstream-cloud.org" \
    --set "ingress.tls[0].secretName=infisical-tls" \
    --namespace infisical \
    --create-namespace

# create bootstrap secrets
kubectl create secret generic infisical-secrets -n infisical \
    --from-literal=AUTH_SECRET=$(openssl rand -base64 32) \
    --from-literal=ENCRYPTION_KEY=$(openssl rand -hex 16) \
    --from-literal=SITE_URL="https://infisical.cis240470.projects.jetstream-cloud.org"