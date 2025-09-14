output "infisical_private_key" {
  description = "The Infisical private key"
  value       = module.infisical.private_key
  sensitive   = true
}

output "kubeconfig" {
  value     = module.cluster.kubeconfig
  sensitive = true
}