# Kubernetes Storage Playlist - Part 4: Implementing Amazon S3 Storage with EKS using Terraform and and Kubernetes Manifests

In this blog, we’ll explore how to integrate Amazon S3 as a storage solution with Amazon EKS using Terraform and Kubernetes YAML manifests. We will run a simple Nginx container that serves website files stored in an S3 bucket.

This approach leverages the Mountpoint for S3 CSI driver, which provides Kubernetes workloads access to Amazon S3 objects using standard POSIX interfaces.

## Understanding Amazon S3 for Kubernetes
### What is Amazon S3?

Amazon Simple Storage Service (Amazon S3) is an object storage service designed for scalability, durability, and availability. Unlike traditional block storage (like EBS) or file storage (like EFS), S3 stores data as objects inside buckets, which makes it ideal for static content, logs, and backups.

### Architecture Diagram

The architecture of attaching Amazon S3 storage to an EKS cluster revolves around the S3 CSI (Container Storage Interface) driver and the Mountpoint for S3 integration. 

At the base layer, an S3 bucket acts as the backend object store where application data is kept. Inside Kubernetes, a StorageClass defines how storage is provisioned and consumed. With S3, however, only static provisioning is currently supported—meaning a PersistentVolume (PV) must be manually created and mapped to an existing S3 bucket, and then a PersistentVolumeClaim (PVC) binds to that PV so workloads can access it. 

Once a pod is deployed, Kubernetes mounts the PVC to the container’s filesystem through the S3 CSI driver, which internally uses Mountpoint for S3 to provide file system-like access to objects in the bucket. 

While dynamic provisioning—where PVCs automatically trigger creation of new storage volumes—is common for drivers like EBS and EFS, it is not yet available for S3. This makes static provisioning the only option, requiring administrators to pre-define the mapping between PVs and S3 buckets. Security is handled through IAM Roles for Service Accounts (IRSA), ensuring pods have only the minimum required permissions to access specific S3 buckets.

![alt text](/k8s-manifests/S3-storage/images/EKS%20S3%20Architecture.png)

Key Benefits of Using S3 with EKS
- Scalability: Virtually unlimited storage capacity.
- Durability: 11 9’s durability guarantees.
- Cost-Effective: Pay for what you use with no upfront provisioning.
- Integration: Easy integration with AWS services like Athena, Glue, and CloudFront.

Important Considerations for EKS
- CSI Driver Requirements: The Mountpoint for S3 CSI driver must be installed.
- Pod Identity Support: Currently, IRSA (IAM Roles for Service Accounts) is required. Pod Identity is not supported yet.
- Limitations: Only static provisioning is supported as of now. Dynamic provisioning is on the roadmap.
- Resource Quotas: Watch for limits like open file descriptors and network throughput when scaling workloads.


## Step 1: Provisioning EKS Cluster with Terraform in a VPC

The first step in integrating Amazon S3 with EKS is to provision a Kubernetes cluster that runs securely inside a dedicated VPC. We will use the widely adopted AWS Terraform community modules for both the VPC and EKS setup. Please refer to main module of GitHub repo.

## Step 2: Creating the S3 bucket

- **S3 Bucket**: Encrypted S3 bucket with versioning and permissions

```terraform
####################################################################################
# S3 Bucket for Kubernetes Storage
####################################################################################
resource "aws_s3_bucket" "main" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
# S3 Bucket Versioning
####################################################################################
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Disabled"
  }
}

####################################################################################
# S3 Bucket Encryption
####################################################################################
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

####################################################################################
# S3 Bucket Public Access Block
####################################################################################
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

- **IAM Role**: For Mountpoint for S3 CSI Driver

```terraform
####################################################################################
# IAM Role for S3 CSI Driver (IRSA)
####################################################################################
resource "aws_iam_role" "s3_csi_driver_role" {
  name = "${var.cluster_name}-s3-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:s3-csi-driver-sa"
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-s3-csi-driver-role"
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
# S3 CSI Driver Policy (Based on AWS Documentation)
####################################################################################
resource "aws_iam_policy" "s3_csi_driver_policy" {
  name        = "${var.cluster_name}-s3-csi-driver-policy"
  description = "IAM policy for S3 CSI Driver based on AWS documentation"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.main.arn}/*"
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-s3-csi-driver-policy"
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
# Attach S3 CSI Driver Policy
####################################################################################
resource "aws_iam_role_policy_attachment" "s3_csi_driver_policy" {
  role       = aws_iam_role.s3_csi_driver_role.name
  policy_arn = aws_iam_policy.s3_csi_driver_policy.arn
}
```

- **Mountpoint for S3 Add-on**: AWS Mountpoint for S3 CSI Driver for Kubernetes integration
```terraform
####################################################################################
###  S3 Mountpoint CSI Driver Addon (deployed after S3 module)
####################################################################################
resource "aws_eks_addon" "s3_mountpoint_csi_driver" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-mountpoint-s3-csi-driver"
  service_account_role_arn = module.s3.s3_csi_driver_role_arn
  # Using IRSA for CSI driver, Pod Identity for application pods

  # Ensure this addon is created after the S3 module creates the IAM role and pod identity association
  depends_on = [module.s3]

  tags = {
    Name        = "${var.cluster_name}-s3-mountpoint-csi-driver"
    Environment = var.environment
    Terraform   = "true"
  }
}
```

## Step 3: S3 Storage Implementation Patterns

Since only static provisioning is supported for S3 today, we’ll define PersistentVolumes (PV) that reference an S3 bucket.

- `storage-class.yaml` - StorageClass for S3 CSI driver (requires `${S3_BUCKET_NAME}` placeholder)
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: s3-csi-sc
provisioner: s3.csi.aws.com
parameters:
  bucketName: ${S3_BUCKET_NAME}
  prefix: "k8s-storage/"
volumeBindingMode: Immediate
allowVolumeExpansion: false
```
- `persistent-volume.yaml` - PersistentVolume for S3 bucket (static provisioning only)
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: s3-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteManyv
  persistentVolumeReclaimPolicy: Retain
  storageClassName: s3-csi-sc
  csi:
    driver: s3.csi.aws.com
    volumeHandle: s3-csi-driver-volume
    volumeAttributes:
      bucketName: ${S3_BUCKET_NAME}
      prefix: "k8s-storage/"
```
- `persistent-volume-claim.yaml` - PVC using S3 CSI driver
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: s3-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: s3-csi-sc
  resources:
    requests:
      storage: 1Gi
```
- `nginx-pod.yaml` - Nginx pod with S3 storage mounted and content creation
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-s3-pod
  namespace: default
  labels:
    app: nginx-s3
spec:
  securityContext:
    runAsUser: 0
    runAsGroup: 0
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
    env:
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    command: ["/bin/sh", "-c"]
    args:
    - |
      echo '<h1>Hello from S3 Mountpoint!</h1><p><b>Pod:</b> '$POD_NAME'</p>' > /usr/share/nginx/html/index.html || true
      sed -i 's/user  nginx;/user  root;/' /etc/nginx/nginx.conf
      nginx -g 'daemon off;'
    volumeMounts:
    - name: s3-storage
      mountPath: /usr/share/nginx/html
  volumes:
  - name: s3-storage
    persistentVolumeClaim:
      claimName: s3-pvc
```
- `nginx-service.yaml` - ClusterIP service to expose nginx on port 80
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-s3-service
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: nginx-s3
```

### Deployment Steps For Static Provisioning:

1. Get S3 bucket name from Terraform:
```bash
cd infrastructure
S3_BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
```

2. Update manifests with S3 values:
```bash
sed "s/\${S3_BUCKET_NAME}/$S3_BUCKET_NAME/g" storage-class.yaml > storage-class-final.yaml

sed "s/\${S3_BUCKET_NAME}/$S3_BUCKET_NAME/g" persistent-volume.yaml > persistent-volume-final.yaml
```

3. Apply manifests:
```bash
kubectl apply -f storage-class-final.yaml
kubectl apply -f persistent-volume-final.yaml
kubectl apply -f persistent-volume-claim.yaml
kubectl apply -f nginx-pod.yaml
kubectl apply -f nginx-service.yaml
```

Refer to `deploy.sh` for automated deployment script

```bash
$ kubectl get sc,pv,pvc
NAME                                    PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
storageclass.storage.k8s.io/s3-csi-sc   s3.csi.aws.com          Delete          Immediate              false                  10m

NAME                     CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM            STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
persistentvolume/s3-pv   1Gi        RWX            Retain           Bound    default/s3-pvc   s3-csi-sc      <unset>                          10m

NAME                           STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/s3-pvc   Bound    s3-pv    1Gi        RWX            s3-csi-sc      <unset>                 10m
```

S3 Bucket:

![alt text](/k8s-manifests/S3-storage/images/S3%20Bucket.png)

S3 Bucket Contents:

![alt text](/k8s-manifests/S3-storage/images/S3%20Bucket%20Contents.png)

Nginx pod accessing S3 for index.html

![alt text](/k8s-manifests/S3-storage/images/EKS%20S3%20Storage.png)

## Verification

```bash
# Check S3 CSI driver status:
kubectl get pods -n kube-system -l app=aws-mountpoint-s3-csi-driver

# Check deployment status:
kubectl get pod nginx-s3-pod
kubectl get service nginx-s3-service
kubectl get pvc s3-pvc
kubectl get pv

# Test nginx web server:
kubectl port-forward service/nginx-s3-service 8084:80
# Then visit http://localhost:8084

# Check S3 File Persistence
kubectl exec nginx-s3-pod -- ls -la /usr/share/nginx/html/
kubectl exec nginx-s3-pod -- cat /usr/share/nginx/html/index.html

# Check S3 bucket content:
aws s3 ls s3://$S3_BUCKET_NAME/k8s-storage/
```

## Cleanup

```bash
kubectl delete -f nginx-service.yaml
kubectl delete -f nginx-pod.yaml
kubectl delete -f persistent-volume-claim.yaml
kubectl delete -f persistent-volume.yaml
kubectl delete -f storage-class.yaml
```

And then terraform destroy the EKS infrastructure if you are not using it to save costs.

## Conclusion

Amazon S3 provides a scalable and cost-effective storage solution for workloads running on EKS. With the Mountpoint for S3 CSI driver, Kubernetes pods can directly mount S3 buckets and serve static files seamlessly. While currently limited to static provisioning, this integration is a powerful way to manage object storage in containerized environments.

In this blog, we provisioned an EKS cluster using Terraform, set up IAM roles with IRSA, deployed the S3 CSI driver, and ran an Nginx container backed by S3 storage.

## References

- [My GitHub Repo – Full Terraform & YAML Implementation](https://github.com/chinmayto/aws-eks-kubernetes-storage-volumes/tree/main)
- [AWS Documentation – Mountpoint for S3 CSI Driver](https://docs.aws.amazon.com/eks/latest/userguide/s3-csi.html)