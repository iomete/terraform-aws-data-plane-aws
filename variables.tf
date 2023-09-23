variable "region" {
  description = "AWS region where cluster will be created"
  type        = string
}

variable "cluster_id" {
  description = "Cluster id from IOMETE. This should match the cluster id in IOMETE"
  type        = string
}
variable "eks_ng_instance_type" {
  description = "EKS main node group instance type"
  type        = string
  default     = "r5a.large"
}

variable "eks_cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.25"
}

variable "volume_size" {
  description = "Cluster node volume size"
  type        = string
  default     = "100"
}

variable "volume_type" {
  description = "Disk mount type"
  type        = string
  default     = "gp3"
}

variable "kms_key_arn" {
  description = "KMS key ARN to decrypt, encrypted resources (e.g. EBS volumes)"
  type        = string
  default     = "null"
}

variable "additional_administrators" {
  description = "A list of IAM ARNs for administrating IOMETE infrastructure. If no value is provided, the current caller identity is used to ensure at least one key admin is available"
  type        = list(string)
  default     = []
}

variable "kubernetes_public_access_cidrs" {
  description = "A list of CIDR blocks to allow access to the Kubernetes API server from. Defaults is '0.0.0.0/0' Anywhere."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "detailed_monitoring" {
  description = "Enable or disable detailed monitoring."
  type        = bool
  default     = false
}

# the followings are your lakehouse bucket name and role name to access it
variable "lakehouse_role_name" {
  description = "A role to access to the lakehouse bucket."
  type        = string
}

variable "lakehouse_bucket_name" {
  description = "A bucket name to store lakehouse data."
  type        = string
}