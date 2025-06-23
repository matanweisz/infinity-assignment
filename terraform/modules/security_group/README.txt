This Terraform module creates an AWS Security Group with configurable ingress and egress rules.
It provides a flexible way to define security rules dynamically, ensuring reusability, security, and modularity.

Folder Structure:

/terraform_project
│── main.tf
│── modules/
│   ├── security_group/
│   │   ├── main.tf        # Security group resource
│   │   ├── variables.tf   # Input variables for customization
│   │   ├── outputs.tf     # Outputs for referencing module values


How to Use the Module:

# Call the Module in Your 'main.tf' File
Add the following to your Terraform configuration:

module "security_group" {
  source  = "./modules/security_group"
  sg_name = "MyApp-SG"
  vpc_id  = module.vpc.vpc_id

  ingress_rules = [
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { from_port = 5000, to_port = 5000, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }  #Example
  ]

  extra_tags = {
    Environment = "Production"
    Owner       = "DevOps Team"
  }
}


# Input Variables
You can customize this module by providing different values for the variables below.

| **Variable**      | **Description**                           | **Type**  | **Default** |
|------------------|-------------------------------------------|---------|------------|
| `sg_name`       | Security Group Name                       | `string` | `"Managed SG"` |
| `sg_description` | Security Group Description               | `string` | `"Managed Security Group"` |
| `vpc_id`        | ID of the VPC to associate the SG with    | `string` | _Required_ |
| `ingress_rules` | List of ingress rules (ports, protocols, CIDR) | `list(object)` | _See Default Below_ |
| `egress_rules`  | List of egress rules (outbound traffic)   | `list(object)` | _See Default Below_ |
| `extra_tags`    | Additional tags for the SG                | `map(string)` | `{}` |


# Default Ingress Rules
By default, the module allows the following inbound traffic:

ingress_rules = [
  { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
  { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
  { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
]


# Default Egress Rules
All outbound traffic is allowed by default:

egress_rules = [
  { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
]


# Outputs
Once the module is applied, you can reference the created Security Group ID using:

| **Output Name**      | **Description**                       |
|---------------------|----------------------------------|
| `security_group_id` | ID of the created security group |

Example usage in another module:

resource "aws_instance" "example" {
  ami                    = "ami-0b74f796d330ab49c"
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.subnet_id
  vpc_security_group_ids = [module.security_group.security_group_id]
}
