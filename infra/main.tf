terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "3.3.2"
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
  cloud = "clouds.yaml"
}
