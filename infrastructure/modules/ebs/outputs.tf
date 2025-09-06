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

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = aws_iam_role.ebs_csi_driver_role.arn
}

output "ebs_kms_key_id" {
  description = "ID of the KMS key used for EBS encryption"
  value       = var.ebs_kms_key_id != null ? var.ebs_kms_key_id : (length(aws_kms_key.ebs_encryption) > 0 ? aws_kms_key.ebs_encryption[0].key_id : null)
}