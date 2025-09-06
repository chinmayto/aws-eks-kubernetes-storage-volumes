# EFS Storage for Kubernetes

This directory contains Kubernetes manifests for using Amazon EFS (Elastic File System) as persistent storage in your EKS cluster with both **static and dynamic volume provisioning**.

## Components Created by Terraform Module

The EFS Terraform module creates:

- **EFS File System**: Encrypted EFS with configurable performance mode
- **EFS Mount Targets**: One per private subnet for high availability
- **Security Group**: Allows NFS traffic (port 2049) from EKS nodes
- **IAM Role**: For EFS CSI driver with pod identity
- **EKS Add-on**: AWS EFS CSI driver for Kubernetes integration

## Kubernetes Manifests

### Static Provisioning
- `static-storage-class.yaml` - StorageClass for static EFS provisioning (no parameters)
- `static-persistent-volume.yaml` - PV using existing EFS file system (requires `${EFS_FILE_SYSTEM_ID}`)
- `static-persistent-volume-claim.yaml` - PVC for static volume
- `static-nginx-pod.yaml` - Test pod using static EFS volume
- `static-nginx-service.yaml` - Service to expose the static test pod
- `static-deploy.sh` - Deployment script for static provisioning

### Dynamic Provisioning
- `dynamic-storage-class.yaml` - StorageClass for dynamic EFS provisioning (requires `${EFS_FILE_SYSTEM_ID}`)
- `dynamic-persistent-volume-claim.yaml` - PVC for dynamic volume creation
- `dynamic-nginx-pod.yaml` - Test pod using dynamic EFS volume
- `dynamic-nginx-service.yaml` - Service to expose the dynamic test pod
- `dynamic-deploy.sh` - Deployment script for dynamic provisioning

## Deployment Steps

### Option 1: Static Provisioning (Using Deploy Script)

```bash
cd k8s-manifests/EFS-storage
chmod +x static-deploy.sh
./static-deploy.sh
```

### Option 2: Dynamic Provisioning (Using Deploy Script)

```bash
cd k8s-manifests/EFS-storage
chmod +x dynamic-deploy.sh
./dynamic-deploy.sh
```

### Option 3: Manual Deployment

#### For Static Provisioning:
1. **Get EFS values from Terraform**:
   ```bash
   cd infrastructure
   EFS_FILE_SYSTEM_ID=$(terraform output -raw efs_file_system_id)
   ```

2. **Update manifests with EFS values**:
   ```bash
   # Replace placeholder in static-persistent-volume.yaml
   sed "s/\${EFS_FILE_SYSTEM_ID}/$EFS_FILE_SYSTEM_ID/g" static-persistent-volume.yaml > static-persistent-volume-final.yaml
   ```

3. **Apply static manifests**:
   ```bash
   kubectl apply -f static-storage-class.yaml
   kubectl apply -f static-persistent-volume-final.yaml
   kubectl apply -f static-persistent-volume-claim.yaml
   kubectl apply -f static-nginx-pod.yaml
   kubectl apply -f static-nginx-service.yaml
   ```

#### For Dynamic Provisioning:
1. **Get EFS values from Terraform**:
   ```bash
   cd infrastructure
   EFS_FILE_SYSTEM_ID=$(terraform output -raw efs_file_system_id)
   ```

2. **Update manifests with EFS values**:
   ```bash
   # Replace placeholder in dynamic-storage-class.yaml
   sed "s/\${EFS_FILE_SYSTEM_ID}/$EFS_FILE_SYSTEM_ID/g" dynamic-storage-class.yaml > dynamic-storage-class-final.yaml
   ```

3. **Apply dynamic manifests**:
   ```bash
   kubectl apply -f dynamic-storage-class-final.yaml
   kubectl apply -f dynamic-persistent-volume-claim.yaml
   kubectl apply -f dynamic-nginx-pod.yaml
   kubectl apply -f dynamic-nginx-service.yaml
   ```

## Verification

Check that everything is working:

```bash
# Check EFS CSI driver pods
kubectl get pods -n kube-system -l app=efs-csi-controller

# Check storage classes
kubectl get storageclass efs-static-sc efs-dynamic-sc

# For Static Provisioning:
kubectl get pv efs-static-pv
kubectl get pvc efs-static-pvc
kubectl get pod nginx-efs-static-pod
kubectl get service nginx-efs-static-service

# For Dynamic Provisioning:
kubectl get pvc efs-dynamic-pvc
kubectl get pod nginx-efs-dynamic-pod
kubectl get service nginx-efs-dynamic-service

# Test nginx web servers
kubectl port-forward service/nginx-efs-static-service 8080:80   # Static
kubectl port-forward service/nginx-efs-dynamic-service 8081:80  # Dynamic

# Test file persistence
kubectl exec -it nginx-efs-static-pod -- ls -la /usr/share/nginx/html/
kubectl exec -it nginx-efs-dynamic-pod -- ls -la /usr/share/nginx/html/
```

## Features

- **Dual Provisioning**: Both static and dynamic provisioning supported
- **Multi-AZ**: EFS mount targets in each availability zone for high availability
- **ReadWriteMany**: Multiple pods can read/write simultaneously
- **Persistent**: Data survives pod restarts and rescheduling
- **Scalable**: EFS scales automatically based on usage (no capacity limits)
- **Secure**: Encrypted at rest and in transit
- **POSIX Compliant**: Full POSIX file system semantics
- **Web Server**: Nginx pods serve content from EFS storage
- **Shared Storage**: Perfect for applications requiring shared file access

## Security

- EFS file system is encrypted at rest
- Security group restricts access to EKS nodes only
- POSIX permissions enforced via access point
- Pod runs with non-root user (UID/GID 1001)
- IAM roles use pod identity for secure access

## Troubleshooting

### Common Issues

1. **Pod stuck in Pending**: Check if EFS CSI driver is running
2. **Mount failures**: Verify security group allows NFS traffic
3. **Permission denied**: Check POSIX user/group settings in access point
4. **DNS resolution**: Ensure VPC has DNS hostnames enabled
5. **PVC stuck in Pending**: Verify EFS file system ID is correct in manifests
6. **Access point creation fails**: Check IAM permissions for EFS CSI driver

### Issue: Pod fails with "Mount failed: mount.nfs: access denied"

This indicates NFS access issues. Solutions:

1. **Check security group rules**:
   ```bash
   # Verify NFS traffic is allowed from EKS nodes
   aws ec2 describe-security-groups --group-ids <efs-security-group-id>
   ```

2. **Verify EFS mount targets**:
   ```bash
   aws efs describe-mount-targets --file-system-id <efs-file-system-id>
   ```

3. **Check EFS CSI driver logs**:
   ```bash
   kubectl logs -n kube-system -l app=efs-csi-controller
   ```

### Issue: Dynamic provisioning creates access point but mount fails

1. **Check access point configuration**:
   ```bash
   aws efs describe-access-points --file-system-id <efs-file-system-id>
   ```

2. **Verify POSIX permissions**:
   ```bash
   kubectl describe pvc <pvc-name>
   ```

3. **Restart EFS CSI driver**:
   ```bash
   kubectl rollout restart daemonset/efs-csi-node -n kube-system
   ```

### Debug Commands

```bash
# Check EFS CSI driver logs
kubectl logs -n kube-system -l app=efs-csi-controller

# Describe PVC for events
kubectl describe pvc efs-pvc

# Check pod events
kubectl describe pod <pod-name>
```

## Cleanup

### Static Provisioning Cleanup
```bash
kubectl delete -f static-nginx-service.yaml
kubectl delete -f static-nginx-pod.yaml
kubectl delete -f static-persistent-volume-claim.yaml
kubectl delete -f static-persistent-volume.yaml
kubectl delete -f static-storage-class.yaml
```

### Dynamic Provisioning Cleanup
```bash
kubectl delete -f dynamic-nginx-service.yaml
kubectl delete -f dynamic-nginx-pod.yaml
kubectl delete -f dynamic-persistent-volume-claim.yaml
kubectl delete -f dynamic-storage-class.yaml
```