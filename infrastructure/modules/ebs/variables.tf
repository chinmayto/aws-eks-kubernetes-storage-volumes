variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EBS resources will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EBS volume placement"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones for EBS volume placement"
  type        = list(string)
}

variable "ebs_volume_type" {
  description = "EBS volume type"
  type        = string
  default     = "gp3"
  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2", "sc1", "st1"], var.ebs_volume_type)
    error_message = "EBS volume type must be one of: gp2, gp3, io1, io2, sc1, st1."
  }
}

variable "ebs_volume_size" {
  description = "Size of the EBS volume in GB"
  type        = number
  default     = 20
  validation {
    condition     = var.ebs_volume_size >= 1 && var.ebs_volume_size <= 16384
    error_message = "EBS volume size must be between 1 and 16384 GB."
  }
}

variable "ebs_volume_iops" {
  description = "IOPS for the EBS volume (only for gp3, io1, io2)"
  type        = number
  default     = 3000
  validation {
    condition     = var.ebs_volume_iops >= 100 && var.ebs_volume_iops <= 64000
    error_message = "EBS volume IOPS must be between 100 and 64000."
  }
}

variable "ebs_volume_throughput" {
  description = "Throughput for the EBS volume in MiB/s (only for gp3)"
  type        = number
  default     = 125
  validation {
    condition     = var.ebs_volume_throughput >= 125 && var.ebs_volume_throughput <= 1000
    error_message = "EBS volume throughput must be between 125 and 1000 MiB/s."
  }
}

variable "ebs_encrypted" {
  description = "Whether to encrypt the EBS volume"
  type        = bool
  default     = true
}

variable "ebs_kms_key_id" {
  description = "KMS key ID for EBS volume encryption (optional)"
  type        = string
  default     = null
}

variable "create_static_volume" {
  description = "Whether to create a static EBS volume for testing"
  type        = bool
  default     = true
}

variable "static_volume_size" {
  description = "Size of the static EBS volume in GB"
  type        = number
  default     = 10
}