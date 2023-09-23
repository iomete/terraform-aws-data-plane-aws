# IOMETE Data-Plane module

## Terraform module which creates resources on AWS.


## References
- https://github.com/terraform-aws-modules/terraform-aws-eks

## Module Usage

### Warning

 
 |⚠ WARNING: If you add additional_administrators, you must add the current user ARN to the list. Otherwise, you will not be able to access the cluster.|
  | --- |


## Terraform code

```hcl

module "data-plane-aws" {
  source                  = "iomete/data-plane-aws/aws"
  version                 = "1.0.0"
  region                  = "us-east-1"  
  workspace_id            = "ws_id"  
  lakehouse_role_name 	  = "iomete-lakehouse-role-kgnwqy"
  lakehouse_bucket_name   = "iomete-lakehouse-bucket-kgnwqy"
 
  # optional | the following line gives permission to administrate Kubernetes and KMS
  # additional_administrators = ["arn:aws:iam::1234567890:user/your_arn", "arn:aws:iam::1234567890:user/user2", "arn:aws:iam::1234567890:user/user3"] 
}
################# 
# Outputs 
#################

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = module.data-plane-aws.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.data-plane-aws.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate cluster with the IOMETE controlplane"
  value       = module.data-plane-aws.cluster_certificate_authority_data
}



```

## Terraform Deployment

```shell
terraform init
terraform plan
terraform apply
```

## Description of variables

| Name | Description | Required |
| --- | --- | --- |
|region| AWS region where is cluster will install | Yes |
|workspace_id| Workspace ID from IOMETE control plane when creted new cluster | Yes |
|lakehouse_role_name| Name of the role that will be used to access the s3 bucket | Yes |
|lakehouse_bucket_name| Name of the bucket that will be used to store Lakehouse data.  Bucket name must be unique across all existing bucket names in Amazon S3. | Yes |
|additional_administrators| List of IAM users or roles that can administer the IOMETE stack. If not provided, a new KMS key and Kubernetes auth will be created only for current user | No |
|kubernetes_public_access_cidrs| To restrict public access your Kubernetes API need to use IOMETE control-plane IP address. If enable you to have to insert your IP range as well to access Kubernetes. | No |

 
