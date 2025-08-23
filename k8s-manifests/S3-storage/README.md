# S3 Storage Demo with Nginx

This folder contains Kubernetes manifests to demonstrate using S3 as storage for an nginx pod using the AWS Mountpoint S3 CSI Driver with EKS Pod Identity.

## Prerequisites

1. EKS cluster with AWS Mountpoint S3 CSI Driver addon installed
2. S3 bucket created and configured via Terraform
3. IAM roles and Pod Identity associations configured via Terraform
4. StorageClass `s3-csi` configured

## Files Overview

- `storage-class.yaml` - StorageClass for S3 CSI driver
- `service-account.yaml` - ServiceAccount for Pod Identity (deployed in kube-system namespace)
- `persistent-volume-claim.yaml` - PVC using S3 CSI driver
- `nginx-pod.yaml` - Simple nginx pod with S3 storage mounted
- `nginx-service.yaml` - ClusterIP service to expose nginx
- `deploy.sh` - Automated deployment script

## Deployment Steps

### 1. Update StorageClass Configuration

Before deploying, update the bucket name in `storage-class.yaml`:

```bash
# Replace YOUR_BUCKET_NAME with your actual S3 bucket name
sed -i 's/YOUR_BUCKET_NAME/your-actual-bucket-name/g' storage-class.yaml
```

### 2. Deploy the manifests

Option A - Use the automated script:
```bash
./deploy.sh
```

Option B - Deploy manually:
```bash
# Update bucket name in storage class
sed -i 's/YOUR_BUCKET_NAME/your-actual-bucket-name/g' storage-class.yaml

# Deploy in order
kubectl apply -f storage-class.yaml
kubectl apply -f service-account.yaml
kubectl apply -f persistent-volume-claim.yaml
kubectl apply -f nginx-pod.yaml
kubectl apply -f nginx-service.yaml

# Wait for pod to be ready
kubectl wait --for=condition=Ready --timeout=300s pod/nginx-s3
```

### 3. Verify the deployment

```bash
# Check pod status
kubectl get pod nginx-s3

# Check PVC status
kubectl get pvc s3-pvc

# Check service
kubectl get svc nginx-s3-service

# Check service account in kube-system
kubectl get sa s3-csi-driver-sa -n kube-system
```

### 4. Test the application

```bash
# Port forward to test locally
kubectl port-forward svc/nginx-s3-service 8080:80

# Open browser to http://localhost:8080
# Or use curl
curl http://localhost:8080
```

## Features Demonstrated

1. **S3 as Filesystem**: S3 bucket mounted as a POSIX-like filesystem
2. **EKS Pod Identity**: Modern authentication using Pod Identity instead of IRSA
3. **Simple Pod**: Single nginx pod with integrated content creation
4. **High Performance**: Direct S3 access through Mountpoint
5. **Content Serving**: Nginx serves HTML content stored in S3
6. **Automated Deployment**: Script handles Terraform integration

## Troubleshooting

### Check pod logs
```bash
kubectl logs nginx-s3
```

### Check CSI driver logs
```bash
kubectl logs -l app=aws-mountpoint-s3-csi-driver -n kube-system
```

### Verify S3 permissions
```bash
kubectl exec -it nginx-s3 -- ls -la /usr/share/nginx/html
```

### Check PVC events
```bash
kubectl describe pvc s3-pvc
```

### Verify Pod Identity association
```bash
kubectl describe sa s3-csi-driver-sa -n kube-system
```

## Cleanup

```bash
kubectl delete -f .
```

## Notes

- The S3 CSI driver provides read-write access to S3 buckets
- Files written to the mounted filesystem appear in the S3 bucket
- Simple nginx setup serving content from S3
- Uses EKS Pod Identity for authentication (modern approach)
- The service account is created in the kube-system namespace as required by Pod Identity
- Sample content is created automatically when the pod starts
- Pod Identity associations are managed by Terraform infrastructure
- The deploy.sh script automatically gets the S3 bucket name from Terraform outputs