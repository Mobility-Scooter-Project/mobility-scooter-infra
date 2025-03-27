#!/bin/bash
set -e

echo "Installing k3s..."
export KUBECONFIG=/home/ubuntu/local-cluster.config
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig=$KUBECONFIG --disable-cloud-controller kubelet-arg='cloud-provider=external' --write-kubeconfig-mode=644" sh -

echo "Waiting for k3s to be ready..."
until kubectl get nodes &>/dev/null; do
  kubectl get nodes
  sleep 2
done

echo "Waiting for Traefik to be assigned an external IP..."
until kubectl get svc -n kube-system traefik &>/dev/null; do
  sleep 2
done

kubectl apply -k /tmp/kustomize/base/traefik
#kubectl apply -k cluster/base/traefik


kubectl create secret -n kube-system generic cloud-config --from-file=/tmp/kustomize/base/openstack/cloud.conf || true
#kubectl create secret -n kube-system generic cloud-config --from-file=cluster/base/openstack/cloud.conf

kubectl apply -k /tmp/kustomize/base/openstack
kubectl apply -k /tmp/kustomize/base/argocd

#kubectl apply -k cluster/base/argocd
#kubectl apply -k cluster/base/openstack

echo "Waiting for ArgoCD server to be ready..."
until kubectl get svc -n argocd-server &>/dev/null; do
  sleep 2
done

sleep 30

kubectl apply -f /tmp/kustomize/base/argocd/ingress.yaml
#kubectl apply -f cluster/base/argocd/ingress.yaml

IP=$(kubectl get svc -n kube-system traefik -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
echo "Traefik Dashboard is available at http://$IP/dashboard/"
echo "ArgoCD server is available at https://$IP/argocd"
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
echo $HOME/local-cluster.config