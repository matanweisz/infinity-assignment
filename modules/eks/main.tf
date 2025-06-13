module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.36.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  enable_irsa = true

  cluster_addons = var.cluster_addons

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    project-ng = {
      desired_size = 1
      max_size     = 3
      min_size     = 1

      instance_types = ["t3.medium"]

      launch_template = {
        name     = "project-worker-node"
        version  = "$Latest"
        key_name = var.key_name
      }
    }
  }

  tags = var.tags
}
