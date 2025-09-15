output "kubeconfig" {
  value     = openstack_containerinfra_cluster_v1.msp_cluster_prod.kubeconfig.raw_config
  sensitive = true
}

output "cluster_keypair" {
  description = "The cluster keypair"
  value       = openstack_compute_keypair_v2.msp_keypair.private_key
  sensitive   = true
}
