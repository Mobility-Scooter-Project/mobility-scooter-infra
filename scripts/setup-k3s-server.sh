#!/bin/bash
set -e

echo "Installing k3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig=$HOME/local-cluster.config --write-kubeconfig-mode=644 --disable=traefik --cloud-provider=external -- --kubelet-arg='cloud-provider=external'" sh -
export KUBECONFIG=$HOME/local-cluster.config

echo "Waiting for k3s to be ready..."
until kubectl get nodes &>/dev/null; do
  sleep 2
done
echo "k3s is ready!"

kubectl create secret -n kube-system generic cloud-config --from-file=/tmp/kustomize/base/openstack/cloud-config || true

kubectl apply -k /tmp/kustomize/base/openstack
kubectl apply -k /tmp/kustomize/base/argocd

echo "Waiting for ArgoCD server to be ready..."
until kubectl get svc -n argocd-server &>/dev/null; do
  sleep 2
done

kubectl patch svc argocd-server -n argocd -p '{"metadata": {"annotations": {"service.beta.kubernetes.io/openstack-internal-load-balancer": "false"}}}'

echo "Waiting for ArgoCD server to get an external IP..."
until curl -s -o /dev/null -w "%{http_code}" http://$FLOATING_IP &>/dev/null; do
  sleep 2
done

echo "ArgoCD server is available at http://$FLOATING_IP"
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

exit 1
