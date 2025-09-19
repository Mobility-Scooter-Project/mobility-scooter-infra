output "infisical_private_key" {
  description = "The Infisical private key"
  value       = module.infisical.private_key
  sensitive   = true
}

output "kubeconfig" {
  value     = module.cluster.kubeconfig
  sensitive = true
}

output "cluster_keypair" {
  description = "The cluster keypair"
  value       = module.cluster.cluster_keypair
  sensitive   = true
}