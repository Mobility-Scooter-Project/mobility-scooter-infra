#!/bin/bash

# This script removes labels from all namespaces in a Kubernetes cluster.
namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')
for ns in $namespaces; do
    echo "Removing label from namespace: $ns"
    kubectl label namespace "$ns" istio.io/dataplane-mode-
done