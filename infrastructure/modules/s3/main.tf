####################################################################################
# S3 Bucket for Kubernetes Storage
####################################################################################
resource "aws_s3_bucket" "main" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
# S3 Bucket Versioning
####################################################################################
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Disabled"
  }
}

####################################################################################
# S3 Bucket Encryption
####################################################################################
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

####################################################################################
# S3 Bucket Public Access Block
####################################################################################
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

####################################################################################
# Data Sources
####################################################################################
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

####################################################################################
# IAM Role for S3 CSI Driver (Pod Identity)
####################################################################################
resource "aws_iam_role" "s3_csi_driver_role" {
  name = "${var.cluster_name}-s3-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-s3-csi-driver-role"
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
# S3 CSI Driver Policy
####################################################################################
resource "aws_iam_policy" "s3_csi_driver_policy" {
  name        = "${var.cluster_name}-s3-csi-driver-policy"
  description = "Policy for S3 CSI Driver"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = [
          aws_s3_bucket.main.arn,
          "arn:aws:s3:::*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion",
          "s3:DeleteObjectVersion",
          "s3:RestoreObject"
        ]
        Resource = [
          "${aws_s3_bucket.main.arn}/*",
          "arn:aws:s3:::*/*"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-s3-csi-driver-policy"
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
# Attach S3 CSI Driver Policy
####################################################################################
resource "aws_iam_role_policy_attachment" "s3_csi_driver_policy" {
  role       = aws_iam_role.s3_csi_driver_role.name
  policy_arn = aws_iam_policy.s3_csi_driver_policy.arn
}

####################################################################################
# Pod Identity Association for S3 CSI Driver
####################################################################################
resource "aws_eks_pod_identity_association" "s3_csi_driver" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "s3-csi-driver-sa"
  role_arn        = aws_iam_role.s3_csi_driver_role.arn

  tags = {
    Name        = "${var.cluster_name}-s3-csi-driver-pod-identity"
    Environment = var.environment
    Terraform   = "true"
  }
}
