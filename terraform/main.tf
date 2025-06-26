# =============================================================================
# TERRAFORM CONFIGURATION
# =============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "eu-central-1"
  profile = "default"
}

# =============================================================================
# VARIABLES
# =============================================================================

locals {
  # Domain configuration
  gitlab_domain   = "gitlab.matanweisz.xyz"
  registry_domain = "registry.matanweisz.xyz"
  vault_domain    = "vault.matanweisz.xyz"

  # Project configuration
  project_name = "infinity-assignment"

  # Bastion host toggle - set to false to disable
  enable_bastion = true

  # SSH key pair name (must exist in AWS)
  key_pair_name = "terraform_key_pair"

  # AMI ID for Ubuntu 24.04 LTS
  ami_id = "ami-014dd8ec7f09293e6"
}

# =============================================================================
# DATA SOURCES
# =============================================================================

# Get existing Route53 hosted zone
data "aws_route53_zone" "main" {
  name         = "matanweisz.xyz"
  private_zone = false
}

# Get ACM certificate
data "aws_acm_certificate" "wildcard_cert" {
  domain      = "matanweisz.xyz"
  statuses    = ["ISSUED"]
  most_recent = true
  types       = ["AMAZON_ISSUED"]
}

# =============================================================================
# VPC AND NETWORKING
# =============================================================================

module "vpc" {
  source              = "./modules/vpc"
  vpc_cidr            = "10.0.0.0/16"
  vpc_name            = "${local.project_name}-vpc"
  availability_zone_1 = "eu-central-1a"
  availability_zone_2 = "eu-central-1b"
}

# =============================================================================
# SECURITY GROUPS
# =============================================================================

# ALB Security Group
module "security_group_alb" {
  source  = "./modules/security_group"
  sg_name = "${local.project_name}-alb-sg"
  vpc_id  = module.vpc.vpc_id
  ingress_rules = [
    { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
  ]
}

# GitLab Security Group
module "security_group_gitlab" {
  source        = "./modules/security_group"
  sg_name       = "${local.project_name}-gitlab-sg"
  vpc_id        = module.vpc.vpc_id
  ingress_rules = []
}

# Vault Security Group
module "security_group_vault" {
  source        = "./modules/security_group"
  sg_name       = "${local.project_name}-vault-sg"
  vpc_id        = module.vpc.vpc_id
  ingress_rules = []
}

# Bastion Security Group
module "security_group_bastion" {
  count = local.enable_bastion ? 1 : 0

  source  = "./modules/security_group"
  sg_name = "${local.project_name}-bastion-sg"
  vpc_id  = module.vpc.vpc_id
  ingress_rules = [
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
  ]
}

# EKS Security Group for additional rules
resource "aws_security_group" "eks_additional" {
  name_prefix = "${local.project_name}-eks-additional"
  vpc_id      = module.vpc.vpc_id
  description = "Additional security group for EKS cluster communication"

  tags = {
    Name = "${local.project_name}-eks-additional"
  }
}

# =============================================================================
# SECURITY GROUP RULES - ALB TO SERVICES
# =============================================================================

# ALB to GitLab web
resource "aws_security_group_rule" "alb_to_gitlab_web" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = module.security_group_gitlab.security_group_id
  source_security_group_id = module.security_group_alb.security_group_id
}

# ALB to GitLab container registry
resource "aws_security_group_rule" "alb_to_gitlab_registry" {
  type                     = "ingress"
  from_port                = 5050
  to_port                  = 5050
  protocol                 = "tcp"
  security_group_id        = module.security_group_gitlab.security_group_id
  source_security_group_id = module.security_group_alb.security_group_id
}

# ALB to Vault
resource "aws_security_group_rule" "alb_to_vault" {
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  security_group_id        = module.security_group_vault.security_group_id
  source_security_group_id = module.security_group_alb.security_group_id
}

# =============================================================================
# SECURITY GROUP RULES - EKS TO SERVICES
# =============================================================================

# EKS clusters to GitLab container registry (for image pulls)
resource "aws_security_group_rule" "eks_to_gitlab_registry" {
  type                     = "ingress"
  from_port                = 5050
  to_port                  = 5050
  protocol                 = "tcp"
  security_group_id        = module.security_group_gitlab.security_group_id
  source_security_group_id = aws_security_group.eks_additional.id
  description              = "Allow EKS clusters to pull from GitLab registry"
}

# EKS clusters to GitLab API (for ArgoCD sync)
resource "aws_security_group_rule" "eks_to_gitlab_api" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = module.security_group_gitlab.security_group_id
  source_security_group_id = aws_security_group.eks_additional.id
  description              = "Allow EKS clusters to access GitLab API"
}

# EKS clusters to Vault API (for secret management)
resource "aws_security_group_rule" "eks_to_vault" {
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  security_group_id        = module.security_group_vault.security_group_id
  source_security_group_id = aws_security_group.eks_additional.id
  description              = "Allow EKS clusters to access Vault API"
}

# =============================================================================
# SECURITY GROUP RULES - BASTION HOST ACCESS
# =============================================================================

# Bastion to GitLab SSH
resource "aws_security_group_rule" "bastion_to_gitlab_ssh" {
  count = local.enable_bastion ? 1 : 0

  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = module.security_group_gitlab.security_group_id
  source_security_group_id = module.security_group_bastion[0].security_group_id
}

# Bastion to Vault SSH
resource "aws_security_group_rule" "bastion_to_vault_ssh" {
  count = local.enable_bastion ? 1 : 0

  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = module.security_group_vault.security_group_id
  source_security_group_id = module.security_group_bastion[0].security_group_id
}

# Bastion to EKS API Server (HTTPS)
resource "aws_security_group_rule" "bastion_to_eks_api" {
  count = local.enable_bastion ? 1 : 0

  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.security_group_bastion[0].security_group_id
  description       = "Allow bastion to access EKS API servers"
}

# =============================================================================
# SECURITY GROUP RULES - OUTBOUND TRAFFIC
# =============================================================================

# GitLab outbound
resource "aws_security_group_rule" "gitlab_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.security_group_gitlab.security_group_id
}

resource "aws_security_group_rule" "gitlab_outbound_dns" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.security_group_gitlab.security_group_id
}

# Vault outbound
resource "aws_security_group_rule" "vault_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.security_group_vault.security_group_id
}

resource "aws_security_group_rule" "vault_outbound_dns" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.security_group_vault.security_group_id
}

# Bastion outbound
resource "aws_security_group_rule" "bastion_outbound" {
  count = local.enable_bastion ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.security_group_bastion[0].security_group_id
}

resource "aws_security_group_rule" "bastion_outbound_dns" {
  count = local.enable_bastion ? 1 : 0

  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.security_group_bastion[0].security_group_id
}

# EKS additional outbound
resource "aws_security_group_rule" "eks_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_additional.id
}

# =============================================================================
# BASTION EKS MANAGEMENT ADDITIONS
# =============================================================================

# IAM Role for Bastion Host to assume for EKS management
resource "aws_iam_role" "bastion_eks_role" {
  count = local.enable_bastion ? 1 : 0

  name = "${local.project_name}-bastion-eks-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.bastion_instance_role[0].arn
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::536697238781:user/matan_infinity"
        }
      }
    ]
  })

  tags = {
    Name = "${local.project_name}-bastion-eks-role"
  }
}

# IAM Policy for EKS cluster management
resource "aws_iam_policy" "bastion_eks_policy" {
  count = local.enable_bastion ? 1 : 0

  name        = "${local.project_name}-bastion-eks-policy"
  description = "Policy for bastion host to manage EKS clusters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeUpdate",
          "eks:ListUpdates"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to bastion EKS role
resource "aws_iam_role_policy_attachment" "bastion_eks_policy_attachment" {
  count = local.enable_bastion ? 1 : 0

  role       = aws_iam_role.bastion_eks_role[0].name
  policy_arn = aws_iam_policy.bastion_eks_policy[0].arn
}

# IAM Instance Role for Bastion Host
resource "aws_iam_role" "bastion_instance_role" {
  count = local.enable_bastion ? 1 : 0

  name = "${local.project_name}-bastion-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.project_name}-bastion-instance-role"
  }
}

# IAM Policy for Bastion Instance (allows assuming EKS role)
resource "aws_iam_policy" "bastion_instance_policy" {
  count = local.enable_bastion ? 1 : 0

  name        = "${local.project_name}-bastion-instance-policy"
  description = "Policy for bastion instance to assume EKS management role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = aws_iam_role.bastion_eks_role[0].arn
      }
    ]
  })
}

# Attach policy to bastion instance role
resource "aws_iam_role_policy_attachment" "bastion_instance_policy_attachment" {
  count = local.enable_bastion ? 1 : 0

  role       = aws_iam_role.bastion_instance_role[0].name
  policy_arn = aws_iam_policy.bastion_instance_policy[0].arn
}

# IAM Instance Profile for Bastion Host
resource "aws_iam_instance_profile" "bastion_profile" {
  count = local.enable_bastion ? 1 : 0

  name = "${local.project_name}-bastion-profile"
  role = aws_iam_role.bastion_instance_role[0].name
}

# =============================================================================
# EKS CLUSTER AUTH CONFIGURATION
# =============================================================================

# Add bastion EKS role to backend cluster auth
resource "aws_eks_access_entry" "bastion_backend_access" {
  count = local.enable_bastion ? 1 : 0

  cluster_name  = module.eks_backend.cluster_name
  principal_arn = aws_iam_role.bastion_eks_role[0].arn
  type          = "STANDARD"

  depends_on = [module.eks_backend]
}

# Associate cluster admin policy with bastion backend access
resource "aws_eks_access_policy_association" "bastion_backend_admin" {
  count = local.enable_bastion ? 1 : 0

  cluster_name  = module.eks_backend.cluster_name
  principal_arn = aws_iam_role.bastion_eks_role[0].arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion_backend_access]
}

# Add bastion EKS role to prod cluster auth
resource "aws_eks_access_entry" "bastion_prod_access" {
  count = local.enable_bastion ? 1 : 0

  cluster_name  = module.eks_prod.cluster_name
  principal_arn = aws_iam_role.bastion_eks_role[0].arn
  type          = "STANDARD"

  depends_on = [module.eks_prod]
}

# Associate cluster admin policy with bastion prod access
resource "aws_eks_access_policy_association" "bastion_prod_admin" {
  count = local.enable_bastion ? 1 : 0

  cluster_name  = module.eks_prod.cluster_name
  principal_arn = aws_iam_role.bastion_eks_role[0].arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion_prod_access]
}

# =============================================================================
# BASTION EC2 INSTANCE
# =============================================================================

resource "aws_instance" "bastion" {
  count = local.enable_bastion ? 1 : 0

  ami                    = local.ami_id
  instance_type          = "t3.medium"
  key_name               = local.key_pair_name
  subnet_id              = element(module.vpc.public_subnet_ids, 0)
  vpc_security_group_ids = [module.security_group_bastion[0].security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile[0].name

  root_block_device {
    volume_type = "gp3"
    volume_size = 15
    encrypted   = true
  }

  tags = {
    Name = "bastion"
  }
}

# =============================================================================
# EKS CLUSTERS
# =============================================================================

# Backend EKS Cluster (ArgoCD + GitLab Runner)
module "eks_backend" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.0"

  cluster_name    = "backend-cluster"
  cluster_version = "1.33"
  subnet_ids      = module.vpc.private_subnet_ids
  vpc_id          = module.vpc.vpc_id

  enable_irsa = true

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false

  # Add additional security group for service communication
  cluster_additional_security_group_ids = [aws_security_group.eks_additional.id]

  eks_managed_node_groups = {
    backend_nodes = {
      instance_types = ["t3.medium"]
      desired_size   = 1
      min_size       = 1
      max_size       = 4

      # Add additional security group to node group
      vpc_security_group_ids = [aws_security_group.eks_additional.id]
    }
  }

  tags = {
    Environment = "backend"
    Project     = local.project_name
    Role        = "ArgoCD-GitLabRunner"
  }
}

# Production EKS Cluster (WebApp only)
module "eks_prod" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.0"

  cluster_name    = "prod-cluster"
  cluster_version = "1.33"
  subnet_ids      = module.vpc.private_subnet_ids
  vpc_id          = module.vpc.vpc_id

  enable_irsa = true

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false

  # Add additional security group for limited service communication
  cluster_additional_security_group_ids = [aws_security_group.eks_additional.id]

  eks_managed_node_groups = {
    prod_nodes = {
      instance_types = ["t3.medium"]
      desired_size   = 1
      min_size       = 1
      max_size       = 3

      # Add additional security group to node group
      vpc_security_group_ids = [aws_security_group.eks_additional.id]
    }
  }

  tags = {
    Environment = "prod"
    Project     = local.project_name
    Role        = "WebApp"
  }
}

# =============================================================================
# EC2 INSTANCES
# =============================================================================

# GitLab Server
module "ubuntu_ec2_gitlab" {
  source            = "./modules/ubuntu_ec2"
  ami               = local.ami_id
  subnet_id         = element(module.vpc.private_subnet_ids, 0)
  security_group_id = module.security_group_gitlab.security_group_id
  instance_type     = "t3.large"
  instance_name     = "gitlab"
  volume_type       = "gp3"
  volume_size       = 50
  key_name          = local.key_pair_name
}

# Vault Server
module "ubuntu_ec2_vault" {
  source            = "./modules/ubuntu_ec2"
  ami               = local.ami_id
  subnet_id         = element(module.vpc.private_subnet_ids, 0)
  security_group_id = module.security_group_vault.security_group_id
  instance_type     = "t3.medium"
  instance_name     = "vault"
  volume_type       = "gp3"
  volume_size       = 50
  key_name          = local.key_pair_name
}

# =============================================================================
# LOAD BALANCER
# =============================================================================

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${local.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.security_group_alb.security_group_id]
  subnets            = module.vpc.public_subnet_ids

  enable_deletion_protection = false
}

# =============================================================================
# TARGET GROUPS
# =============================================================================

# GitLab Target Group
resource "aws_lb_target_group" "gitlab" {
  name     = "${local.project_name}-gitlab"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 30
    interval            = 60
    path                = "/-/health"
    matcher             = "200"
  }
}

# GitLab Registry Target Group
resource "aws_lb_target_group" "gitlab_registry" {
  name     = "${local.project_name}-registry"
  port     = 5050
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 30
    interval            = 60
    path                = "/v2/"
    matcher             = "200,401"
  }
}

# Vault Target Group
resource "aws_lb_target_group" "vault" {
  name     = "${local.project_name}-vault"
  port     = 8200
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 30
    interval            = 60
    path                = "/v1/sys/health"
    matcher             = "200,429,472,473"
  }
}

# =============================================================================
# TARGET GROUP ATTACHMENTS
# =============================================================================

resource "aws_lb_target_group_attachment" "gitlab" {
  target_group_arn = aws_lb_target_group.gitlab.arn
  target_id        = module.ubuntu_ec2_gitlab.instance_id
  port             = 80
}

resource "aws_lb_target_group_attachment" "gitlab_registry" {
  target_group_arn = aws_lb_target_group.gitlab_registry.arn
  target_id        = module.ubuntu_ec2_gitlab.instance_id
  port             = 5050
}

resource "aws_lb_target_group_attachment" "vault" {
  target_group_arn = aws_lb_target_group.vault.arn
  target_id        = module.ubuntu_ec2_vault.instance_id
  port             = 8200
}

# =============================================================================
# LOAD BALANCER LISTENERS
# =============================================================================

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = data.aws_acm_certificate.wildcard_cert.arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Unsupported host"
      status_code  = "404"
    }
  }
}

# HTTP Redirect Listener
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# =============================================================================
# LISTENER RULES
# =============================================================================

# GitLab routing rule
resource "aws_lb_listener_rule" "gitlab" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  condition {
    host_header {
      values = [local.gitlab_domain]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gitlab.arn
  }
}

# Registry routing rule
resource "aws_lb_listener_rule" "registry" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 101

  condition {
    host_header {
      values = [local.registry_domain]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gitlab_registry.arn
  }
}

# Vault routing rule
resource "aws_lb_listener_rule" "vault" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 102

  condition {
    host_header {
      values = [local.vault_domain]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vault.arn
  }
}

# =============================================================================
# DNS RECORDS
# =============================================================================

resource "aws_route53_record" "gitlab" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.gitlab_domain
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "registry" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.registry_domain
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "vault" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.vault_domain
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
