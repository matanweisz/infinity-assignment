variable "ami" {
  description = "AMI ID for Ubuntu"
  type        = string
  default     = "ami-03250b0e01c28d196" # Ubuntu AMI (Change if needed)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "subnet_id" {
  description = "Subnet ID for the instance"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for the instance"
  type        = string
}

variable "key_name" {
  description = "SSH Key Pair name"
  type        = string
  default     = "terraform_key_pair"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "Ubuntu-Instance"
}

variable "volume_type" {
  type    = string
  default = "gp3"
}

variable "volume_size" {
  type    = string
  default = "8"
}

variable "extra_tags" {
  description = "Additional tags for the instance"
  type        = map(string)
  default     = {}
}
