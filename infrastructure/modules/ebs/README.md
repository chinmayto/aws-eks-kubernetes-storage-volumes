# EBS Module

This Terraform module creates AWS EBS (Elastic Block Store) resources for use with EKS clusters, including IAM roles and policies for the EBS CSI driver.

## Features

- Creates IAM role and policy for EBS CSI driver with Pod Identity
- Optionally creates a static EBS volume for testing
- Configures KMS encryption for EBS volumes
- Supports various EBS volume types (gp2, gp3, io1, io2, sc1, st1)
- Configurable IOPS and throughput for performance optimization

## Usage

```hcl
module "ebs" {
  source = "./modules/ebs"

  cluster_name         = "my-eks-cluster"
  environment          = "dev"
  vpc_id               = "vpc-12345678"
  private_subnet_ids   = ["subnet-12345678", "subnet-87654321"]
  availability_zones   = ["us-west-2a", "us-west-2b"]
  
  # EBS volume configuration
  ebs_volume_type       = "gp3"
  ebs_volume_size       = 20
  ebs_volume_iops       = 3000
  ebs_volume_throughput = 125
  ebs_encrypted         = true
  
  # Static volume for testing
  create_static_volume = true
  static_volume_size   = 10
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the EKS cluster | `string` | n/a | yes |
| environment | Environment name | `string` | n/a | yes |
| vpc_id | VPC ID where EBS resources will be created | `string` | n/a | yes |
| private_subnet_ids | List of private subnet IDs for EBS volume placement | `list(string)` | n/a | yes |
| availability_zones | List of availability zones for EBS volume placement | `list(string)` | n/a | yes |
| ebs_volume_type | EBS volume type | `string` | `"gp3"` | no |
| ebs_volume_size | Size of the EBS volume in GB | `number` | `20` | no |
| ebs_volume_iops | IOPS for the EBS volume (only for gp3, io1, io2) | `number` | `3000` | no |
| ebs_volume_throughput | Throughput for the EBS volume in MiB/s (only for gp3) | `number` | `125` | no |
| ebs_encrypted | Whether to encrypt the EBS volume | `bool` | `true` | no |
| ebs_kms_key_id | KMS key ID for EBS volume encryption (optional) | `string` | `null` | no |
| create_static_volume | Whether to create a static EBS volume for testing | `bool` | `true` | no |
| static_volume_size | Size of the static EBS volume in GB | `number` | `10` | no |

## Outputs

| Name | Description |
|------|-------------|
| ebs_volume_id | ID of the static EBS volume |
| ebs_volume_arn | ARN of the static EBS volume |
| ebs_volume_availability_zone | Availability zone of the static EBS volume |
| ebs_volume_size | Size of the static EBS volume in GB |
| ebs_volume_type | Type of the static EBS volume |
| ebs_volume_encrypted | Whether the static EBS volume is encrypted |
| ebs_csi_driver_role_arn | ARN of the EBS CSI driver IAM role |
| ebs_csi_driver_policy_arn | ARN of the EBS CSI driver policy |
| ebs_pod_identity_association_id | ID of the EBS CSI driver pod identity association |
| ebs_kms_key_id | ID of the KMS key used for EBS encryption |
| ebs_kms_key_arn | ARN of the KMS key used for EBS encryption |
| ebs_kms_alias_name | Alias name of the KMS key used for EBS encryption |

## EBS Volume Types

- **gp2**: General Purpose SSD (previous generation)
- **gp3**: General Purpose SSD (latest generation) - Recommended
- **io1**: Provisioned IOPS SSD (previous generation)
- **io2**: Provisioned IOPS SSD (latest generation)
- **sc1**: Cold HDD
- **st1**: Throughput Optimized HDD

## IAM Permissions

The module creates an IAM role with the following permissions for the EBS CSI driver:

- Create, attach, detach, and modify EBS volumes
- Create and delete snapshots
- Describe EC2 resources (volumes, snapshots, instances, etc.)
- Create and delete tags on volumes and snapshots
- KMS permissions for encryption (if using KMS)

## Pod Identity Integration

The module uses EKS Pod Identity to associate the IAM role with the EBS CSI driver service account (`ebs-csi-controller-sa` in the `kube-system` namespace).

## Security

- EBS volumes are encrypted by default
- KMS key is created automatically if not provided
- IAM policies follow least privilege principle
- Resource-based conditions limit access to appropriate resources

## Dependencies

This module should be used with:
- EKS cluster with Pod Identity addon enabled
- EBS CSI driver addon (deployed after this module)
- VPC with private subnets in multiple AZs