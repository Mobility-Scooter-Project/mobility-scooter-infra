#!/bin/bash
set -e

echo "Installing k3s..."
export KUBECONFIG=/home/ubuntu/local-cluster.config
sudo curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig=$KUBECONFIG --disable=servicelb --tls-san $FLOATING_IP --tls-san 127.0.0.1 --disable-cloud-controller kubelet-arg cloud-provider=external --write-kubeconfig-mode=644" sh -

echo "Waiting for k3s to be ready..."
until kubectl get nodes &>/dev/null; do
  sleep 2
done

kubectl patch node "$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')" -p '{"spec":{"providerID":"openstack://IU/'${INSTANCE_ID}'"}}'

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

kubectl apply -f /tmp/cluster/base/argocd/ingress.yaml

IP=$(kubectl get svc -n kube-system traefik -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
echo "Traefik Dashboard is available at http://$IP/dashboard/"
echo "ArgoCD server is available at https://$IP/argocd"
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# TODO: assign dns records