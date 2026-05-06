#!bin/bash
cd ./infra && terraform output kubeconfig | tail -n +2 | head -n -2 > kubeconfig.yaml
mv kubeconfig.yaml ../kubeconfig.yaml
