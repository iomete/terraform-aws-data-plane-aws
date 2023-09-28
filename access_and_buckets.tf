################################################################################
# Lakehouse IAM Role
################################################################################

resource "aws_iam_role" "lakehouse_role" {
  name = local.lakehouse_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "${module.eks.oidc_provider}:sub" : [
              "system:serviceaccount:iomete-system:*",
            ]
          },
          StringEquals = {
            "${module.eks.oidc_provider}:aud" : "sts.amazonaws.com"
          }
        }
      },
    ]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "lakehouse_bucket_access" {
  name = "${local.lakehouse_role_name}-lakehouse-bucket-access-policy"
  role = aws_iam_role.lakehouse_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObjectVersion",
          "s3:DeleteObject",
          "s3:GetObjectVersion",
        ]
        Resource = "arn:aws:s3:::${local.lakehouse_bucket_name}/*"
      },
      {

        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::${local.lakehouse_bucket_name}"
      },
    ]
  })
}

resource "aws_iam_role_policy" "assets_bucket_access" {
  name = "${local.lakehouse_role_name}-assets-bucket-access-policy"
  role = aws_iam_role.lakehouse_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObjectVersion",
          "s3:DeleteObject",
          "s3:GetObjectVersion",
        ]
        Resource = "arn:aws:s3:::${local.assets_bucket_name}/*"
      },
      {

        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::${local.assets_bucket_name}"
      },
    ]
  })
}

################################################################################
# Lakehouse Bucket
################################################################################

resource "aws_s3_bucket" "lakehouse" {
  bucket = local.lakehouse_bucket_name
  tags = local.tags
}

resource "aws_s3_bucket_public_access_block" "lakehouse" {
  bucket = aws_s3_bucket.lakehouse.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

################################################################################
# Assets Bucket
################################################################################

resource "aws_s3_bucket" "assets" {
  bucket = local.assets_bucket_name
  tags = local.tags
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    id = "retention-rule"
    expiration {
      days = 180
    }
    status = "Enabled"
  }
}

################################################################################
# KMS key access?
################################################################################
# If region EBS is enabled, we need access to the KMS key. 
# This is because the EBS CSI driver will create encrypted volumes, and we need to be able to decrypt them.
# If region EBS is not enabled, you can skip this section.

resource "aws_iam_policy_attachment" "kms_describe_attachment" {
  count      = var.kms_key_arn != "null" ? 1 : 0
  name       = "kms-describe-attachment"
  roles      = [module.karpenter.irsa_name, module.eks.eks_managed_node_groups["${var.cluster_name}-ng"].iam_role_name, "AmazonEKS_EBS_CSI_DriverRole-${var.cluster_name}"]
  policy_arn = aws_iam_policy.kms_access_policy[0].arn
}

resource "aws_iam_policy" "kms_access_policy" {
  count       = var.kms_key_arn != "null" ? 1 : 0
  name        = "kms-access-policy"
  description = "Allows access to the KMS key"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowEncryptDecrypt",
      "Effect": "Allow",
      "Action": [
        "kms:*"
      ],
      "Resource": "${var.kms_key_arn}"
    }
  ]
}
EOF
}