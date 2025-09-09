terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "3.3.2"
    }
  }
}

# https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/data-sources/compute_keypair_v2
resource "openstack_compute_keypair_v2" "msp_keypair" {
  name = "msp-keypair"
}

# https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/containerinfra_cluster_v1
resource "openstack_containerinfra_cluster_v1" "msp_cluster_prod" {
  name                = "msp-cluster-prod"
  cluster_template_id = var.cluster_template_id
  keypair             = openstack_compute_keypair_v2.msp_keypair.name
  master_count        = 1
  node_count          = 1
  flavor              = var.node_flavor
  master_flavor       = var.master_flavor
  floating_ip_enabled = true
  master_lb_enabled   = true
  # https://docs.openstack.org/magnum/latest/user/#labels
  merge_labels = true
  labels = {
    influx_grafana_dashboard_enabled = "true"
    boot_volume_size                 = "60"
    cloud_provider_enabled           = "true"
  }
}

# commented out for now to save SU as they are a separate pool from regular vCPU and RAM
#resource "openstack_containerinfra_nodegroup_v1" "gpu_nodegroup" {
#name       = "gpu-nodegroup"
#cluster_id = openstack_containerinfra_cluster_v1.msp_cluster_prod.id
#node_count = 1
#flavor_id     = "g3.medium"
#image_id   = "74846576-bb7e-4ca9-897e-8f33e8fd84d1"
# NOTE: this did not actually end up working, so I manually set the volume size in the OpenStack dashboard to 100GB
#docker_volume_size = 100
#labels    = {
#boot_volume_size = "60"
#}
#}
