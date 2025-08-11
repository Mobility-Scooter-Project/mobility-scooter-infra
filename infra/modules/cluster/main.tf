terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "3.3.2"
    }
  }
}

resource "openstack_containerinfra_cluster_v1" "msp_cluster_prod" {
    name = "msp-cluster-prod"
    cluster_template_id = "e16df0b2-5cc0-480a-b64e-1489962545bd"
    master_count = 1
    node_count = 1
    flavor = "m3.medium"
    master_flavor = "m3.small"
    floating_ip_enabled = true
    master_lb_enabled = true
    # https://docs.openstack.org/magnum/latest/user/#labels
    labels = {
        influx_grafana_dashboard_enabled = "true"
        boot_volume_zie = "50"
        cloud_provider_enabled = "true"
    }
}