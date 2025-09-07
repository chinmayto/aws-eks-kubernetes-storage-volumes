# Implementing Amazon EBS Storage with Amazon EKS Using Terraform and Kubernetes Manifests

In this blog, we’ll explore how to integrate Amazon Elastic Block Store (EBS) with Amazon Elastic Kubernetes Service (EKS). We’ll provision an EKS cluster with Terraform, configure the EBS CSI driver, and run an Nginx container that uses EBS storage to persist website files.

This is a practical guide for anyone building stateful workloads on EKS.
## Understanding Amazon EBS for Kubernetes

### What is Amazon EBS?

Amazon Elastic Block Store (EBS) provides persistent block-level storage volumes that can be attached to Amazon EC2 instances. Within Kubernetes, EBS volumes can be exposed to Pods through the EBS CSI (Container Storage Interface) driver, allowing workloads to persist data beyond pod lifecycles.

### Key Benefits for EKS

- **Durability**: Data persists beyond pod restarts.
- **Performance**: Multiple volume types (gp3, io2, st1, etc.) for optimized throughput or IOPS.
- **Elasticity**: Volumes can be resized without downtime.
- **Cost-effectiveness**: Pay only for the storage provisioned.

### Important Considerations with EKS

- EBS volumes are AZ-scoped – a Pod using EBS must run in the same Availability Zone as the volume.
- Requires Kubernetes v1.17+ with CSI driver support.
- Pods requiring EBS must use StatefulSets or carefully scheduled Deployments.
- Resource quotas should be monitored to avoid exhausting storage or hitting API limits.


## Step 1: Provisioning EKS Cluster with Terraform in a VPC

The first step in integrating Amazon EBS with EKS is to provision a Kubernetes cluster that runs securely inside a dedicated VPC. We will use the widely adopted AWS Terraform community modules for both the VPC and EKS setup. Please refer to main module of GitHub repo.

## Step 2: Creating the EFS File System

EBS Storage: Encrypted EBS Storage with optional encryption

```terraform
####################################################################################
# Static EBS Volume for Testing
####################################################################################
resource "aws_ebs_volume" "static_volume" {
  count = var.create_static_volume ? 1 : 0

  availability_zone = var.availability_zones[0]
  size              = var.static_volume_size
  type              = var.ebs_volume_type
  encrypted         = var.ebs_encrypted
  kms_key_id        = var.ebs_kms_key_id

  # Configure IOPS for gp3, io1, io2 volumes
  iops = var.ebs_volume_type == "gp3" || var.ebs_volume_type == "io1" || var.ebs_volume_type == "io2" ? var.ebs_volume_iops : null

  # Configure throughput for gp3 volumes
  throughput = var.ebs_volume_type == "gp3" ? var.ebs_volume_throughput : null

  tags = {
    Name        = "${var.cluster_name}-static-ebs-volume"
    Environment = var.environment
    Terraform   = "true"
    Purpose     = "Static EBS volume for Kubernetes testing"
  }
}

####################################################################################
# KMS Key for EBS Encryption (Optional)
####################################################################################
resource "aws_kms_key" "ebs_encryption" {
  count = var.ebs_kms_key_id == null ? 1 : 0

  description             = "KMS key for EBS volume encryption in ${var.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "${var.cluster_name}-ebs-encryption-key"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_kms_alias" "ebs_encryption" {
  count = var.ebs_kms_key_id == null ? 1 : 0

  name          = "alias/${var.cluster_name}-ebs-encryption"
  target_key_id = aws_kms_key.ebs_encryption[0].key_id
}
```

IAM Role: For EFS CSI driver with pod identity
```terraform
####################################################################################
# IAM Role for EBS CSI Driver (Pod Identity)
####################################################################################
resource "aws_iam_role" "ebs_csi_driver_role" {
  name = "${var.cluster_name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-ebs-csi-driver-role"
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
# Create Custom EBS CSI Driver Policy
####################################################################################
resource "aws_iam_policy" "ebs_csi_driver_policy" {
  name        = "${var.cluster_name}-ebs-csi-driver-policy"
  description = "Policy for EBS CSI driver"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:ModifyVolume",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumesModifications"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = [
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:snapshot/*"
        ]
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = [
              "CreateVolume",
              "CreateSnapshot"
            ]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteTags"
        ]
        Resource = [
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:snapshot/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:RequestedRegion" = data.aws_region.current.name
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteVolume"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/ebs.csi.aws.com/cluster" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/CSIVolumeSnapshotName" = "*"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-ebs-csi-driver-policy"
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
# Attach EBS CSI Driver Policy
####################################################################################
resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  role       = aws_iam_role.ebs_csi_driver_role.name
  policy_arn = aws_iam_policy.ebs_csi_driver_policy.arn
}

####################################################################################
# Pod Identity Association for EBS CSI Driver
####################################################################################
resource "aws_eks_pod_identity_association" "ebs_csi_driver" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi_driver_role.arn

  tags = {
    Name        = "${var.cluster_name}-ebs-csi-pod-identity"
    Environment = var.environment
    Terraform   = "true"
  }
}
```

EKS Add-on: AWS EFS CSI driver for Kubernetes integration
```terraform
####################################################################################
###  EBS CSI Driver Addon (deployed after EBS module)
####################################################################################
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-ebs-csi-driver"

  # Ensure this addon is created after the EBS module creates the IAM role and pod identity association
  depends_on = [module.ebs]

  tags = {
    Name        = "${var.cluster_name}-ebs-csi-driver"
    Environment = var.environment
    Terraform   = "true"
  }
}
```
## Step 3: EBS Storage Implementation Patterns

### Static Provisioning
In static provisioning, the PersistentVolume (PV) is created manually by the administrator. The PV explicitly points to an existing EBS volume ID and directory.

How it works:

1. You first provision an EBS Volume using Terraform/CLI.
2. You then define a Kubernetes PersistentVolume (PV) resource that references the EBS Volume ID.
3. Then youcreate a PersistentVolumeClaim (PVC) that requests storage matching the PV’s specifications.
4. Deploy your Pod (e.g., Nginx) and mount the PVC as a volume to store files.

- `static-storage-class.yaml` - StorageClass for static EBS volumes (no parameters needed)
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-static-sc
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```
- `static-persistent-volume.yaml` - PersistentVolume pointing to existing EBS volume (requires `${EBS_VOLUME_ID}`)
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ebs-static-pv
spec:
  capacity:
    storage: 10Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ebs-static-sc
  csi:
    driver: ebs.csi.aws.com
    volumeHandle: ${EBS_VOLUME_ID}
    fsType: ext4
```
- `static-persistent-volume-claim.yaml` - PersistentVolumeClaim for static volume
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ebs-static-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ebs-static-sc
  volumeName: ebs-static-pv
  resources:
    requests:
      storage: 10Gi
```
- `static-nginx-pod.yaml` - Test pod using static EBS volume
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-ebs-static-pod
  namespace: default
  labels:
    app: nginx-ebs-static
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
    volumeMounts:
    - name: ebs-storage
      mountPath: /usr/share/nginx/html
    env:
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    command: ["/bin/sh"]
    args: ["-c", "echo '<h1>Hello from EBS Static Volume!</h1><p><b>Pod:</b> '$POD_NAME'</p>' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
  volumes:
  - name: ebs-storage
    persistentVolumeClaim:
      claimName: ebs-static-pvc
```
- `static-nginx-service.yaml` - Service to expose the static test pod
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-ebs-static-service
  namespace: default
  labels:
    app: nginx-ebs-static
spec:
  selector:
    app: nginx-ebs-static
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
```

### Deployment Steps For Static Provisioning:

1. Get EBS values from Terraform:
```bash
cd infrastructure
EBS_VOLUME_ID=$(terraform output -raw ebs_volume_id 2>/dev/null || echo "")
```
2. Update manifests with EFS values:
```bash
sed "s/\${EBS_VOLUME_ID}/$EBS_VOLUME_ID/g" static-persistent-volume.yaml > static-persistent-volume-final.yaml
```
3. Apply static manifests:
```bash
kubectl apply -f static-storage-class.yaml
kubectl apply -f static-persistent-volume-final.yaml
kubectl apply -f static-persistent-volume-claim.yaml
kubectl apply -f static-nginx-pod.yaml
kubectl apply -f static-nginx-service.yaml
```

Refer to `static-deploy.sh` for deployment script for static provisioning

### Dynamic Provisioning (Recommended)

In dynamic provisioning, Kubernetes automatically creates EBS volumes on demand using the EBS CSI driver and a StorageClass.

How it works:

1. Define a StorageClass that specifies the EBS Volume (e.g., gp3 type, retention policy, binding mode)..
2. When an application requests storage using a PVC, Kubernetes dynamically creates:
   - A new PV backed by a new EBS volume
   - Pods mount the dynamically provisioned PV through the PVC.


- `dynamic-storage-class.yaml` - StorageClass with gp3 volume configuration
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-dynamic-sc
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"
  iops: "3000"
  throughput: "125"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
```
- `dynamic-persistent-volume-claim.yaml` - PVC for dynamic volume creation
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ebs-dynamic-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ebs-dynamic-sc
  resources:
    requests:
      storage: 10Gi
```
- `dynamic-nginx-pod.yaml` - Test pod using dynamic EBS volume
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-ebs-dynamic-pod
  namespace: default
  labels:
    app: nginx-ebs-dynamic
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
    volumeMounts:
    - name: ebs-storage
      mountPath: /usr/share/nginx/html
    env:
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    lifecycle:
      postStart:
        exec:
          command: ["/bin/sh", "-c", "echo '<h1>Hello from EBS Dynamic Volume!</h1><p><b>Pod:</b> '$POD_NAME'</p>' > /usr/share/nginx/html/index.html"]
  volumes:
  - name: ebs-storage
    persistentVolumeClaim:
      claimName: ebs-dynamic-pvc
```
- `dynamic-nginx-service.yaml` - Service to expose the dynamic test pod
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-ebs-dynamic-service
  namespace: default
  labels:
    app: nginx-ebs-dynamic
spec:
  selector:
    app: nginx-ebs-dynamic
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
```

### Deployment Steps For Dynamic Provisioning:

1. Apply static manifests:
```bash
kubectl apply -f dynamic-storage-class.yaml
kubectl apply -f dynamic-persistent-volume-claim.yaml
kubectl apply -f dynamic-nginx-pod.yaml
kubectl apply -f dynamic-nginx-service.yaml
```

Refer to `dynamic-deploy.sh` for deployment script for dynamic provisioning

### Verification

Check that everything is working:

```bash
# Check EFS CSI driver pods
kubectl get pods -n kube-system -l app=efs-csi-controller

# Check storage classes
kubectl get storageclass ebs-sc

# For Static Provisioning:
kubectl get pv ebs-static-pv
kubectl get pvc ebs-static-pvc
kubectl get pod nginx-ebs-static
kubectl get service nginx-ebs-static-service

# For Dynamic Provisioning:
kubectl get pvc ebs-dynamic-pvc
kubectl get pod nginx-ebs-dynamic
kubectl get service nginx-ebs-dynamic-service

# Check volume mount
kubectl exec nginx-ebs-static-pod -- df -h /usr/share/nginx/html
kubectl exec nginx-ebs-dynamic-pod -- df -h /usr/share/nginx/html

# View content
kubectl exec nginx-ebs-static-pod -- cat /usr/share/nginx/html/index.html
kubectl exec nginx-ebs-dynamic-pod -- cat /usr/share/nginx/html/index.html

# Test nginx web servers
kubectl port-forward service/nginx-ebs-static-service 8082:80   # Static
kubectl port-forward service/nginx-ebs-dynamic-service 8083:80  # Dynamic
```

## Cleanup

- Static Provisioning Cleanup
```bash
kubectl delete -f static-storage-class.yaml
kubectl delete -f static-persistent-volume-final.yaml
kubectl delete -f static-persistent-volume-claim.yaml
kubectl delete -f static-nginx-pod.yaml
kubectl delete -f static-nginx-service.yaml
```

- Dynamic Provisioning Cleanup

```bash
kubectl delete -f dynamic-nginx-service.yaml
kubectl delete -f dynamic-nginx-pod.yaml
kubectl delete -f dynamic-persistent-volume-claim.yaml
kubectl delete -f dynamic-storage-class.yaml
```

And then terraform destroy the EKS infrastructure if you are not using it to save costs.

### Conclusion

Amazon EBS provides reliable block storage for stateful workloads on Amazon EKS. Using Terraform for infrastructure provisioning and Kubernetes manifests for storage configuration gives you both automation and flexibility. With proper setup of IAM roles, CSI drivers, and best practices, you can run workloads like Nginx with persistent storage on EKS confidently.

### References
- [My GitHub Repo – Full Terraform & YAML Implementation](https://github.com/chinmayto/aws-eks-kubernetes-storage-volumes/tree/main)
- [Amazon EBS CSI Driver Documentation](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)
