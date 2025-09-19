#!/bin/bash

# Script to generate admin kubeconfig from the revocable admin ServiceAccount
# This kubeconfig will have the same permissions as cluster-admin but can be revoked
#
# SECURITY: This script requires cluster-admin (root kubeconfig) permissions to run.
# The revocable admin user cannot regenerate their own credentials for security reasons.

set -e

NAMESPACE="kube-system"
SERVICE_ACCOUNT="admin-user"
CONTEXT_NAME="admin-context"
KUBECONFIG_FILE="admin-kubeconfig.yaml"

echo "Generating admin kubeconfig..."

# Security check: Ensure only root/cluster-admin can run this script
echo "Verifying root/cluster-admin permissions..."

# Check if the current user is the admin ServiceAccount (block self-regeneration)
CURRENT_USER=$(kubectl auth whoami 2>/dev/null || echo "unknown")
if echo "$CURRENT_USER" | grep -q "system:serviceaccount:kube-system:admin-user"; then
    echo "ERROR: The admin ServiceAccount cannot regenerate its own credentials."
    echo "   This is a security measure to prevent privilege escalation."
    echo "   Please run this script with your root kubeconfig, not the admin kubeconfig."
    exit 1
fi

# Check if we can identify the current context as the admin context
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "unknown")
if [ "$CURRENT_CONTEXT" = "admin-context" ]; then
    echo "ERROR: Currently using admin-context. Cannot regenerate own credentials."
    echo "   Please switch to your root kubeconfig first."
    exit 1
fi



if ! kubectl auth can-i "*" "*" --all-namespaces >/dev/null 2>&1; then
    echo "ERROR: This script requires cluster-admin (root kubeconfig) permissions."
    echo "   The revocable admin user cannot regenerate their own credentials."
    echo "   Please run this script with your root kubeconfig."
    exit 1
fi

echo "Root permissions verified."

# Get the current cluster info
CURRENT_CONTEXT=$(kubectl config current-context)
CLUSTER_NAME=$(kubectl config view --minify --output 'jsonpath={.clusters[0].name}')
SERVER=$(kubectl config view --minify --output 'jsonpath={.clusters[0].cluster.server}')

echo "Current context: $CURRENT_CONTEXT"
echo "Cluster: $CLUSTER_NAME"
echo "Server: $SERVER"

# Check if ServiceAccount exists
echo "Verifying ServiceAccount exists..."
if ! kubectl get serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE >/dev/null 2>&1; then
    echo "ERROR: ServiceAccount $SERVICE_ACCOUNT not found in namespace $NAMESPACE"
    echo "Please deploy the RBAC resources first: kubectl apply -k cluster/base/rbac/"
    exit 1
fi

# Create token using modern approach (works with Kubernetes 1.22+)
echo "Creating ServiceAccount token..."
TOKEN=$(kubectl create token $SERVICE_ACCOUNT -n $NAMESPACE --duration=8760h)

# Get cluster CA certificate
CERTIFICATE=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

if [ -z "$TOKEN" ]; then
    echo "Failed to create token for ServiceAccount $SERVICE_ACCOUNT"
    exit 1
fi

if [ -z "$CERTIFICATE" ]; then
    echo "Failed to get cluster certificate authority data"
    exit 1
fi

# Create the kubeconfig
cat > $KUBECONFIG_FILE << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $CERTIFICATE
    server: $SERVER
  name: $CLUSTER_NAME
contexts:
- context:
    cluster: $CLUSTER_NAME
    user: $SERVICE_ACCOUNT
  name: $CONTEXT_NAME
current-context: $CONTEXT_NAME
users:
- name: $SERVICE_ACCOUNT
  user:
    token: $TOKEN
EOF

echo "Admin kubeconfig generated: $KUBECONFIG_FILE"
echo ""
echo "Usage:"
echo "  export KUBECONFIG=$PWD/$KUBECONFIG_FILE"
echo "  kubectl get nodes"
echo ""
echo "Security notes:"
echo "  - This kubeconfig has cluster-admin equivalent permissions"
echo "  - It can be revoked by deleting the ServiceAccount or ClusterRoleBinding"
echo "  - Token expires after 1 year (8760 hours) from generation"
echo "  - Store this file securely and rotate tokens regularly"
echo ""
echo "To revoke access:"
echo "  kubectl delete serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE"
echo "  kubectl delete clusterrolebinding admin-user-binding"
echo ""
echo "To regenerate token (must be run with root kubeconfig):"
echo "  ./cluster/scripts/generate-admin-kubeconfig.sh"