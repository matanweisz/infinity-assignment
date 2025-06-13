variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_name" {
  description = "Name tag for the VPC"
  type        = string
  default     = "CustomVPC"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability Zone for the subnet"
  type        = string
  default     = "eu-central-1a"
}

variable "subnet_name" {
  description = "Name tag for the subnet"
  type        = string
  default     = "CustomSubnet"
}


variable "public_subnet_1_cidr" {
  description = "CIDR block for the first public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for the second public subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone_1" {
  description = "Availability Zone for the first public subnet"
  type        = string
  default     = "eu-central-1a"
}

variable "availability_zone_2" {
  description = "Availability Zone for the second public subnet"
  type        = string
  default     = "eu-central-1b"
}

variable "igw_name" {
  description = "Name tag for the Internet Gateway"
  type        = string
  default     = "CustomIGW"
}

variable "route_table_name" {
  description = "Name tag for the Route Table"
  type        = string
  default     = "CustomRouteTable"
}
