variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where EKS will be created"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets (usually public) for the EKS cluster"
}

variable "key_name" {
  description = "SSH key pair name to attach to the worker nodes"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts (IRSA)"
  type        = bool
  default     = true
}

variable "cluster_addons" {
  description = "Map of EKS addons"
  type        = any
  default     = {}
}

variable "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.32"
}
