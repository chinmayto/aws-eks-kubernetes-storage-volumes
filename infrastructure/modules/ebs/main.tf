####################################################################################
# Data Sources
####################################################################################
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

####################################################################################
# Static EBS Volume for Testing (Optional)
####################################################################################
resource "aws_ebs_volume" "static_volume" {
  count = var.create_static_volume ? 1 : 0

  availability_zone = var.availability_zones[0]
  size              = var.static_volume_size
  type              = var.ebs_volume_type
  encrypted         = var.ebs_encrypted
  kms_key_id        = var.ebs_kms_key_id

  # Configure IOPS for gp3, io1, io2 volumes
  iops = var.ebs_volume_type == "gp3" || var.ebs_volume_type == "io1" || var.ebs_volume_type == "io2" ? var.ebs_volume_iops : null

  # Configure throughput for gp3 volumes
  throughput = var.ebs_volume_type == "gp3" ? var.ebs_volume_throughput : null

  tags = {
    Name        = "${var.cluster_name}-static-ebs-volume"
    Environment = var.environment
    Terraform   = "true"
    Purpose     = "Static EBS volume for Kubernetes testing"
  }
}

####################################################################################
# IAM Role for EBS CSI Driver (Pod Identity)
####################################################################################
resource "aws_iam_role" "ebs_csi_driver_role" {
  name = "${var.cluster_name}-ebs-csi-driver-role"

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
    Name        = "${var.cluster_name}-ebs-csi-driver-role"
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
# Create Custom EBS CSI Driver Policy
####################################################################################
resource "aws_iam_policy" "ebs_csi_driver_policy" {
  name        = "${var.cluster_name}-ebs-csi-driver-policy"
  description = "Policy for EBS CSI driver"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:ModifyVolume",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumesModifications"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = [
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:snapshot/*"
        ]
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = [
              "CreateVolume",
              "CreateSnapshot"
            ]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteTags"
        ]
        Resource = [
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:snapshot/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:RequestedRegion" = data.aws_region.current.name
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteVolume"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/ebs.csi.aws.com/cluster" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/CSIVolumeSnapshotName" = "*"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-ebs-csi-driver-policy"
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
# Attach EBS CSI Driver Policy
####################################################################################
resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  role       = aws_iam_role.ebs_csi_driver_role.name
  policy_arn = aws_iam_policy.ebs_csi_driver_policy.arn
}

####################################################################################
# Pod Identity Association for EBS CSI Driver
####################################################################################
resource "aws_eks_pod_identity_association" "ebs_csi_driver" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi_driver_role.arn

  tags = {
    Name        = "${var.cluster_name}-ebs-csi-pod-identity"
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
# KMS Key for EBS Encryption (Optional)
####################################################################################
resource "aws_kms_key" "ebs_encryption" {
  count = var.ebs_kms_key_id == null ? 1 : 0

  description             = "KMS key for EBS volume encryption in ${var.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "${var.cluster_name}-ebs-encryption-key"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_kms_alias" "ebs_encryption" {
  count = var.ebs_kms_key_id == null ? 1 : 0

  name          = "alias/${var.cluster_name}-ebs-encryption"
  target_key_id = aws_kms_key.ebs_encryption[0].key_id
}