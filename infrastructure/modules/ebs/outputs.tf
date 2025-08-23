output "ebs_volume_id" {
  description = "ID of the static EBS volume"
  value       = var.create_static_volume ? aws_ebs_volume.static_volume[0].id : null
}

output "ebs_volume_arn" {
  description = "ARN of the static EBS volume"
  value       = var.create_static_volume ? aws_ebs_volume.static_volume[0].arn : null
}

output "ebs_volume_availability_zone" {
  description = "Availability zone of the static EBS volume"
  value       = var.create_static_volume ? aws_ebs_volume.static_volume[0].availability_zone : null
}

output "ebs_volume_size" {
  description = "Size of the static EBS volume in GB"
  value       = var.create_static_volume ? aws_ebs_volume.static_volume[0].size : null
}

output "ebs_volume_type" {
  description = "Type of the static EBS volume"
  value       = var.create_static_volume ? aws_ebs_volume.static_volume[0].type : null
}

output "ebs_volume_encrypted" {
  description = "Whether the static EBS volume is encrypted"
  value       = var.create_static_volume ? aws_ebs_volume.static_volume[0].encrypted : null
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = aws_iam_role.ebs_csi_driver_role.arn
}

output "ebs_csi_driver_policy_arn" {
  description = "ARN of the EBS CSI driver policy"
  value       = aws_iam_policy.ebs_csi_driver_policy.arn
}

output "ebs_pod_identity_association_id" {
  description = "ID of the EBS CSI driver pod identity association"
  value       = aws_eks_pod_identity_association.ebs_csi_driver.association_id
}

output "ebs_kms_key_id" {
  description = "ID of the KMS key used for EBS encryption"
  value       = var.ebs_kms_key_id != null ? var.ebs_kms_key_id : (length(aws_kms_key.ebs_encryption) > 0 ? aws_kms_key.ebs_encryption[0].key_id : null)
}

output "ebs_kms_key_arn" {
  description = "ARN of the KMS key used for EBS encryption"
  value       = var.ebs_kms_key_id != null ? var.ebs_kms_key_id : (length(aws_kms_key.ebs_encryption) > 0 ? aws_kms_key.ebs_encryption[0].arn : null)
}

output "ebs_kms_alias_name" {
  description = "Alias name of the KMS key used for EBS encryption"
  value       = length(aws_kms_alias.ebs_encryption) > 0 ? aws_kms_alias.ebs_encryption[0].name : null
}