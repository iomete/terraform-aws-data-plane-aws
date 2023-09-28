provider "aws" {
  region = var.region
}

locals {
  module_version        = "1.1.0"
  lakehouse_bucket_name = "${var.cluster_name}-lakehouse"
  assets_bucket_name    = "${var.cluster_name}-assets"
  lakehouse_role_name   = "${var.cluster_name}-lakehouse-role"

  tags = {
    "iomete.com/cluster_name" : var.cluster_name
    "iomete.com/terraform" : true
    "iomete.com/managed" : true
  }
}
