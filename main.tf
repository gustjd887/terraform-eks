module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.1"

  name = "onboarding"
  cidr = "192.168.2.0/23"

  azs             = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
  public_subnets  = ["192.168.2.0/27", "192.168.2.32/27", "192.168.2.64/27"]
  private_subnets = ["192.168.2.128/25", "192.168.3.0/25", "192.168.3.128/25"]

  enable_nat_gateway   = true
  enable_dns_hostnames = true
}

resource "aws_security_group" "security_group" {
  vpc_id = module.vpc.vpc_id
  ingress {
    description = "allow ssh from all"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.15.1"

  cluster_name    = "onboarding"
  cluster_version = "1.26"

  cluster_endpoint_public_access  = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # node_security_group_id = module.security-group.security_group_id

  eks_managed_node_groups = {
    onboarding-eks-node = {
      min_size     = 1
      max_size     = 3
      desired_size = 3

      instance_types = ["t3.large"]
      capacity_type  = "SPOT"

      use_custom_launch_template = false

      remote_access = {
        ec2_ssh_key               = "kuberix-lab"
        source_security_group_ids = [aws_security_group.security_group.id]
      }
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

# module "eks_managed_node_group" {
#   source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"

#   name            = "onboarding-eks-node"
#   cluster_name    = "onboarding"
#   cluster_version = "1.26"

#   subnet_ids = module.vpc.private_subnets

#   // The following variables are necessary if you decide to use the module outside of the parent EKS module context.
#   // Without it, the security groups of the nodes are empty and thus won't join the cluster.
#   cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
#   vpc_security_group_ids            = [module.eks.node_security_group_id]

#   // Note: `disk_size`, and `remote_access` can only be set when using the EKS managed node group default launch template
#   // This module defaults to providing a custom launch template to allow for custom security groups, tag propagation, etc.
#   // use_custom_launch_template = false
#   // disk_size = 50
#   //
#   //  # Remote access cannot be specified with a launch template
#   remote_access = {
#     ec2_ssh_key               = "kuberix-lab"
#     source_security_group_ids = [module.security-group.security_group_id]
#   }

#   min_size     = 1
#   max_size     = 3
#   desired_size = 3

#   instance_types = ["t3.large"]
#   capacity_type  = "SPOT"

#   labels = {
#     Environment = "test"
#     GithubRepo  = "terraform-aws-eks"
#     GithubOrg   = "terraform-aws-modules"
#   }

#   # taints = {
#   #   dedicated = {
#   #     key    = "dedicated"
#   #     value  = "gpuGroup"
#   #     effect = "NO_SCHEDULE"
#   #   }
#   # }

#   tags = {
#     Environment = "dev"
#     Terraform   = "true"
#   }
# }

module "ec2-instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.0.0"

  name = "onboarding-bastion"

  instance_type = "t2.micro"
  key_name = "kuberix-lab"
  vpc_security_group_ids = [aws_security_group.security_group.id, module.eks.node_security_group_id]
  subnet_id = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  ami = "ami-0e05f79e46019bfac"

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}