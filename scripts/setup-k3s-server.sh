#!/bin/bash
set -e

# Install kubectl
echo "Installing kubectl..."


echo "Installing k3s..."
sudo curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=$FLOATING_IP --write-kubeconfig-mode 644" sh -

echo "Waiting for k3s to be ready..."
until kubectl get nodes &>/dev/null; do
  kubectl get nodes
  sleep 2
done
echo "k3s is ready!"

kubectl create secret -n kube-system generic cloud-config --from-file=/tmp/kustomize/base/openstack/cloud.conf || true
#kubectl create secret -n kube-system generic cloud-config --from-file=cluster/base/openstack/cloud.conf || true

kubectl apply -k /tmp/kustomize/base/openstack
kubectl apply -k /tmp/kustomize/base/argocd
#kubectl apply -k cluster/base/openstack
#kubectl apply -k cluster/base/argocd

echo "Waiting for ArgoCD server to be ready..."
until kubectl get svc -n argocd-server &>/dev/null; do
  sleep 2
done

echo "Waiting for ArgoCD server to get an external IP..."
until [[ -n "$FLOATING_IP" ]]; do
  kubectl get svc argocd-server -n argocd -o jsonpath="{.status.loadBalancer.ingress[0].ip}"
  FLOATING_IP=$(kubectl get svc argocd-server -n argocd -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
  sleep 2
done

echo "ArgoCD server is available at http://$FLOATING_IP"
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d