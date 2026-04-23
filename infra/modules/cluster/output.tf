output "kubeconfig" {
  description = "Raw kubeconfig returned by Magnum for the cluster."
  value       = openstack_containerinfra_cluster_v1.msp_cluster_prod.kubeconfig.raw_config
  sensitive   = true
}
