#!bin/bash

# This script applies labels to all namespaces in a Kubernetes cluster.
namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')
for ns in $namespaces; do
  echo "Applying label to namespace: $ns"
  kubectl label namespace "$ns" istio.io/dataplane-mode=ambient --overwrite
done