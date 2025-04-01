#!/bin/bash
set -e

# A random user id is used by Terraform to create the instance, so we need to use /home/ubuntu
# to ensure the k3s config can be read by the local-exec provisioner that runs after this script.
export KUBECONFIG=/home/ubuntu/local-cluster.config

# This script needs to run as root in order to access /home/ubuntu
# Servicelb is disabled because it is conflicts with Open Stack Cloud Controller Manager.
# The floating IP is passed to the script via an environment variable to allow TLS with external
# access.
echo "Installing k3s..."
sudo curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig=$KUBECONFIG --disable=servicelb --tls-san $FLOATING_IP --tls-san 127.0.0.1 --disable-cloud-controller kubelet-arg cloud-provider=external --write-kubeconfig-mode=644" sh -

echo "Waiting for k3s to be ready..."
# Add an extra delay to ensure the node is ready - sometimes the check below it is not enough
sleep 5
until kubectl get nodes &>/dev/null; do
  sleep 2
done

# For some unknown reason, when setting manage-security-groups=true in cluster/base/openstack/cloud.conf,
# the OpenStack cloud controller manager does not work assign the cluster a providerID.
# This is a workaround to set the providerID manually.
kubectl patch node "$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')" -p '{"spec":{"providerID":"openstack://IU/'${INSTANCE_ID}'"}}'

# An example cloud.conf file is provided in the repo at cluster/base/openstack/cloud.conf.example
# Credentials can be retrieved from the Jetstream Horizon dashboard at https://js2.jetstream-cloud.org
kubectl create secret -n kube-system generic cloud-config --from-file=/tmp/cluster/base/openstack/cloud.conf || true
kubectl apply -k /tmp/cluster/base/openstack

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.0/cert-manager.yaml
echo "Waiting for cert-manager webhook to be ready..."
kubectl wait --for=condition=ready pod -l app=webhook -n cert-manager --timeout=120s
kubectl apply -f /tmp/cluster/base/cert-manager/issuer-staging.yaml

echo "Waiting for Traefik to be ready..."
until kubectl get svc -n kube-system traefik &>/dev/null; do
  sleep 2
done

kubectl apply -k /tmp/cluster/base/traefik

echo "Waiting for Traefik to be assigned an external IP...(this may take a few minutes)"
until IP=$(kubectl get svc -n kube-system traefik -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null) && [ -n "$IP" ]; do
  kubectl get svc -n kube-system traefik
  sleep 10
done
echo "Load balancer external IP: $IP"

# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Headlamp
kubectl apply -k /tmp/cluster/base/headlamp
kubectl -n kube-system create serviceaccount headlamp-admin
kubectl create clusterrolebinding headlamp-admin --serviceaccount=kube-system:headlamp-admin --clusterrole=cluster-admin

# Install ArgoCD
kubectl apply -k /tmp/cluster/base/argocd

echo "Waiting for ArgoCD server to be ready..."
until kubectl get svc -n argocd-server &>/dev/null; do
  sleep 2
done

# Install OpenStack CLI
sudo apt-get update && sudo apt-get install python3-designateclient python3-openstackclient -y

echo "Converting cloud.conf to .env format..."

# Process the cloud.conf file into .env format
while IFS='=' read -r key value; do
  # Skip comments and empty lines
  if [[ -n "$key" && ! "$key" =~ ^[[:space:]]*# ]]; then
    # Trim leading/trailing whitespace and capitalize
    key=$(echo "$key" | xargs | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    echo "OS_${key}=${value}"
  fi
done < /tmp/cluster/base/openstack/cloud.conf > /tmp/cluster/base/openstack/.env

# Set the environment variables for OpenStack CLI
# This allows the source command to work in a non-interactive shell
set -a
source /tmp/cluster/base/openstack/.env
set +a

export OS_AUTH_TYPE=v3applicationcredential
export OS_USER_DOMAIN_NAME=access

## Assign DNS records to the load balancer IP
DOMAIN=cis240470.projects.jetstream-cloud.org

openstack recordset create --type A --record "$IP" $DOMAIN. argocd
openstack recordset create --type A --record "$IP" $DOMAIN. traefik
openstack recordset create --type A --record "$IP" $DOMAIN. dashboard

# The trailing slash is important for the Traefik dashboard URL IngressRoute
echo "Traefik dashboard is available at http://traefik.$DOMAIN/dashboard/"
echo "ArgoCD server is available at https://argocd.$DOMAIN"
echo "Argo initial admin password: $(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)"
echo "Headlamp is available at http://headlamp.$DOMAIN"
echo "Headlamp admin token $(kubectl create clusterrolebinding headlamp-admin --serviceaccount=kube-system:headlamp-admin --clusterrole=cluster-admin)"