This Terraform module creates an **AWS Virtual Private Cloud (VPC)** with the following components:
- **VPC**
- **Subnet**
- **Internet Gateway**
- **Route Table & Route Table Association**

Folder Structure:

/terraform_project
│── main.tf
│── modules/
│   ├── vpc/
│   │   ├── main.tf        # Main Terraform configuration for VPC
│   │   ├── variables.tf   # Input variables for customization
│   │   ├── outputs.tf     # Outputs for referencing module values


How to Use the Module:

To use the VPC module in your project, add the following in main.tf:

module "vpc" {
  source            = "./modules/vpc"
  vpc_cidr         = "10.0.0.0/16"
  subnet_cidr      = "10.0.1.0/24"
  availability_zone = "eu-central-1a"
}

This will create a VPC with all the requiered network components in the AZ eu-central-1a.
