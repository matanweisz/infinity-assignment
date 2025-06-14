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

# Define local variables for domains and project name
locals {
  gitlab_domain   = "gitlab.matanweisz.xyz"
  registry_domain = "registry.matanweisz.xyz"
  vault_domain    = "vault.matanweisz.xyz"
  project_name    = "infinity-assignment"
}

# Get existing Route53 hosted zone
data "aws_route53_zone" "main" {
  name         = "matanweisz.xyz"
  private_zone = false
}

# Get the ACM certificate for my domain
data "aws_acm_certificate" "wildcard_cert" {
  domain      = "matanweisz.xyz"
  statuses    = ["ISSUED"]
  most_recent = true
  types       = ["AMAZON_ISSUED"]
}

# Create VPC and Network Components
module "vpc" {
  source              = "./modules/vpc"
  vpc_cidr            = "10.0.0.0/16"
  vpc_name            = "${local.project_name}-vpc"
  availability_zone_1 = "eu-central-1a"
  availability_zone_2 = "eu-central-1b"
}

# Create the EKS Cluster
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.37.0"
  cluster_name    = "${local.project_name}-eks"
  cluster_version = "1.33"
  subnet_ids      = module.vpc.private_subnet_ids
  vpc_id          = module.vpc.vpc_id

  enable_irsa = true

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false

  eks_managed_node_groups = {
    default_node_group = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 1
      max_size       = 4
    }
  }

  tags = {
    Environment = "dev"
    Project     = local.project_name
  }
}

# Security Group for GitLab EC2 Instance
module "security_group_gitlab" {
  source        = "./modules/security_group"
  sg_name       = "gitlab-sg"
  vpc_id        = module.vpc.vpc_id
  ingress_rules = []
}

# Security Group for Vault EC2 Instance
module "security_group_vault" {
  source        = "./modules/security_group"
  sg_name       = "vault-sg"
  vpc_id        = module.vpc.vpc_id
  ingress_rules = []
}

# Security Group for Application Load Balancer
module "security_group_alb" {
  source  = "./modules/security_group"
  sg_name = "${local.project_name}-alb-sg"
  vpc_id  = module.vpc.vpc_id
  ingress_rules = [
    { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
  ]
}

# Application Load Balancer
resource "aws_lb" "project_alb" {
  name                       = "${local.project_name}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [module.security_group_alb.security_group_id]
  subnets                    = module.vpc.public_subnet_ids
  enable_deletion_protection = false

  tags = {
    Name = "${local.project_name}-alb"
  }
}

# GitLab EC2 Instance
module "ubuntu_ec2_gitlab" {
  source            = "./modules/ubuntu_ec2"
  ami               = "ami-014dd8ec7f09293e6" # Ubuntu Server 24.04 LTS
  subnet_id         = element(module.vpc.private_subnet_ids, 0)
  security_group_id = module.security_group_gitlab.security_group_id
  instance_type     = "t3.large"
  instance_name     = "gitlab-server"
  volume_type       = "gp3"
  volume_size       = 60
}

# Vault EC2 Instance
module "ubuntu_ec2_vault" {
  source            = "./modules/ubuntu_ec2"
  ami               = "ami-014dd8ec7f09293e6" # Ubuntu Server 24.04 LTS
  subnet_id         = element(module.vpc.private_subnet_ids, 0)
  security_group_id = module.security_group_vault.security_group_id
  instance_type     = "t3.large"
  instance_name     = "vault-server"
  volume_type       = "gp3"
  volume_size       = 30
}

# Target Group for GitLab
resource "aws_lb_target_group" "gitlab_tg" {
  name     = "gitlab-tg"
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
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = {
    Name = "gitlab-tg"
  }
}

# Target Group for GitLab Container Registry
resource "aws_lb_target_group" "gitlab_registry_tg" {
  name     = "gitlab-registry-tg"
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
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = {
    Name = "gitlab-registry-tg"
  }
}

# Attach GitLab instance to target groups
resource "aws_lb_target_group_attachment" "gitlab_attachment" {
  target_group_arn = aws_lb_target_group.gitlab_tg.arn
  target_id        = module.ubuntu_ec2_gitlab.instance_id
  port             = 80
}

# Attach GitLab Container Registry to target groups
resource "aws_lb_target_group_attachment" "gitlab_registry_attachment" {
  target_group_arn = aws_lb_target_group.gitlab_registry_tg.arn
  target_id        = module.ubuntu_ec2_gitlab.instance_id
  port             = 5050
}

# Target Group for Vault
resource "aws_lb_target_group" "vault_tg" {
  name     = "vault-tg"
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
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = {
    Name = "vault-tg"
  }
}

# Attach Vault instance to target group
resource "aws_lb_target_group_attachment" "vault_attachment" {
  target_group_arn = aws_lb_target_group.vault_tg.arn
  target_id        = module.ubuntu_ec2_vault.instance_id
  port             = 8200
}

# HTTPS Listener
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.project_alb.arn
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

# Rule for GitLab (host-based)
resource "aws_lb_listener_rule" "gitlab_rule" {
  listener_arn = aws_lb_listener.https_listener.arn
  priority     = 100

  condition {
    host_header {
      values = [local.gitlab_domain]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gitlab_tg.arn
  }
}

# Rule for Registry (host-based)
resource "aws_lb_listener_rule" "registry_rule" {
  listener_arn = aws_lb_listener.https_listener.arn
  priority     = 101

  condition {
    host_header {
      values = [local.registry_domain]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gitlab_registry_tg.arn
  }
}

# Rule for Vault (host-based)
resource "aws_lb_listener_rule" "vault_rule" {
  listener_arn = aws_lb_listener.https_listener.arn
  priority     = 102

  condition {
    host_header {
      values = [local.vault_domain]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vault_tg.arn
  }
}

# HTTP to HTTPS redirect
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.project_alb.arn
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

# Security Group Rules - Allow ALB to communicate with GitLab
resource "aws_security_group_rule" "allow_alb_to_gitlab_web" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = module.security_group_gitlab.security_group_id
  source_security_group_id = module.security_group_alb.security_group_id
}

resource "aws_security_group_rule" "allow_alb_to_gitlab_registry" {
  type                     = "ingress"
  from_port                = 5050
  to_port                  = 5050
  protocol                 = "tcp"
  security_group_id        = module.security_group_gitlab.security_group_id
  source_security_group_id = module.security_group_alb.security_group_id
}

# Security Group Rules - Allow ALB to communicate with Vault
resource "aws_security_group_rule" "allow_alb_to_vault" {
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  security_group_id        = module.security_group_vault.security_group_id
  source_security_group_id = module.security_group_alb.security_group_id
}

# Allow all outbound traffic for Vault (needed for package downloads, etc.)
resource "aws_security_group_rule" "vault_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.security_group_vault.security_group_id
}


# Allow all outbound traffic for GitLab (needed for package downloads, etc.)
resource "aws_security_group_rule" "gitlab_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.security_group_gitlab.security_group_id
}

# Allow Vault HTTPS outbound (port 443)
resource "aws_security_group_rule" "vault_outbound_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.security_group_vault.security_group_id
}

# Allow Vault HTTP outbound (port 80)
resource "aws_security_group_rule" "vault_outbound_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.security_group_vault.security_group_id
}

# Allow GitLab HTTPS outbound (port 443)
resource "aws_security_group_rule" "gitlab_outbound_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.security_group_gitlab.security_group_id
}

# Allow GitLab HTTP outbound (port 80)
resource "aws_security_group_rule" "gitlab_outbound_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.security_group_gitlab.security_group_id
}

# Allow DNS outbound (port 53)
resource "aws_security_group_rule" "gitlab_outbound_dns" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.security_group_gitlab.security_group_id
}

# DNS Records - Point domains to load balancer
resource "aws_route53_record" "gitlab" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.gitlab_domain
  type    = "A"

  alias {
    name                   = aws_lb.project_alb.dns_name
    zone_id                = aws_lb.project_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "gitlab_registry" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.registry_domain
  type    = "A"

  alias {
    name                   = aws_lb.project_alb.dns_name
    zone_id                = aws_lb.project_alb.zone_id
    evaluate_target_health = true
  }
}

# Allow DNS outbound (port 53)
resource "aws_security_group_rule" "vault_outbound_dns" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.security_group_vault.security_group_id
}

# Allow GitLab to communicate with Vault within the VPC
resource "aws_security_group_rule" "allow_gitlab_to_vault" {
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  security_group_id        = module.security_group_vault.security_group_id
  source_security_group_id = module.security_group_gitlab.security_group_id
  description              = "Allow GitLab to access Vault"
}

# Allow Vault to communicate with GitLab within the VPC
resource "aws_security_group_rule" "allow_vault_to_gitlab" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = module.security_group_gitlab.security_group_id
  source_security_group_id = module.security_group_vault.security_group_id
  description              = "Allow Vault to access GitLab"
}

# DNS Record - Point vault domain to load balancer
resource "aws_route53_record" "vault" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.vault_domain
  type    = "A"

  alias {
    name                   = aws_lb.project_alb.dns_name
    zone_id                = aws_lb.project_alb.zone_id
    evaluate_target_health = true
  }
}
