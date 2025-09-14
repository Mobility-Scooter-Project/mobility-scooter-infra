#!/bin/bash

# ==> MODIFY THESE TWO VARIABLES
SERVICE_ACCOUNT_NAME="devpod-sa"
NAMESPACE="devpod"
# <==

echo "🔎 Finding token secret for service account '$SERVICE_ACCOUNT_NAME'..."

# Find the secret name associated with the service account
# We look for a secret with the specific annotation that links it to the SA
SECRET_NAME=$(kubectl get secrets -n "$NAMESPACE" -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='$SERVICE_ACCOUNT_NAME')].metadata.name}")

# Check if a secret was found
if [ -z "$SECRET_NAME" ]; then
  echo "❌ Error: Could not find a token secret for service account '$SERVICE_ACCOUNT_NAME' in namespace '$NAMESPACE'."
  echo "Please ensure you have applied the YAML to create the Service Account and its associated secret."
  exit 1
fi

echo "✅ Found secret: $SECRET_NAME"

# Get the server URL and CA data from the current context
CURRENT_CONTEXT=$(kubectl config current-context)
CLUSTER_NAME=$(kubectl config get-contexts "$CURRENT_CONTEXT" --no-headers | awk '{print $3}')
SERVER=$(kubectl config view -o jsonpath="{.clusters[?(@.name=='$CLUSTER_NAME')].cluster.server}")
CA_DATA=$(kubectl config view --raw -o jsonpath="{.clusters[?(@.name=='$CLUSTER_NAME')].cluster.certificate-authority-data}")

# Extract the non-expiring token from the secret
TOKEN=$(kubectl get secret "$SECRET_NAME" --namespace "$NAMESPACE" -o jsonpath='{.data.token}' | base64 --decode)

# Assemble the kubeconfig file
cat <<EOF > sa-kubeconfig.yaml
apiVersion: v1
kind: Config
current-context: ${SERVICE_ACCOUNT_NAME}-context
clusters:
- name: ${CLUSTER_NAME}
  cluster:
    server: ${SERVER}
    certificate-authority-data: ${CA_DATA}
contexts:
- name: ${SERVICE_ACCOUNT_NAME}-context
  context:
    cluster: ${CLUSTER_NAME}
    user: ${SERVICE_ACCOUNT_NAME}
    namespace: ${NAMESPACE}
users:
- name: ${SERVICE_ACCOUNT_NAME}
  user:
    token: ${TOKEN}
EOF

echo "🚀 Kubeconfig file 'sa-kubeconfig.yaml' created successfully!"s