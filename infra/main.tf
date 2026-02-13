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

# EVIL ASS CLUSTER
# cluster template is defined in ./modules/cluster
module "cluster" {
  source              = "./modules/cluster"
  cluster_template_id = "2d56f33a-713c-488a-b65f-47b625d832cd"
  master_flavor       = "m3.small"
  node_flavor         = "m3.medium"
  node_count          = 2
}
