# Define required providers
terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

# Fetch the existing keypair from the cloud
data "openstack_compute_keypair_v2" "msp_keypair" {
  name = "msp-keypair"
}

# The Cluster Resource
resource "openstack_containerinfra_cluster_v1" "msp_cluster_prod" {
  name                = "msp-cluster-prod"
  cluster_template_id = var.cluster_template_id
  keypair             = data.openstack_compute_keypair_v2.msp_keypair.name
  
  master_count        = var.master_count
  node_count          = var.node_count
  flavor              = var.node_flavor
  master_flavor       = var.master_flavor

  # This is the "safe" way to handle networking on Jetstream2
  fixed_network       = "auto_allocated_network"
  
  # Merges your manual labels with the ones baked into the template
  merge_labels = true

  labels = {
    # These are passed as strings to the Heat orchestration engine
    "floating_ip_enabled"              = "true"
    "master_lb_enabled"                = "true"
    "cloud_provider_enabled"           = "true"
    "influx_grafana_dashboard_enabled" = "true"
    "monitoring_enabled"               = "true"
    "auto_healing_enabled"             = "true"
  }
}