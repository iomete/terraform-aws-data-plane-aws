# Description: Creates a secret in Kubernetes details for the iomete-controller
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

data "aws_caller_identity" "current" {}


resource "kubernetes_secret" "iom-manage-secrets" {
  metadata {
    name = "iomete-manage-secrets"
  }

  data = {
    "aws.settings" = jsonencode({
      region = var.region,
      cluster = {
        id   = var.cluster_id,
        name = local.cluster_name,
      },
      karpenter = {
        irsa_arn         = module.karpenter.irsa_arn,
        instance_profile = module.karpenter.instance_profile_name,
        queue_name       = module.karpenter.queue_name,
      },
      eks = {
        name                      = module.eks.cluster_name,
        endpoint                  = module.eks.cluster_endpoint,
        admin_arn                 = data.aws_caller_identity.current.arn,
        additional_administrators = var.additional_administrators,
        nat_public_ips            = module.vpc.nat_public_ips

      },
      default_storage_configuration = {
        cluster_lakehouse_role_arn = aws_iam_role.cluster_lakehouse.arn,
        bucket_arn                 = module.storage-configuration.bucket_arn,
        bucket_access_role_arn     = module.storage-configuration.bucket_access_role_arn
      },
      terraform = {
        module_version = local.module_version
      },
      loki = {
        bucket           = aws_s3_bucket.assets.bucket
        cluster_role_arn = aws_iam_role.cluster_lakehouse.arn
        region           = var.region
      },
    })
  }

  type = "opaque"

  depends_on = [
    module.karpenter,
    module.eks,
  ]
}

resource "kubernetes_namespace" "fluxcd" {
  metadata {
    name = "fluxcd"
  }
}


resource "helm_release" "fluxcd" {
  name       = "helm-operator"
  namespace  = "fluxcd"
  repository = "https://fluxcd-community.github.io/helm-charts"
  version    = "2.7.0"
  chart      = "flux2"
  depends_on = [
    kubernetes_namespace.fluxcd
  ]
  set {
    name  = "imageReflectionController.create"
    value = "false"
  }

  set {
    name  = "imageAutomationController.create"
    value = "false"
  }

  set {
    name  = "kustomizeController.create"
    value = "false"
  }

  set {
    name  = "notificationController.create"
    value = "false"
  }


}
