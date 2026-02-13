variable "cluster_template_id" {
  type        = string
  description = "The ID of the Magnum cluster template"
}

variable "node_flavor" {
  type        = string
  description = "Flavor for worker nodes"
}

variable "node_count" {
  type        = number
  description = "Number of worker nodes"
}

variable "master_flavor" {
  type        = string
  description = "Flavor for master nodes"
}

variable "master_count" {
  type        = number
  default     = 1
  description = "Number of master nodes"
}