#!/bin/bash
set -e

FLOATING_IP=$(curl https://ipinfo.io/ip)

echo "Installing k3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig=$HOME/local-cluster.config --write-kubeconfig-mode=644" sh -
export KUBECONFIG=$HOME/local-cluster.config

echo "Waiting for k3s to be ready..."
until kubectl get nodes &>/dev/null; do
  kubectl get nodes
  sleep 2
done
echo "k3s is ready!"

kubectl create secret -n kube-system generic cloud-config --from-file=/tmp/kustomize/base/openstack/cloud.conf || true
#kubectl create secret -n kube-system generic cloud-config --from-file=cluster/base/openstack/cloud.conf || true

#kubectl apply -k /tmp/kustomize/base/openstack
#kubectl apply -k /tmp/kustomize/base/argocd
kubectl apply -k cluster/base/openstack
kubectl apply -k cluster/base/argocd

echo "Waiting for ArgoCD server to be ready..."
until kubectl get svc -n argocd-server &>/dev/null; do
  sleep 2
done

echo "ArgoCD server is available at http://$FLOATING_IP"
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d