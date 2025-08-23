# EBS Storage Manifests

This directory contains Kubernetes manifests for testing EBS (Elastic Block Store) storage with the AWS EBS CSI driver.

## Prerequisites

- EKS cluster with EBS CSI driver addon installed
- kubectl configured to access your cluster
- For static provisioning: Pre-created EBS volume

## Files Overview

### Static Provisioning
- `static-storage-class.yaml` - StorageClass for static EBS volumes
- `static-persistent-volume.yaml` - PersistentVolume pointing to existing EBS volume
- `static-persistent-volume-claim.yaml` - PersistentVolumeClaim for static volume
- `static-nginx-pod.yaml` - Test pod using static EBS volume
- `static-nginx-service.yaml` - Service to expose the static test pod
- `static-deploy.sh` - Deployment script for static provisioning

### Dynamic Provisioning
- `dynamic-storage-class.yaml` - StorageClass for dynamic EBS volume creation
- `dynamic-persistent-volume-claim.yaml` - PersistentVolumeClaim for dynamic volume
- `dynamic-nginx-pod.yaml` - Test pod using dynamic EBS volume
- `dynamic-nginx-service.yaml` - Service to expose the dynamic test pod
- `dynamic-deploy.sh` - Deployment script for dynamic provisioning

## Usage

### Dynamic Provisioning (Recommended)
```bash
cd k8s-manifests/EBS-storage
chmod +x dynamic-deploy.sh
./dynamic-deploy.sh
```

### Static Provisioning
1. First create an EBS volume in your Terraform configuration
2. Add output for the volume ID in your Terraform
3. Run the deployment script:
```bash
cd k8s-manifests/EBS-storage
chmod +x static-deploy.sh
./static-deploy.sh
```

## Key Differences from EFS

- **Access Mode**: EBS volumes use `ReadWriteOnce` (single node access)
- **Volume Binding**: Uses `WaitForFirstConsumer` for proper AZ placement
- **File System**: Uses ext4 file system
- **Performance**: Configurable IOPS and throughput for gp3 volumes
- **Encryption**: Supports encryption at rest

## Testing

After deployment, test the storage:

```bash
# Check pod status
kubectl get pod nginx-ebs-dynamic-pod

# Test web server
kubectl port-forward service/nginx-ebs-dynamic-service 8083:80

# Check volume mount
kubectl exec nginx-ebs-dynamic-pod -- df -h /usr/share/nginx/html

# View content
kubectl exec nginx-ebs-dynamic-pod -- cat /usr/share/nginx/html/index.html
```

## Cleanup

```bash
kubectl delete -f dynamic-nginx-service.yaml
kubectl delete -f dynamic-nginx-pod.yaml
kubectl delete -f dynamic-persistent-volume-claim.yaml
kubectl delete -f dynamic-storage-class.yaml
```

## Storage Class Parameters

The dynamic storage class includes:
- `type: gp3` - General Purpose SSD v3
- `fsType: ext4` - File system type
- `encrypted: "true"` - Encryption enabled
- `iops: "3000"` - Baseline IOPS
- `throughput: "125"` - Throughput in MiB/s
- `volumeBindingMode: WaitForFirstConsumer` - Ensures proper AZ placement