####################################################################################
# EFS File System
####################################################################################
resource "aws_efs_file_system" "main" {
  creation_token = "${var.cluster_name}-efs"
  encrypted      = true

  performance_mode = var.performance_mode
  throughput_mode  = var.throughput_mode

  tags = {
    Name        = "${var.cluster_name}-efs"
    Environment = var.environment
    Terraform   = "true"
  }
}
####################################################################################
# EFS Mount Targets (one per private subnet)
####################################################################################
resource "aws_efs_mount_target" "main" {
  count           = length(var.private_subnet_ids)
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}
####################################################################################
# Security Group for EFS
####################################################################################
resource "aws_security_group" "efs" {
  name_prefix = "${var.cluster_name}-efs-"
  vpc_id      = var.vpc_id

  ingress {
    description = "NFS from EKS nodes"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-efs-sg"
    Environment = var.environment
    Terraform   = "true"
  }
}


####################################################################################
# EFS Access Point for Pod
####################################################################################
resource "aws_efs_access_point" "pod_access_point" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = var.posix_user_gid
    uid = var.posix_user_uid
  }

  root_directory {
    path = "/app-data"
    creation_info {
      owner_gid   = var.posix_user_gid
      owner_uid   = var.posix_user_uid
      permissions = "755"
    }
  }

  tags = {
    Name        = "${var.cluster_name}-efs-access-point"
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
# Data Sources
####################################################################################
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

####################################################################################
# IAM Role for EFS CSI Driver (Pod Identity)
####################################################################################
resource "aws_iam_role" "efs_csi_driver_role" {
  name = "${var.cluster_name}-efs-csi-driver-role"

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
    Name        = "${var.cluster_name}-efs-csi-driver-role"
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
# Create Custom EFS CSI Driver Policy
####################################################################################
resource "aws_iam_policy" "efs_csi_driver_policy" {
  name        = "${var.cluster_name}-efs-csi-driver-policy"
  description = "Policy for EFS CSI driver"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets",
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:CreateAccessPoint",
          "elasticfilesystem:TagResource"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:DeleteAccessPoint"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "elasticfilesystem:AccessedViaMountTarget" = "true"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-efs-csi-driver-policy"
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
# Attach EFS CSI Driver Policy
####################################################################################
resource "aws_iam_role_policy_attachment" "efs_csi_driver_policy" {
  role       = aws_iam_role.efs_csi_driver_role.name
  policy_arn = aws_iam_policy.efs_csi_driver_policy.arn
}

####################################################################################
# Pod Identity Association for EFS CSI Driver
####################################################################################
resource "aws_eks_pod_identity_association" "efs_csi_driver" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "efs-csi-controller-sa"
  role_arn        = aws_iam_role.efs_csi_driver_role.arn

  tags = {
    Name        = "${var.cluster_name}-efs-csi-pod-identity"
    Environment = var.environment
    Terraform   = "true"
  }
}

