variable "image_id" {
  description = "The ID of the image to use for the instance."
  type        = string
}

variable "flavor_name" {
  description = "The ID of the flavor to use for the instance."
  type        = string
  default     = "m3.small"
}

variable "dns_zone_name" {
  description = "The name of the DNS zone to create the record in."
  type        = string
}

variable "project_id" {
  description = "The OpenStack project ID where resources will be created"
  type        = string

}

variable "subdomain" {
  description = "The subdomain to create the DNS record for."
  type        = string
}
