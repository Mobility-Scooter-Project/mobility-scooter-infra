terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "3.3.2"
    }
  }
}

resource "openstack_compute_keypair_v2" "infisical_keypair" {
  name = "infisical-keypair"
}

resource "openstack_networking_floatingip_v2" "infisical_fip" {
  pool = "public"
}

data "openstack_networking_network_v2" "public_network" {
  name = "public"
}

data "openstack_networking_port_v2" "infisical_port" {
  device_id = openstack_compute_instance_v2.infisical.id
}

resource "openstack_compute_instance_v2" "infisical" {
  name     = "infisical"
  key_pair = openstack_compute_keypair_v2.infisical_keypair.name

  image_id    = var.image_id
  flavor_name = var.flavor_name

  security_groups = ["ssh-security-group"]

  network {
    name = "auto_allocated_network"
  }
}

resource "openstack_networking_floatingip_associate_v2" "infisical_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.infisical_fip.address
  port_id     = data.openstack_networking_port_v2.infisical_port.id
}

data "openstack_dns_zone_v2" "infisical_zone" {
  name       = var.dns_zone_name
  project_id = var.project_id
}

resource "openstack_dns_recordset_v2" "infisical_dns" {
  zone_id = data.openstack_dns_zone_v2.infisical_zone.id
  name    = "${var.subdomain}.${data.openstack_dns_zone_v2.infisical_zone.name}"
  type    = "A"
  ttl     = 300

  records = [openstack_networking_floatingip_v2.infisical_fip.address]
}

resource "openstack_blockstorage_volume_v3" "infisical_volume" {
  region      = "IU"
  name        = "infisical-volume"
  description = "Volume for Infisical instance"
  size        = var.volume_size
}

resource "openstack_compute_volume_attach_v2" "infisical_volume_attach" {
  instance_id = openstack_compute_instance_v2.infisical.id
  volume_id   = openstack_blockstorage_volume_v3.infisical_volume.id
}
