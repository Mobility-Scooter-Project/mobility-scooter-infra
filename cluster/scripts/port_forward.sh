#!/bin/bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
kubectl port-forward svc/infisical-backend -n infisical 8081:8080 > /dev/null 2>&1 &
kubectl port-forward svc/kiali 20001:20001 -n istio-system > /dev/null 2>&1 &

echo "ArgoCD is now accessible at https://localhost:8080"
echo "Infisical is now accessible at http://localhost:8081"
echo "Kiali is now accessible at http://localhost:20001"