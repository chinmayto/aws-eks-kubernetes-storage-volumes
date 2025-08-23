variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EFS will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EFS mount targets"
  type        = list(string)
}



variable "performance_mode" {
  description = "EFS performance mode"
  type        = string
  default     = "generalPurpose"
  validation {
    condition     = contains(["generalPurpose", "maxIO"], var.performance_mode)
    error_message = "Performance mode must be either 'generalPurpose' or 'maxIO'."
  }
}

variable "throughput_mode" {
  description = "EFS throughput mode"
  type        = string
  default     = "bursting"
  validation {
    condition     = contains(["bursting", "provisioned"], var.throughput_mode)
    error_message = "Throughput mode must be either 'bursting' or 'provisioned'."
  }
}

variable "posix_user_uid" {
  description = "POSIX user ID for EFS access point"
  type        = number
  default     = 1001
}

variable "posix_user_gid" {
  description = "POSIX group ID for EFS access point"
  type        = number
  default     = 1001
}