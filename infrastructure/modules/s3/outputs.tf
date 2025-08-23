output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.main.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.main.arn
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.main.bucket_domain_name
}

output "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

output "s3_csi_driver_role_arn" {
  description = "ARN of the S3 CSI Driver IAM role"
  value       = aws_iam_role.s3_csi_driver_role.arn
}

output "s3_csi_driver_policy_arn" {
  description = "ARN of the S3 CSI Driver policy"
  value       = aws_iam_policy.s3_csi_driver_policy.arn
}
