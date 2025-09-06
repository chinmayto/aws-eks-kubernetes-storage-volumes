# EBS Storage Manifests

This directory contains Kubernetes manifests for testing EBS (Elastic Block Store) storage with the AWS EBS CSI driver.

## Prerequisites

- EKS cluster with EBS CSI driver addon installed
- kubectl configured to access your cluster
- For static provisioning: Pre-created EBS volume

## Files Overview

### Static Provisioning
- `static-storage-class.yaml` - StorageClass for static EBS volumes (no parameters needed)
- `static-persistent-volume.yaml` - PersistentVolume pointing to existing EBS volume (requires `${EBS_VOLUME_ID}`)
- `static-persistent-volume-claim.yaml` - PersistentVolumeClaim for static volume
- `static-nginx-pod.yaml` - Test pod using static EBS volume
- `static-nginx-service.yaml` - Service to expose the static test pod
- `static-deploy.sh` - Deployment script for static provisioning

### Dynamic Provisioning (Recommended)
- `dynamic-storage-class.yaml` - StorageClass with gp3 volume configuration
  - Volume type: `gp3` (General Purpose SSD v3)
  - File system: `ext4`
  - Encryption: enabled
  - IOPS: 3000 baseline
  - Throughput: 125 MiB/s
  - Volume binding: `WaitForFirstConsumer` (ensures proper AZ placement)
- `dynamic-persistent-volume-claim.yaml` - PVC for dynamic volume creation
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

## Key Differences from EFS and S3

- **Access Mode**: EBS volumes use `ReadWriteOnce` (single node access only)
- **Volume Binding**: Uses `WaitForFirstConsumer` for proper AZ placement
- **File System**: Uses ext4 file system
- **Performance**: Configurable IOPS (3000) and throughput (125 MiB/s) for gp3 volumes
- **Encryption**: Supports encryption at rest (enabled by default)
- **Capacity**: Fixed size volumes (expandable with `allowVolumeExpansion: true`)
- **Provisioning**: Both static and dynamic provisioning supported

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

## Troubleshooting

### Common Issues

1. **Pod stuck in Pending**: Check if EBS CSI driver is running and PVC is bound
2. **Volume attachment failures**: Verify EBS volume is in the same AZ as the node
3. **Permission denied**: Check file system permissions and security context
4. **Volume not found**: Verify EBS volume ID exists and is available

### Issue: Pod fails with "Volume not found" error

This indicates the EBS volume doesn't exist or isn't accessible. Solutions:

1. **Verify EBS volume exists**:
   ```bash
   aws ec2 describe-volumes --volume-ids <volume-id>
   ```

2. **Check volume availability zone**:
   ```bash
   kubectl get nodes --show-labels | grep topology.kubernetes.io/zone
   ```

3. **Ensure volume is available**:
   ```bash
   aws ec2 describe-volumes --volume-ids <volume-id> --query 'Volumes[0].State'
   ```

### Issue: PVC stuck in Pending state

1. **Check EBS CSI driver status**:
   ```bash
   kubectl get pods -n kube-system -l app=ebs-csi-controller
   ```

2. **Check PVC events**:
   ```bash
   kubectl describe pvc <pvc-name>
   ```

3. **Verify storage class**:
   ```bash
   kubectl describe storageclass <storage-class-name>
   ```

### Issue: Dynamic provisioning fails

1. **Check IAM permissions for EBS CSI driver**:
   ```bash
   kubectl describe sa ebs-csi-controller-sa -n kube-system
   ```

2. **Verify EBS CSI driver logs**:
   ```bash
   kubectl logs -n kube-system -l app=ebs-csi-controller
   ```

3. **Check node capacity and limits**:
   ```bash
   kubectl describe node <node-name>
   ```

## Storage Class Configuration

### Dynamic Storage Class (`ebs-dynamic-sc`)
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-dynamic-sc
provisioner: ebs.csi.aws.com
parameters:
  type: gp3                    # General Purpose SSD v3
  fsType: ext4                 # File system type
  encrypted: "true"            # Encryption enabled
  iops: "3000"                 # Baseline IOPS
  throughput: "125"            # Throughput in MiB/s
volumeBindingMode: WaitForFirstConsumer  # Ensures proper AZ placement
allowVolumeExpansion: true     # Allows volume expansion
reclaimPolicy: Delete          # Deletes volume when PVC is deleted
```

### Static Storage Class (`ebs-static-sc`)
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-static-sc
provisioner: ebs.csi.aws.com
# No parameters needed for static provisioning
```