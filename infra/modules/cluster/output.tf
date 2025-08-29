output "kubeconfig" {
  value = openstack_containerinfra_cluster_v1.msp_cluster_prod.kubeconfig.raw_config
  sensitive = true
}