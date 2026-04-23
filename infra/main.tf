terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "3.4.0"
    }
  }

  backend "s3" {
    bucket = "msp-config"
    key    = "terraform.tfstate"
    region = "IU"
    endpoints = {
      s3 = "https://js2.jetstream-cloud.org:8001"
    }
    skip_requesting_account_id  = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}

provider "openstack" {
  cloud = "openstack"
}

/*
module "infisical" {
  source        = "./modules/infisical"
  image_id      = "91fcfdd3-16c8-4cac-aaae-d7029317c77c" # Featured-Ubuntu24
  flavor_name   = "m3.small"
  dns_zone_name = "cis240470.projects.jetstream-cloud.org."
  project_id    = var.PROJECT_ID
  subdomain     = "infisical"
}
*/

module "cluster" {
  source                           = "./modules/cluster"
  cluster_name                     = var.cluster_name
  cluster_template_name            = var.cluster_template_name
  cluster_keypair_name             = var.cluster_keypair_name
  cluster_image_name               = var.cluster_image_name
  external_network_name            = var.external_network_name
  fixed_network_name               = var.fixed_network_name
  dns_nameserver                   = var.dns_nameserver
  master_count                     = var.master_count
  node_count                       = var.node_count
  master_flavor                    = var.master_flavor
  node_flavor                      = var.node_flavor
  docker_volume_size               = var.docker_volume_size
  docker_volume_type               = var.docker_volume_type
  boot_volume_size                 = var.boot_volume_size
  boot_volume_type                 = var.boot_volume_type
  etcd_volume_size                 = var.etcd_volume_size
  etcd_volume_type                 = var.etcd_volume_type
  network_driver                   = var.network_driver
  volume_driver                    = var.volume_driver
  docker_storage_driver            = var.docker_storage_driver
  kube_tag                         = var.kube_tag
  floating_ip_enabled              = var.floating_ip_enabled
  master_lb_enabled                = var.master_lb_enabled
  create_timeout_minutes           = var.create_timeout_minutes
  monitoring_enabled               = var.monitoring_enabled
  influx_grafana_dashboard_enabled = var.influx_grafana_dashboard_enabled
  cloud_provider_enabled           = var.cloud_provider_enabled
  cinder_csi_enabled               = var.cinder_csi_enabled
  auto_healing_enabled             = var.auto_healing_enabled
  nova_availability_zone           = var.nova_availability_zone
  cinder_availability_zone         = var.cinder_availability_zone
}
