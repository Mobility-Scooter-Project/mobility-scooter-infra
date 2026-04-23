variable "PROJECT_ID" {
  description = "The OpenStack project ID where resources will be created."
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "The Magnum cluster name."
  type        = string
  default     = "msp-cluster-prod"
}

variable "cluster_template_name" {
  description = "The Magnum cluster template name."
  type        = string
  default     = "msp-k8s-v1-30"
}

variable "cluster_keypair_name" {
  description = "The pre-existing OpenStack keypair name Magnum should use."
  type        = string
}

variable "cluster_image_name" {
  description = "The Glance image name used for Magnum nodes."
  type        = string
  default     = "ubuntu-jammy-kube-v1.30.4-240828-1653"
}

variable "external_network_name" {
  description = "The external network name used for floating IPs and load balancers."
  type        = string
  default     = "public"
}

variable "fixed_network_name" {
  description = "The tenant network Magnum should attach cluster nodes to."
  type        = string
  default     = "auto_allocated_network"
}

variable "dns_nameserver" {
  description = "DNS nameserver handed to the Magnum cluster template."
  type        = string
  default     = "8.8.8.8"
}

variable "master_count" {
  description = "The number of control plane nodes."
  type        = number
  default     = 1
}

variable "node_count" {
  description = "The number of worker nodes."
  type        = number
  default     = 1
}

variable "master_flavor" {
  description = "The flavor to use for the control plane nodes."
  type        = string
  default     = "m3.small"
}

variable "node_flavor" {
  description = "The flavor to use for the worker nodes."
  type        = string
  default     = "m3.medium"
}

variable "docker_volume_size" {
  description = "Per-node Cinder volume size for container storage in GB."
  type        = number
  default     = 20
}

variable "docker_volume_type" {
  description = "Optional Cinder volume type for Magnum docker volumes."
  type        = string
  default     = ""
}

variable "boot_volume_size" {
  description = "Optional boot volume size override for Magnum nodes."
  type        = number
  default     = 0
}

variable "boot_volume_type" {
  description = "Optional boot volume type override for Magnum nodes."
  type        = string
  default     = ""
}

variable "etcd_volume_size" {
  description = "Optional etcd volume size for Magnum masters."
  type        = number
  default     = 0
}

variable "etcd_volume_type" {
  description = "Optional etcd volume type override for Magnum masters."
  type        = string
  default     = ""
}

variable "network_driver" {
  description = "The Magnum network driver."
  type        = string
  default     = "calico"
}

variable "volume_driver" {
  description = "The Magnum volume driver."
  type        = string
  default     = "cinder"
}

variable "docker_storage_driver" {
  description = "The container runtime storage driver."
  type        = string
  default     = "overlay2"
}

variable "kube_tag" {
  description = "The Kubernetes version tag Magnum should bootstrap."
  type        = string
  default     = "v1.30.4"
}

variable "floating_ip_enabled" {
  description = "Whether Magnum should attach a floating IP to the API endpoint."
  type        = bool
  default     = true
}

variable "master_lb_enabled" {
  description = "Whether Magnum should create a load balancer for the control plane."
  type        = bool
  default     = true
}

variable "create_timeout_minutes" {
  description = "How long Terraform should wait for Magnum cluster creation."
  type        = number
  default     = 60
}

variable "monitoring_enabled" {
  description = "Whether Magnum should enable built-in monitoring."
  type        = bool
  default     = false
}

variable "influx_grafana_dashboard_enabled" {
  description = "Whether Magnum should enable the legacy InfluxDB/Grafana dashboard."
  type        = bool
  default     = false
}

variable "cloud_provider_enabled" {
  description = "Whether Magnum should enable the external OpenStack cloud provider."
  type        = bool
  default     = true
}

variable "cinder_csi_enabled" {
  description = "Whether Magnum should enable the out-of-tree Cinder CSI driver."
  type        = bool
  default     = true
}

variable "auto_healing_enabled" {
  description = "Whether Magnum should enable health monitoring and remediation."
  type        = bool
  default     = false
}

variable "nova_availability_zone" {
  description = "The Nova availability zone the cluster nodes must use."
  type        = string
}

variable "cinder_availability_zone" {
  description = "The Cinder availability zone validated for node-attached volumes."
  type        = string
}
