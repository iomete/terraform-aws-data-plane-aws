################################################################################
# AWS EBS CSI Driver Role
################################################################################

resource "aws_iam_role" "ebs-csi-driver" {
  name = "AmazonEKS_EBS_CSI_DriverRole-${var.cluster_name}"

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
              "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            ]
          },
          StringEquals = {
            "${module.eks.oidc_provider}:aud" : "sts.amazonaws.com"
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sto-readonly-role-policy-attach" {
  role       = aws_iam_role.ebs-csi-driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}


 