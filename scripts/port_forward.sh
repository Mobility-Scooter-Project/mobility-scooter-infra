#!/bin/bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
kubectl port-forward svc/infisical-backend -n infisical 8081:8080 > /dev/null 2>&1 &