#!/bin/bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &