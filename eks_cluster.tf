data "aws_availability_zones" "available" {}

locals {
   vpc_cidr            = "10.10.0.0/16"
  azs                 = slice(data.aws_availability_zones.available.names, 0, (length(data.aws_availability_zones.available.names) <= 2 ? length(data.aws_availability_zones.available.names) : 3))
  arns                = concat(var.additional_administrators, ["arn:aws:iam::680330367469:role/iomete-eks-operator"])
}

################################################################################
# EKS Cluster
################################################################################

module "eks" {
  source                                       = "terraform-aws-modules/eks/aws"
  version                                      = "19.15.4"
  cluster_name                                 = local.cluster_name
  cluster_version                              = var.eks_cluster_version
  kms_key_administrators                       = var.additional_administrators
  vpc_id                                       = module.vpc.vpc_id
  subnet_ids                                   = module.vpc.private_subnets
  control_plane_subnet_ids                     = module.vpc.intra_subnets
  node_security_group_enable_recommended_rules = false
  cluster_endpoint_public_access               = true
  cluster_endpoint_private_access              = true
  cluster_endpoint_public_access_cidrs         = var.kubernetes_public_access_cidrs

  # Required for Karpenter role below
  enable_irsa = true

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
    aws-ebs-csi-driver = {
      service_account_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.ebs-csi-driver.name}"
      resolve_conflicts        = "OVERWRITE"
    }
  }

  node_security_group_tags = {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = local.cluster_name
  }

  # Only need one node to get Karpenter up and running if you uncommented karpenter provisioner in helms.tf
  # This ensures core services such as VPC CNI, CoreDNS, etc. are up and running
  # so that Karpenter can be deployed and start managing compute capacity as required
  eks_managed_node_groups = {
    "${local.cluster_name}-ng" = {
      enable_monitoring = var.detailed_monitoring
      instance_types    = ["t3a.xlarge"]
      #keep nodes in same AZ
      subnet_ids = [module.vpc.private_subnets[0]]
      # Ensure enough capacity to run 2 Karpenter pods
      min_size     = 1
      max_size     = 3
      desired_size = 1
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = var.volume_size
            volume_type           = var.volume_type
            delete_on_termination = true
          }
        }
      }
    }
  }
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    ingress_cluster_all = {
      description                   = "Cluster to node all ports/protocols (covering istio calls through ELB)"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
    egress_all = {
      description = "Allow all egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      rolearn  = module.eks.cluster_iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    },
  ]

  aws_auth_users = concat([for index, value in local.arns :
    {
      userarn  = value
      username = split("/", value)[1]
      groups   = ["system:masters"]
    }
  ])

  tags = local.tags
}

################################################################################
# Karpenter
################################################################################

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "18.31.0"

  cluster_name                    = module.eks.cluster_name
  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]

  # Since Karpenter is running on an EKS Managed Node group,
  # we can re-use the role that was created for the node group
  create_iam_role = false
  iam_role_arn    = module.eks.eks_managed_node_groups["${local.cluster_name}-ng"].iam_role_arn
  tags            = local.tags
}


################################################################################
# VPC
################################################################################


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.cluster_name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 3, k + 5)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  enable_flow_log                      = false
  create_flow_log_cloudwatch_iam_role  = false
  create_flow_log_cloudwatch_log_group = false

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    # Tags subnets for Karpenter auto-discovery
    "karpenter.sh/discovery" = local.cluster_name
  }

  tags = local.tags
}


