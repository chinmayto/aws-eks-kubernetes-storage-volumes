output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = module.eks.cluster_iam_role_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "vpc_id" {
  description = "ID of the VPC where the cluster is deployed"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}



# EFS Outputs
output "efs_file_system_id" {
  description = "ID of the EFS file system"
  value       = module.efs.efs_file_system_id
}

output "efs_file_system_dns_name" {
  description = "DNS name of the EFS file system"
  value       = module.efs.efs_file_system_dns_name
}

output "efs_access_point_id" {
  description = "ID of the EFS access point"
  value       = module.efs.efs_access_point_id
}

# EBS Outputs
output "ebs_volume_id" {
  description = "ID of the static EBS volume"
  value       = module.ebs.ebs_volume_id
}

output "ebs_volume_arn" {
  description = "ARN of the static EBS volume"
  value       = module.ebs.ebs_volume_arn
}

output "ebs_volume_availability_zone" {
  description = "Availability zone of the static EBS volume"
  value       = module.ebs.ebs_volume_availability_zone
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = module.ebs.ebs_csi_driver_role_arn
}

output "ebs_kms_key_id" {
  description = "ID of the KMS key used for EBS encryption"
  value       = module.ebs.ebs_kms_key_id
}

# S3 Outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket for Kubernetes storage"
  value       = module.s3.s3_bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.s3.s3_bucket_arn
}

output "s3_csi_driver_role_arn" {
  description = "ARN of the S3 CSI driver IAM role"
  value       = module.s3.s3_csi_driver_role_arn
}
