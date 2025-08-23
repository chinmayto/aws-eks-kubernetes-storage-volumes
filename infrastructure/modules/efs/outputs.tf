output "efs_file_system_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.main.id
}

output "efs_file_system_arn" {
  description = "ARN of the EFS file system"
  value       = aws_efs_file_system.main.arn
}

output "efs_file_system_dns_name" {
  description = "DNS name of the EFS file system"
  value       = aws_efs_file_system.main.dns_name
}

output "efs_access_point_id" {
  description = "ID of the EFS access point"
  value       = aws_efs_access_point.pod_access_point.id
}

output "efs_access_point_arn" {
  description = "ARN of the EFS access point"
  value       = aws_efs_access_point.pod_access_point.arn
}

output "efs_security_group_id" {
  description = "ID of the EFS security group"
  value       = aws_security_group.efs.id
}

output "efs_csi_driver_role_arn" {
  description = "ARN of the EFS CSI driver IAM role"
  value       = aws_iam_role.efs_csi_driver_role.arn
}

output "efs_pod_identity_association_id" {
  description = "ID of the EFS CSI driver pod identity association"
  value       = aws_eks_pod_identity_association.efs_csi_driver.association_id
}

output "efs_csi_driver_policy_arn" {
  description = "ARN of the EFS CSI driver policy"
  value       = aws_iam_policy.efs_csi_driver_policy.arn
}