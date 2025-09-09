variable "cluster_template_id" {
  description = "The ID of the Magnum cluster template to use for the cluster"
  type        = string
}

variable "master_count" {
  description = "The number of master nodes to create"
  type        = number
  default     = 1
}

variable "node_count" {
  description = "The number of non-gpu worker nodes to create"
  type        = number
  default     = 1
}

variable "node_flavor" {
  description = "The flavor to use for the worker nodes"
  type        = string
  default     = "m3.medium"
}

variable "master_flavor" {
  description = "The flavor to use for the master nodes"
  type        = string
  default     = "m3.small"
}
