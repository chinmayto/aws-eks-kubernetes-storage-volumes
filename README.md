# EKS Cluster with Terraform

This project creates an Amazon EKS cluster with the following infrastructure:

- VPC with 2 public and 2 private subnets across 2 availability zones
- 2 NAT Gateways (one in each public subnet)
- EKS cluster (CT-EKS-Cluster) version 1.33 deployed in private subnets
- EKS managed node group with t3.medium instances
- EFS file system with CSI driver for persistent storage
- IAM roles and policies for pod identity integration

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0 installed
- kubectl installed (for cluster access)
- S3 bucket for Terraform state storage (configured in providers.tf)
- DynamoDB table for state locking (optional but recommended)

## Quick Start

1. **Configure S3 backend**:
   The project uses native S3 backend for state management. Update the backend configuration in `infrastructure/providers.tf`:
   ```hcl
   backend "s3" {
     bucket         = "your-terraform-state-bucket"
     key            = "eks-cluster/terraform.tfstate"
     region         = "us-west-2"
     encrypt        = true
     dynamodb_table = "terraform-state-lock"
   }
   ```

2. **Setup AWS resources** (one-time setup):
   ```bash
   # Create S3 bucket for state storage
   aws s3 mb s3://your-terraform-state-bucket --region us-west-2
   
   # Enable versioning on the bucket (recommended)
   aws s3api put-bucket-versioning \
     --bucket your-terraform-state-bucket \
     --versioning-configuration Status=Enabled
   
   # Create DynamoDB table for state locking (optional but recommended)
   aws dynamodb create-table \
     --table-name terraform-state-lock \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
     --region us-west-2
   ```

3. **Configure variables**:
   ```bash
   cd infrastructure
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your desired values
   ```

4. **Initialize and deploy**:
   ```bash
   cd infrastructure
   terraform init
   terraform plan
   terraform apply
   ```

5. **Configure kubectl**:
   ```bash
   aws eks update-kubeconfig --region us-west-2 --name CT-EKS-Cluster
   ```

6. **Verify cluster**:
   ```bash
   kubectl get nodes
   ```

## Configuration

### Variables

Key variables you can customize in `terraform.tfvars`:

- `aws_region`: AWS region (default: us-west-2)
- `cluster_name`: EKS cluster name (default: CT-EKS-Cluster)
- `cluster_version`: Kubernetes version (default: 1.33)
- `vpc_cidr`: VPC CIDR block (default: 10.0.0.0/16)
- `public_subnet_cidrs`: Public subnet CIDRs
- `private_subnet_cidrs`: Private subnet CIDRs

### Architecture

```
Internet Gateway
       |
   Public Subnets (10.0.1.0/24, 10.0.2.0/24)
       |
   NAT Gateways (2x)
       |
   Private Subnets (10.0.10.0/24, 10.0.20.0/24)
       |
   EKS Cluster & Worker Nodes
```

## Outputs

After deployment, you'll get:
- Cluster endpoint
- VPC and subnet IDs
- NAT Gateway IDs
- Security group information
- EFS file system ID and DNS name
- EFS access point ID for Kubernetes integration

## Storage Options

The project includes comprehensive storage solutions for different use cases:

### EFS (Elastic File System) - Shared Storage
- **Location**: `infrastructure/modules/efs/` - Terraform module for EFS
- **Manifests**: `k8s-manifests/EFS-storage/` - Kubernetes manifests
- **Features**: Encrypted storage, multi-AZ mount targets, ReadWriteMany access
- **Use Case**: Shared storage across multiple pods
- **Provisioning**: Static and dynamic provisioning supported

```bash
cd k8s-manifests/EFS-storage
./static-deploy.sh    # For static provisioning
./dynamic-deploy.sh   # For dynamic provisioning
```

### EBS (Elastic Block Store) - High Performance Storage
- **Location**: `k8s-manifests/EBS-storage/` - Kubernetes manifests
- **Features**: High IOPS, encryption, gp3 volumes with configurable performance
- **Use Case**: High-performance storage for single pods
- **Access Mode**: ReadWriteOnce (single node access)
- **Provisioning**: Static and dynamic provisioning supported

```bash
cd k8s-manifests/EBS-storage
./static-deploy.sh    # For static provisioning with existing EBS volume
./dynamic-deploy.sh   # For dynamic provisioning (recommended)
```

### S3 (Simple Storage Service) - Object Storage
- **Location**: `k8s-manifests/S3-storage/` - Kubernetes manifests
- **Features**: Unlimited capacity, S3 Mountpoint CSI driver, Pod Identity integration
- **Use Case**: Large-scale data storage, content serving, backup storage
- **Access Mode**: ReadWriteMany (multiple pods can access)
- **Provisioning**: Static provisioning only (S3 CSI driver limitation)

```bash
cd k8s-manifests/S3-storage
./deploy.sh
```

## Cleanup

```bash
cd infrastructure
terraform destroy
```

## Backend Configuration

This project uses Terraform's native S3 backend for state management:

- **State file**: Stored in S3 with encryption enabled
- **State locking**: Uses DynamoDB to prevent concurrent modifications
- **Versioning**: Recommended to enable on S3 bucket for state history
- **Configuration**: Located in `infrastructure/providers.tf`

## Security Notes

- EKS cluster is deployed in private subnets
- Public access to cluster endpoint is enabled (can be restricted)
- NAT Gateways provide outbound internet access for private subnets
- Security groups follow least privilege principles
- Terraform state is encrypted and stored securely in S3