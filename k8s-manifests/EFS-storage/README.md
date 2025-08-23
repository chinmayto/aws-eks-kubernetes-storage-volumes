# EFS Storage for Kubernetes

This directory contains Kubernetes manifests for using Amazon EFS (Elastic File System) as persistent storage in your EKS cluster with **static volume provisioning**.

## Components Created by Terraform Module

The EFS Terraform module creates:

- **EFS File System**: Encrypted EFS with configurable performance mode
- **EFS Mount Targets**: One per private subnet for high availability
- **Security Group**: Allows NFS traffic (port 2049) from EKS nodes
- **IAM Role**: For EFS CSI driver with pod identity
- **EKS Add-on**: AWS EFS CSI driver for Kubernetes integration

## Kubernetes Manifests

1. **storage-class.yaml**: Defines the EFS storage class for static provisioning
2. **persistent-volume.yaml**: Creates a static PV using the EFS file system
3. **persistent-volume-claim.yaml**: Claims storage from the specific EFS PV
4. **nginx-pod.yaml**: Single nginx pod using EFS storage
5. **nginx-service.yaml**: Service to access the nginx web server
6. **sample-pod.yaml**: Simple pod example with EFS mount (legacy)

## Deployment Steps

### Option 1: Using the Deploy Script

```bash
cd k8s-manifests/EFS-storage
./deploy.sh
```

### Option 2: Manual Deployment

1. **Get EFS values from Terraform**:
   ```bash
   cd infrastructure
   EFS_FILE_SYSTEM_ID=$(terraform output -raw efs_file_system_id)
   ```

2. **Update manifests with EFS values**:
   ```bash
   # Replace placeholder in persistent-volume.yaml (static provisioning only needs file system ID)
   sed -i "s/\${EFS_FILE_SYSTEM_ID}/$EFS_FILE_SYSTEM_ID/g" persistent-volume.yaml
   ```

3. **Apply manifests**:
   ```bash
   kubectl apply -f storage-class.yaml
   kubectl apply -f persistent-volume.yaml
   kubectl apply -f persistent-volume-claim.yaml
   kubectl apply -f nginx-pod.yaml
   kubectl apply -f nginx-service.yaml
   ```

## Verification

Check that everything is working:

```bash
# Check EFS CSI driver pods
kubectl get pods -n kube-system -l app=efs-csi-controller

# Check storage class
kubectl get storageclass efs-sc

# Check persistent volume and claim
kubectl get pv efs-pv
kubectl get pvc efs-pvc

# Check nginx pod
kubectl get pod nginx-efs-pod
kubectl get service nginx-efs-service

# Test nginx web server
kubectl port-forward service/nginx-efs-service 8080:80
# Then visit http://localhost:8080 in your browser

# Test file persistence
kubectl exec -it nginx-efs-pod -- ls -la /usr/share/nginx/html/
```

## Features

- **Static Provisioning**: Pre-created EFS file system with direct mounting
- **Multi-AZ**: EFS mount targets in each availability zone
- **ReadWriteMany**: Multiple pods can read/write simultaneously
- **Persistent**: Data survives pod restarts and rescheduling
- **Scalable**: EFS scales automatically based on usage
- **Secure**: Encrypted at rest and in transit
- **POSIX Compliant**: Full POSIX file system semantics
- **Web Server**: Nginx pod serves content from EFS storage

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

### Debug Commands

```bash
# Check EFS CSI driver logs
kubectl logs -n kube-system -l app=efs-csi-controller

# Describe PVC for events
kubectl describe pvc efs-pvc

# Check pod events
kubectl describe pod <pod-name>
```