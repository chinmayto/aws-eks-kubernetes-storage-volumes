# S3 Storage Demo with Nginx

This folder contains Kubernetes manifests to demonstrate using S3 as storage for an nginx pod using the AWS Mountpoint S3 CSI Driver with EKS Pod Identity.

## Prerequisites

1. EKS cluster with AWS Mountpoint S3 CSI Driver addon installed
2. S3 bucket created and configured via Terraform
3. IAM roles and Pod Identity associations configured via Terraform
4. Pod Identity agent addon enabled on EKS cluster

## Files Overview

- `storage-class.yaml` - StorageClass for S3 CSI driver (requires `${S3_BUCKET_NAME}` placeholder)
- `persistent-volume.yaml` - PersistentVolume for S3 bucket (static provisioning only)
- `persistent-volume-claim.yaml` - PVC using S3 CSI driver
- `nginx-pod.yaml` - Nginx pod with S3 storage mounted and content creation
- `nginx-service.yaml` - ClusterIP service to expose nginx on port 80
- `deploy.sh` - Automated deployment script with Terraform integration
- `storage-class-final.yaml` - Generated file with actual bucket name (temporary)
- `persistent-volume-final.yaml` - Generated file with actual bucket name (temporary)

## Deployment Steps

### 1. Deploy using the automated script

```bash
./deploy.sh
```

The script will:
- Get the S3 bucket name from Terraform outputs
- Create manifests with the correct bucket name
- Apply all Kubernetes manifests
- Clean up temporary files

### 2. Manual deployment (alternative)

```bash
# Get S3 bucket name from Terraform
cd ../../infrastructure
S3_BUCKET_NAME=$(terraform output -raw s3_bucket_name)
cd ../k8s-manifests/S3-storage

# Create manifests with bucket name
sed "s/\${S3_BUCKET_NAME}/$S3_BUCKET_NAME/g" storage-class.yaml > storage-class-final.yaml
sed "s/\${S3_BUCKET_NAME}/$S3_BUCKET_NAME/g" persistent-volume.yaml > persistent-volume-final.yaml

# Apply manifests
kubectl apply -f storage-class-final.yaml
kubectl apply -f persistent-volume-final.yaml
kubectl apply -f persistent-volume-claim.yaml
kubectl apply -f nginx-pod.yaml
kubectl apply -f nginx-service.yaml

# Clean up
rm storage-class-final.yaml persistent-volume-final.yaml
```

### 3. Verify the deployment

```bash
# Check pod status
kubectl get pod nginx-s3-pod

# Check PVC status
kubectl get pvc s3-pvc

# Check service
kubectl get svc nginx-s3-service

# Check application service account
kubectl get sa s3-app-sa

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod/nginx-s3-pod --timeout=120s
```

### 4. Test the application

```bash
# Port forward to test locally
kubectl port-forward svc/nginx-s3-service 8084:80

# Open browser to http://localhost:8084
# Or use curl
curl http://localhost:8084
```

## Pod Configuration

The nginx pod (`nginx-s3-pod`) includes:
- **Security Context**: Runs as root (UID/GID 0) for S3 Mountpoint compatibility
- **Content Creation**: Automatically creates `index.html` with pod identification
- **Nginx Configuration**: Modified to run as root user
- **Volume Mount**: S3 storage mounted at `/usr/share/nginx/html`
- **Service Account**: Uses default service account (Pod Identity handles S3 access)
- **Port**: Exposes port 80 for HTTP traffic

## Features Demonstrated

1. **S3 as Filesystem**: S3 bucket mounted as a POSIX-like filesystem using Mountpoint S3 CSI driver
2. **EKS Pod Identity**: Modern authentication using Pod Identity instead of IRSA
3. **Static Provisioning**: Uses PersistentVolume for S3 bucket access (dynamic not supported)
4. **Content Creation**: Nginx pod automatically creates sample HTML content on startup
5. **High Performance**: Direct S3 access through AWS Mountpoint for S3
6. **Content Serving**: Nginx serves HTML content stored directly in S3
7. **Automated Deployment**: Script handles Terraform integration and placeholder replacement
8. **ReadWriteMany**: Multiple pods can access the same S3 bucket simultaneously
9. **Unlimited Capacity**: S3 provides virtually unlimited storage capacity

## Troubleshooting

### Check pod logs
```bash
kubectl logs nginx-s3-pod
```

### Check CSI driver logs
```bash
kubectl logs -l app=aws-mountpoint-s3-csi-driver -n kube-system
```

### Verify S3 permissions
```bash
kubectl exec -it nginx-s3-pod -- ls -la /usr/share/nginx/html
```

### Check PVC events
```bash
kubectl describe pvc s3-pvc
```

### Verify Pod Identity associations
```bash
# Check CSI driver service account
kubectl describe sa s3-csi-driver-sa -n kube-system

# Check application service account
kubectl describe sa s3-app-sa

# List all Pod Identity associations
aws eks list-pod-identity-associations --cluster-name $(kubectl config current-context | cut -d'/' -f2)
```

### Common Issues and Solutions

#### Issue: Pod fails with "Forbidden: User: arn:aws:sts::xxx:assumed-role/xxx-node-group-xxx is not authorized"

This indicates the S3 CSI driver is using the node group role instead of Pod Identity. Solutions:

1. **Apply updated Terraform configuration**:
   ```bash
   cd ../../infrastructure
   terraform apply
   ```

2. **Restart CSI driver pods**:
   ```bash
   kubectl rollout restart daemonset/aws-mountpoint-s3-csi-driver -n kube-system
   ```

3. **Verify service account is applied**:
   ```bash
   kubectl get sa s3-csi-driver-sa -n kube-system
   ```

### Issue: PVC stuck in Pending state

1. **Check CSI driver status**:
   ```bash
   kubectl get pods -n kube-system -l app=aws-mountpoint-s3-csi-driver
   ```

2. **Check PVC events**:
   ```bash
   kubectl describe pvc s3-pvc
   ```

3. **Verify bucket name in PV**:
   ```bash
   kubectl describe pv s3-pv
   ```

### Issue: Pod fails to mount S3 bucket

1. **Check Pod Identity associations**:
   ```bash
   aws eks list-pod-identity-associations --cluster-name <cluster-name>
   ```

2. **Verify S3 bucket permissions**:
   ```bash
   aws s3 ls s3://<bucket-name>/
   ```

3. **Check CSI driver logs**:
   ```bash
   kubectl logs -l app=aws-mountpoint-s3-csi-driver -n kube-system
   ```

### Issue: Files not appearing in S3 bucket

1. **Check mount path permissions**:
   ```bash
   kubectl exec -it nginx-s3-pod -- ls -la /usr/share/nginx/html/
   ```

2. **Verify S3 prefix configuration**:
   ```bash
   kubectl describe pv s3-pv
   ```

3. **Test file creation**:
   ```bash
   kubectl exec -it nginx-s3-pod -- touch /usr/share/nginx/html/test.txt
   aws s3 ls s3://<bucket-name>/k8s-storage/
   ```

## Cleanup

```bash
kubectl delete -f nginx-service.yaml
kubectl delete -f nginx-pod.yaml
kubectl delete -f persistent-volume-claim.yaml
kubectl delete -f persistent-volume.yaml
kubectl delete -f storage-class.yaml
```

Or delete all at once:
```bash
kubectl delete -f .
```

## Notes

- The S3 CSI driver provides read-write access to S3 buckets
- Files written to the mounted filesystem appear in the S3 bucket
- Simple nginx setup serving content from S3
- Uses EKS Pod Identity for authentication (modern approach)
- Application components are deployed in the default namespace
- S3 access uses Pod Identity for secure, pod-level authentication
- Separate IAM roles for S3 CSI driver and application pods
- Sample content is created automatically when the pod starts
- Pod Identity associations are managed by Terraform infrastructure
- The deploy.sh script automatically gets the S3 bucket name from Terraform outputs
- **Important**: After updating Terraform IAM policies, restart CSI driver pods for changes to take effect
- The S3 CSI driver service account must be created in the kube-system namespace
- Enhanced IAM policies include IRSA-compatible permissions for better compatibility

## Architecture

- **S3 CSI Driver**: Managed by EKS addon with Pod Identity association
- **Application Pods**: Use `s3-app-sa` service account in `default` namespace  
- **Pod Identity**: Service account has IAM role with appropriate S3 permissions
- **Static Provisioning**: PersistentVolume manually defines S3 bucket access
- **Security**: No node-level S3 permissions required, all access is pod-scoped

## Storage Configuration

### S3 Storage Class (`s3-csi-sc`)
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: s3-csi-sc
provisioner: s3.csi.aws.com
parameters:
  bucketName: ${S3_BUCKET_NAME}    # Replaced by deploy script
  prefix: "k8s-storage/"           # Optional prefix for organization
volumeBindingMode: Immediate       # Immediate binding
allowVolumeExpansion: false        # S3 doesn't need expansion
```

### S3 Persistent Volume (`s3-pv`)
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: s3-pv
spec:
  capacity:
    storage: 1Gi                   # Nominal size (S3 is unlimited)
  accessModes:
    - ReadWriteMany                # Multiple pods can access
  persistentVolumeReclaimPolicy: Retain
  storageClassName: s3-csi-sc
  csi:
    driver: s3.csi.aws.com
    volumeHandle: s3-csi-driver-volume
    volumeAttributes:
      bucketName: ${S3_BUCKET_NAME}  # Actual bucket name
      prefix: "k8s-storage/"
```

## Important Notes

- **Static Provisioning Only**: S3 Mountpoint CSI driver only supports static provisioning
- **Bucket Pre-creation**: S3 bucket must be created via Terraform before deployment
- **Pod Identity**: Uses EKS Pod Identity for secure S3 access (no node-level permissions)
- **Content Persistence**: Files written to mounted path appear directly in S3 bucket
- **Performance**: Optimized for high-throughput workloads with S3 Mountpoint