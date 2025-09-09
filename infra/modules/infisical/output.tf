output "private_key" {
  description = "The Infisical private key"
  value       = openstack_compute_keypair_v2.infisical_keypair.private_key
  sensitive   = true
}