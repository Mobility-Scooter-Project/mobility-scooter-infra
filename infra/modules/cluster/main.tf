terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "3.4.0"
    }
  }
}

data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}

data "openstack_compute_keypair_v2" "cluster_keypair" {
  name = var.cluster_keypair_name
}

locals {
  template_labels = merge(
    {
      monitoring_enabled               = tostring(var.monitoring_enabled)
      influx_grafana_dashboard_enabled = tostring(var.influx_grafana_dashboard_enabled)
      cinder_csi_enabled               = tostring(var.cinder_csi_enabled)
      cloud_provider_enabled           = tostring(var.cloud_provider_enabled)
      auto_healing_enabled             = tostring(var.auto_healing_enabled)
      kube_tag                         = var.kube_tag
      availability_zone                = var.nova_availability_zone
    },
    var.docker_volume_type != "" ? { docker_volume_type = var.docker_volume_type } : {},
    var.boot_volume_size > 0 ? { boot_volume_size = tostring(var.boot_volume_size) } : {},
    var.boot_volume_type != "" ? { boot_volume_type = var.boot_volume_type } : {},
    var.etcd_volume_size > 0 ? { etcd_volume_size = tostring(var.etcd_volume_size) } : {},
    var.etcd_volume_type != "" ? { etcd_volume_type = var.etcd_volume_type } : {}
  )
}

resource "openstack_containerinfra_clustertemplate_v1" "msp_cluster_template" {
  name                  = var.cluster_template_name
  image                 = var.cluster_image_name
  coe                   = "kubernetes"
  external_network_id   = data.openstack_networking_network_v2.external.id
  dns_nameserver        = var.dns_nameserver
  master_flavor         = var.master_flavor
  flavor                = var.node_flavor
  docker_volume_size    = var.docker_volume_size
  network_driver        = var.network_driver
  volume_driver         = var.volume_driver
  docker_storage_driver = var.docker_storage_driver
  floating_ip_enabled   = var.floating_ip_enabled
  master_lb_enabled     = var.master_lb_enabled
  labels                = local.template_labels
}

resource "openstack_containerinfra_cluster_v1" "msp_cluster_prod" {
  name                = var.cluster_name
  cluster_template_id = openstack_containerinfra_clustertemplate_v1.msp_cluster_template.id
  keypair             = data.openstack_compute_keypair_v2.cluster_keypair.name
  fixed_network       = var.fixed_network_name

  master_count  = var.master_count
  node_count    = var.node_count
  flavor        = var.node_flavor
  master_flavor = var.master_flavor

  floating_ip_enabled = var.floating_ip_enabled
  master_lb_enabled   = var.master_lb_enabled
  create_timeout      = var.create_timeout_minutes

  merge_labels = true
  labels = {
    availability_zone = var.nova_availability_zone
  }

  lifecycle {
    precondition {
      condition     = var.nova_availability_zone == var.cinder_availability_zone
      error_message = "Jetstream Magnum provisioning requires matching Nova and Cinder availability zones to avoid volume attach timeouts."
    }
  }
}
