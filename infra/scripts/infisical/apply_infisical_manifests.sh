export KUBECONFIG=infisical-kubeconfig.yaml

# install argo
kubectl apply -k cluster/bootstrap --server-side

# install helm charts
kubectl apply -f cluster/helm/cert-manager.yaml --server-side

# this contains the .env file with our OS credentials
kubectl apply -f cluster/helm/external-secrets.yaml --server-side
kubectl apply -f cluster/helm/clustersecret.yaml --server-side
kubectl apply -k cluster/base/external-secrets --server-side
kubectl apply -k cluster/base/cert-manager --server-side
kubectl apply -f cluster/helm/designate-certmanager-webhook.yaml --server-side