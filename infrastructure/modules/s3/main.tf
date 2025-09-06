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
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

####################################################################################
# IAM Role for S3 CSI Driver (IRSA)
####################################################################################
resource "aws_iam_role" "s3_csi_driver_role" {
  name = "${var.cluster_name}-s3-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:s3-csi-driver-sa"
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
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
# S3 CSI Driver Policy (Based on AWS Documentation)
####################################################################################
resource "aws_iam_policy" "s3_csi_driver_policy" {
  name        = "${var.cluster_name}-s3-csi-driver-policy"
  description = "IAM policy for S3 CSI Driver based on AWS documentation"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.main.arn}/*"
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
