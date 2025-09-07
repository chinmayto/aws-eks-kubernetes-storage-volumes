# Implementing Amazon EFS Storage with EKS using Terraform and Kubernetes Manifests

In this blog, we will walk through how to integrate Amazon Elastic File System (EFS) with Amazon Elastic Kubernetes Service (EKS) using Terraform for infrastructure provisioning and Kubernetes manifests for workloads.

As a demo, we will deploy an NGINX container that uses EFS-backed storage to persist and serve website files. This approach is common for workloads that require shared storage across multiple pods.

## Understanding Amazon EFS for Kubernetes
### What is Amazon EFS?

Amazon Elastic File System (EFS) is a fully managed, scalable, and serverless network file system that can be mounted concurrently by multiple EC2 instances, Lambda functions, and Kubernetes pods.

For Kubernetes workloads, EFS provides persistent volumes that can be shared across multiple pods, even across Availability Zones (AZs) in a VPC.

### Key Benefits for EKS

- **Shared storage**: Multiple pods can read and write simultaneously.
- **Elastic scaling**: Automatically grows and shrinks with demand.
- **Multi-AZ access**: Ensures high availability across EKS worker nodes.
- **Use cases**: Content management, logs aggregation, web apps, home directories.

### Important Considerations with EKS

- **Kubernetes version**: Ensure you are using a supported version (v1.23+ recommended).
- **EFS CSI driver**: Must be installed in the cluster to enable storage integration.
- **Pod Identity/IRSA**: Required to grant fine-grained IAM permissions.
- **Performance**: Suitable for general-purpose and throughput-heavy workloads, but not ideal for low-latency databases.
- **Quotas**: File system size and performance modes must be considered when designing workloads.

## Step 1: Provisioning EKS Cluster with Terraform in a VPC

The first step in integrating Amazon EFS with EKS is to provision a Kubernetes cluster that runs securely inside a dedicated VPC. We will use the widely adopted AWS Terraform community modules for both the VPC and EKS setup. Please refer to main module of GitHub repo.

## Step 2: Creating the EFS File System

- **EFS File System**: Encrypted EFS with configurable performance mode
```terraform
####################################################################################
# EFS File System
####################################################################################
resource "aws_efs_file_system" "main" {
  creation_token = "${var.cluster_name}-efs"
  encrypted      = true

  performance_mode = var.performance_mode
  throughput_mode  = var.throughput_mode

  tags = {
    Name        = "${var.cluster_name}-efs"
    Environment = var.environment
    Terraform   = "true"
  }
}
```
- **EFS Mount Targets**: One per private subnet for high availability and EFS access point
```terraform
####################################################################################
# EFS Mount Targets (one per private subnet)
####################################################################################
resource "aws_efs_mount_target" "main" {
  count           = length(var.private_subnet_ids)
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

####################################################################################
# EFS Access Point for Pod
####################################################################################
resource "aws_efs_access_point" "pod_access_point" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = var.posix_user_gid
    uid = var.posix_user_uid
  }

  root_directory {
    path = "/app-data"
    creation_info {
      owner_gid   = var.posix_user_gid
      owner_uid   = var.posix_user_uid
      permissions = "755"
    }
  }

  tags = {
    Name        = "${var.cluster_name}-efs-access-point"
    Environment = var.environment
    Terraform   = "true"
  }
}
```
- **Security Group**: Allows NFS traffic (port 2049) from EKS nodes
```terraform
####################################################################################
# Security Group for EFS
####################################################################################
resource "aws_security_group" "efs" {
  name_prefix = "${var.cluster_name}-efs-"
  vpc_id      = var.vpc_id

  ingress {
    description = "NFS from EKS nodes"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-efs-sg"
    Environment = var.environment
    Terraform   = "true"
  }
}
```
- **IAM Role**: For EFS CSI driver with pod identity
```terraform
####################################################################################
# IAM Role for EFS CSI Driver (Pod Identity)
####################################################################################
resource "aws_iam_role" "efs_csi_driver_role" {
  name = "${var.cluster_name}-efs-csi-driver-role"

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
    Name        = "${var.cluster_name}-efs-csi-driver-role"
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
# Create Custom EFS CSI Driver Policy
####################################################################################
resource "aws_iam_policy" "efs_csi_driver_policy" {
  name        = "${var.cluster_name}-efs-csi-driver-policy"
  description = "Policy for EFS CSI driver"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets",
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:CreateAccessPoint",
          "elasticfilesystem:TagResource"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:DeleteAccessPoint"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "elasticfilesystem:AccessedViaMountTarget" = "true"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-efs-csi-driver-policy"
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
# Attach EFS CSI Driver Policy
####################################################################################
resource "aws_iam_role_policy_attachment" "efs_csi_driver_policy" {
  role       = aws_iam_role.efs_csi_driver_role.name
  policy_arn = aws_iam_policy.efs_csi_driver_policy.arn
}
####################################################################################
# Pod Identity Association for EFS CSI Driver
####################################################################################
resource "aws_eks_pod_identity_association" "efs_csi_driver" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "efs-csi-controller-sa"
  role_arn        = aws_iam_role.efs_csi_driver_role.arn

  tags = {
    Name        = "${var.cluster_name}-efs-csi-pod-identity"
    Environment = var.environment
    Terraform   = "true"
  }
}
```
- **EKS Add-on**: AWS EFS CSI driver for Kubernetes integration
```terraform
####################################################################################
###  EFS CSI Driver Addon (deployed after EFS module)
####################################################################################
resource "aws_eks_addon" "efs_csi_driver" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-efs-csi-driver"

  # Ensure this addon is created after the EFS module creates the IAM role and pod identity association
  depends_on = [module.efs]

  tags = {
    Name        = "${var.cluster_name}-efs-csi-driver"
    Environment = var.environment
    Terraform   = "true"
  }
}
```

## Step 3: EFS Storage Implementation Patterns

### Static Provisioning
In static provisioning, the PersistentVolume (PV) is created manually by the administrator. The PV explicitly points to an existing EFS File System ID and directory.

How it works:
1. You first provision an EFS file system and create mount targets in your VPC.
2. You then define a Kubernetes PersistentVolume (PV) resource that references the EFS File System ID.
3. Applications request storage through a PersistentVolumeClaim (PVC) that binds to this PV.
4. The EFS volume is mounted directly into pods through the PVC.

- `static-storage-class.yaml` - StorageClass for static EFS provisioning (no parameters)
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-static-sc
provisioner: efs.csi.aws.com
# Static provisioning - no parameters needed
```
- `static-persistent-volume.yaml` - PV using existing EFS file system (requires `${EFS_FILE_SYSTEM_ID}`)
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: efs-static-pv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: efs-static-sc
  csi:
    driver: efs.csi.aws.com
    volumeHandle: ${EFS_FILE_SYSTEM_ID}
```
- `static-persistent-volume-claim.yaml` - PVC for static volume
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-static-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-static-sc
  volumeName: efs-static-pv
  resources:
    requests:
      storage: 5Gi
```
- `static-nginx-pod.yaml` - Test pod using static EFS volume
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-efs-static-pod
  namespace: default
  labels:
    app: nginx-efs-static
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
    volumeMounts:
    - name: efs-storage
      mountPath: /usr/share/nginx/html
    env:
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    command: ["/bin/sh"]
    args: ["-c", "echo '<h1>Hello from EFS Static Volume!</h1><p><b>Pod:</b> '$POD_NAME'</p>' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
  volumes:
  - name: efs-storage
    persistentVolumeClaim:
      claimName: efs-static-pvc
```
- `static-nginx-service.yaml` - Service to expose the static test pod
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-efs-static-service
  namespace: default
spec:
  selector:
    app: nginx-efs-static
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
```

### Deployment Steps For Static Provisioning:
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

Refer to `static-deploy.sh` for deployment script for static provisioning

```bash
$ kubectl get sc,pv,pvc
NAME                                         PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
storageclass.storage.k8s.io/efs-static-sc    efs.csi.aws.com         Delete          Immediate              false                  27s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                     STORAGECLASS     VOLUMEATTRIBUTESCLASS   REASON   AGE
persistentvolume/efs-static-pv                              5Gi        RWX            Retain           Bound    default/efs-static-pvc    efs-static-sc    <unset>                          25s

NAME                                    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS     VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/efs-static-pvc    Bound    efs-static-pv                              5Gi        RWX            efs-static-sc    <unset>                 21s
```

EFS Volume:

![alt text](/k8s-manifests/EFS-storage/images/EFS-Volume.png)

Nginx pod accessing EFS for index.html

![alt text](/k8s-manifests/EFS-storage/images/Static-EFS.png)

### Dynamic Provisioning

In dynamic provisioning, Kubernetes automatically creates PersistentVolumes (PVs) as needed, based on a StorageClass that uses the EFS CSI driver. This approach leverages EFS Access Points, which act like sub-directories with their own permissions inside the file system.

How it works:
1. Define a StorageClass that specifies the EFS file system and provisioning mode.
2. When an application requests storage using a PVC, Kubernetes dynamically creates:
  - A new PV backed by an EFS Access Point.
  - A dedicated directory within the EFS filesystem.
  - Pods mount the dynamically provisioned PV through the PVC.


- `dynamic-storage-class.yaml` - StorageClass for dynamic EFS provisioning (requires `${EFS_FILE_SYSTEM_ID}`)
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-dynamic-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: ${EFS_FILE_SYSTEM_ID}
  directoryPerms: "700"
  gidRangeStart: "1000"
  gidRangeEnd: "2000"
  basePath: "/dynamic_provisioning"
allowVolumeExpansion: true
```
- `dynamic-persistent-volume-claim.yaml` - PVC for dynamic volume creation
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-dynamic-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-dynamic-sc
  resources:
    requests:
      storage: 5Gi
```
- `dynamic-nginx-pod.yaml` - Test pod using dynamic EFS volume
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-efs-dynamic-pod
  namespace: default
  labels:
    app: nginx-efs-dynamic
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
    volumeMounts:
    - name: efs-storage
      mountPath: /usr/share/nginx/html
    env:
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    lifecycle:
      postStart:
        exec:
          command: ["/bin/sh", "-c", "echo '<h1>Hello from EFS Dynamic Volume!</h1><p><b>Pod:</b> '$POD_NAME'</p>' > /usr/share/nginx/html/index.html"]
  volumes:
  - name: efs-storage
    persistentVolumeClaim:
      claimName: efs-dynamic-pvc
```
- `dynamic-nginx-service.yaml` - Service to expose the dynamic test pod
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-efs-dynamic-service
  namespace: default
spec:
  selector:
    app: nginx-efs-dynamic
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
```

### Deployment Steps For Dynamic Provisioning:
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

Refer `dynamic-deploy.sh` for deployment script for dynamic provisioning

```bash
$ kubectl get sc,pv,pvc
NAME                                         PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
storageclass.storage.k8s.io/efs-dynamic-sc   efs.csi.aws.com         Delete          Immediate              true                   14m

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                     STORAGECLASS     VOLUMEATTRIBUTESCLASS   REASON   AGE
persistentvolume/pvc-c07eb431-8060-4e19-8fd6-7166e816c4d9   5Gi        RWX            Delete           Bound    default/efs-dynamic-pvc   efs-dynamic-sc   <unset>                          14m

NAME                                    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS     VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/efs-dynamic-pvc   Bound    pvc-c07eb431-8060-4e19-8fd6-7166e816c4d9   5Gi        RWX            efs-dynamic-sc   <unset>                 14m
```

Nginx pod accessing EFS for index.html:

![alt text](/k8s-manifests/EFS-storage/images/Dynamic-EFS.png)

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
# Then visit http://localhost:8080

kubectl port-forward service/nginx-efs-dynamic-service 8081:80  # Dynamic
# Then visit http://localhost:8081

# Test file persistence
kubectl exec -it nginx-efs-static-pod -- ls -la /usr/share/nginx/html/
kubectl exec -it nginx-efs-dynamic-pod -- ls -la /usr/share/nginx/html/
```

### Cleanup

* Static Provisioning Cleanup
   ```bash
   kubectl delete -f static-nginx-service.yaml
   kubectl delete -f static-nginx-pod.yaml
   kubectl delete -f static-persistent-volume-claim.yaml
   kubectl delete -f static-persistent-volume.yaml
   kubectl delete -f static-storage-class.yaml
   ```

* Dynamic Provisioning Cleanup
   ```bash
   kubectl delete -f dynamic-nginx-service.yaml
   kubectl delete -f dynamic-nginx-pod.yaml
   kubectl delete -f dynamic-persistent-volume-claim.yaml
   kubectl delete -f dynamic-storage-class.yaml
   ```

And then terraform destroy the EKS infrastructure if you are not using it to save costs.

### Conclusion

Amazon EFS with EKS provides a scalable, shared, and highly available storage solution for Kubernetes workloads. Using Terraform, YAML manifests, and the EFS CSI driver, you can seamlessly integrate cloud-native storage with your workloads.

For our demo, we deployed an NGINX container that serves website files from EFS storage. This pattern is widely applicable to web applications, shared logs, and content management systems running on EKS.

### References
- [My GitHub Repo – Full Terraform & YAML Implementation](https://github.com/chinmayto/aws-eks-kubernetes-storage-volumes/tree/main)
- [Amazon EFS CSI Driver Documentation](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html)
