# Define required providers
terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
      version = "3.4.0"
    }
  }

  backend "s3" {
    bucket    = "msp-config"
    key       = "terraform.tfstate"
    region    = "IU"
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

# AUTHENTICATION: Points to your clouds.yaml profile
provider "openstack" {
  cloud = "openstack" 
}

/*
# IMAGE DATA SOURCE: The OpenStack equivalent of data "aws_ami"
data "openstack_images_image_v2" "ubuntu" {
  name        = "Featured-Ubuntu22"
  most_recent = true
}
*/

/* FOR TESTING
# succeeds on apply
resource "openstack_compute_instance_v2" "master_canary" {
  name            = "master-canary-test"
  image_name      = "ubuntu-jammy-kube-v1.33.2-250626-0848"
  flavor_name     = "m3.small"
  key_pair        = "msp-keypair"
  security_groups = ["default"]

  network {
    name = "auto_allocated_network"
  }
}
*/


# CLUSTER TESTING, imported from /modules/cluster

# CLUSTER TEMPLATE

data "openstack_networking_network_v2" "public_net" {
  name = "public"
}

resource "openstack_containerinfra_clustertemplate_v1" "lightweight_k8s_v130" {
  name                  = "lightweight-k8s-v1.30-stable"
  
  image                 = "ubuntu-jammy-kube-v1.30.4-240828-1653"
  
  coe                   = "kubernetes"
  flavor                = "m3.quad"
  master_flavor         = "m3.quad"

  external_network_id   = data.openstack_networking_network_v2.public_net.id
  
  dns_nameserver        = "8.8.8.8"
  docker_volume_size    = 20              # 20GB disk per node (saves space)
  network_driver        = "calico"        # Standard for JS2
  volume_driver         = "cinder"        # Allows Persistent Volumes
  docker_storage_driver = "overlay2"
  
  # NETWORK FIX: Prevents "Port Not Ready" race conditions
  master_lb_enabled     = true 
  floating_ip_enabled   = false

  labels = {
    # VERSION FIX: Prevents "Container Runtime" crash
    # Must match the version in your 'image' name exactly
    kube_tag = "v1.30.4" 
    
    # PERFORMANCE FIX: Saves RAM for the actual workload
    kube_dashboard_enabled           = "true"
    prometheus_monitoring            = "false"
    influx_grafana_dashboard_enabled = "false"
    auto_healing_enabled             = "true"
    cinder_csi_enabled               = "true"
  }
}



# ROLLS THE CLUSTER

# Fetch the existing keypair from the cloud
data "openstack_compute_keypair_v2" "msp_keypair" {
  name = "msp-keypair"
}

# The Cluster Resource
resource "openstack_containerinfra_cluster_v1" "msp_cluster_prod" {
  name                = "msp-cluster-prod"
  cluster_template_id = openstack_containerinfra_clustertemplate_v1.lightweight_k8s_v130.id
  keypair             = data.openstack_compute_keypair_v2.msp_keypair.name
  
  master_count        = 1
  node_count          = 2
  
  # throws error if configuration takes longer than 60 minutes
  create_timeout      = 60
}





/*
# EVIL ASS CLUSTER
module "cluster" {
  source              = "./modules/cluster" 
  cluster_template_id = "ff32fc8d-23de-417f-b6cc-5f03f2aa6628"
  node_flavor         = "m3.medium"
  node_count          = 0
  master_flavor       = "m3.small"
}
*/