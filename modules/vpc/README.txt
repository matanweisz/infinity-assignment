This Terraform module creates an **AWS Virtual Private Cloud (VPC)** with the following components:
- **VPC**
- **Subnet**
- **Internet Gateway**
- **Route Table & Route Table Association**

This module is designed for reusability, so you can integrate it into different projects by simply copying the modules/vpc folder.

Folder Structure:

/terraform_project
│── main.tf
│── modules/
│   ├── vpc/
│   │   ├── main.tf        # Main Terraform configuration for VPC
│   │   ├── variables.tf   # Input variables for customization
│   │   ├── outputs.tf     # Outputs for referencing module values
│── README.txt


How to Use the Module:

1. Call the Module in Your main.tf File

To use the VPC module in your project, add the following in main.tf:

module "vpc" {
  source            = "./modules/vpc"
  vpc_cidr         = "10.0.0.0/16"
  subnet_cidr      = "10.0.1.0/24"
  availability_zone = "eu-central-1a"
}

This will create a VPC with a subnet in eu-central-1a.


2. Available Input Variables

You can customize this module by providing different values for the variables below.

| **Variable**        | **Description**                           | **Type**   | **Default**   |
|--------------------|-------------------------------------------|----------|------------------|
| `vpc_cidr`        | CIDR block for the VPC                    | `string`  | `"10.0.0.0/16"`  |
| `vpc_name`        | Name of the VPC                           | `string`  | `"CustomVPC"`    |
| `subnet_cidr`     | CIDR block for the subnet                 | `string`  | `"10.0.1.0/24"`  |
| `availability_zone`| Availability Zone for the subnet         | `string`  | `"eu-central-1a"`|
| `subnet_name`     | Name of the subnet                        | `string`  | `"CustomSubnet"` |
| `igw_name`        | Name of the Internet Gateway              | `string`  | `"CustomIGW"`    |
| `route_table_name`| Name of the Route Table                   | `string`  | `"CustomRouteTable"`|


3. Outputs

Once the module is applied, you can reference the created **VPC components** using these outputs.

| **Output Name** | **Description**            |
|---------------|------------------------------|
| `vpc_id`     | ID of the created VPC         |
| `subnet_id`  | ID of the created Subnet      |
| `igw_id`     | ID of the Internet Gateway    |


Example usage in another module:

resource "aws_instance" "example" {
  ami                    = "ami-0b74f796d330ab49c"
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.subnet_id
}
