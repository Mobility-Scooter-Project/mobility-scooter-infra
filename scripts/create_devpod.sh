export KUBECONFIG=/home/bryan/projects/cpp/msp/mobility-scooter-infra/kubeconfig.yaml

devpod provider add kubernetes \
    -o CLUSTER_ROLE=devpod-role \
    -o INACTIVITY_TIMEOUT=30m \
    -o KUBERNETES_CONFIG=$KUBECONFIG \
    -o SERVICE_ACCOUNT=devpod-sa \
    -o STORAGE_CLASS=default