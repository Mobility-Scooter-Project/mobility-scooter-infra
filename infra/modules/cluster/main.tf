terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "3.3.2"
    }
  }
}

resource "openstack_containerinfra_cluster_v1" "msp_cluster_prod" {
  name                = "msp-cluster-prod"
  cluster_template_id = "e16df0b2-5cc0-480a-b64e-1489962545bd"
  master_count        = 1
  node_count          = 1
  flavor              = "m3.medium"
  master_flavor       = "m3.small"
  floating_ip_enabled = true
  master_lb_enabled   = true
  # https://docs.openstack.org/magnum/latest/user/#labels
  labels = {
    influx_grafana_dashboard_enabled = "true"
    boot_volume_zie                  = "50"
    cloud_provider_enabled           = "true"
  }
}

resource "openstack_containerinfra_nodegroup_v1" "gpu_nodegroup" {
  name       = "gpu-nodegroup"
  cluster_id = openstack_containerinfra_cluster_v1.msp_cluster_prod.id
  node_count = 1
  flavor_id     = "g3.medium"
  image_id   = "74846576-bb7e-4ca9-897e-8f33e8fd84d1"
  labels    = {
    boot_volume_size = "50"
  }
}
