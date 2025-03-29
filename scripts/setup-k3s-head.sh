#!/bin/bash
set -e

# A random user id is used by Terraform to create the instance, so we need to use /home/ubuntu
# to ensure the k3s config can be read by the local-exec provisioner that runs after this script.
export KUBECONFIG=/home/ubuntu/local-cluster.config

# This script needs to run as root in order to access /home/ubuntu
# Servicelb is disabled because it is not necessary with Open Stack Cloud Controller Manager.
# The floating IP is passed to the script via an environment variable to allow TLS with external
# access.
echo "Installing k3s..."
sudo curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig=$KUBECONFIG --disable=servicelb --tls-san $FLOATING_IP --tls-san 127.0.0.1 --disable-cloud-controller kubelet-arg cloud-provider=external --write-kubeconfig-mode=644" sh -

echo "Waiting for k3s to be ready..."
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

echo "Waiting for Traefik to be assigned an external IP..."
until kubectl get svc -n kube-system traefik &>/dev/null; do
  sleep 2
done

kubectl apply -k /tmp/cluster/base/traefik

# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard

# Install ArgoCD
kubectl apply -k /tmp/cluster/base/argocd

echo "Waiting for ArgoCD server to be ready..."
until kubectl get svc -n argocd-server &>/dev/null; do
  sleep 2
done

# Its important that the ingress is applied after Traefik is ready, otherwise
# Traefik will throw an error.
kubectl apply -f /tmp/cluster/base/argocd/ingress.yaml

IP=$(kubectl get svc -n kube-system traefik -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
echo "Traefik Dashboard is available at http://$IP/dashboard/"
echo "ArgoCD server is available at https://$IP/argocd"
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# TODO: assign dns records