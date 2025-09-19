#!/bin/bash
START=$(date +%s)
echo "Modifiying kubelet config..."
kubectl patch cm -n kube-system kubelet-config --patch-file cluster/overlays/prod/kubelet-config.yaml

echo "Applying bootstrap manifests..."
kubectl apply -k cluster/bootstrap

echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd

echo "ArgoCD is ready. Installing helm charts..."
kubectl apply -k cluster/helm --server-side

echo "Waiting for helm charts to be ready..."
kubectl wait --for=condition=available deployment -n external-secrets --all
kubectl wait --for=condition=available deployment -n infisical  --all

echo "Applying prod overlay..."
kubectl kustomize cluster/overlays/prod --enable-helm | kubectl apply -f - --server-side --force-conflicts

echo "Waiting for traefik to be ready..."
kubectl wait --for=condition=available deployment -n traefik-system --all

echo "Editing kube-prometheus-stack config..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack --version 77.7.0 --namespace monitoring-system

echo "Patching Grafana ConfigMap to enable feature toggles..."
kubectl patch configmap kube-prometheus-stack-grafana -n monitoring-system --type merge --patch-file scripts/bootstrap/grafanacm.yaml

echo "Restarting Grafana deployment to apply changes..."
kubectl rollout restart deployment kube-prometheus-stack-grafana -n monitoring-system

echo "Finished applying manifests after $(( $(date +%s) - $START )) seconds."