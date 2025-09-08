# Kubernetes Storage Playlist - Part 1: Storage on an Amazon EKS Cluster

When running applications on Kubernetes, storage is one of the most critical aspects to design correctly. Stateless workloads like frontend services can restart or scale up and down without issues, but stateful workloads—such as databases, CMS platforms, or logging systems—require persistent storage to avoid data loss and maintain application reliability.

In this blog, we will:
- Explore the fundamentals of storage in Kubernetes.
- Understand how storage is integrated in Amazon Elastic Kubernetes Service (EKS).
- Discuss three common ways of providing storage for EKS workloads with real-world use cases.

## Storage in Kubernetes

Kubernetes provides an abstraction layer for managing storage. Instead of directly attaching disks or dealing with file systems, developers simply declare the storage requirements in YAML manifests, and Kubernetes takes care of provisioning and attaching the appropriate backend.

The main building blocks are:
### Persistent Volume (PV)

A Persistent Volume represents a piece of storage in the cluster. It can be created manually (static provisioning) or dynamically through a StorageClass. Importantly, PVs exist independently of pod lifecycles, ensuring data durability even if pods are deleted or rescheduled.

### Persistent Volume Claim (PVC)

A Persistent Volume Claim is a request for storage made by a pod. PVCs are workload-facing: developers specify storage size, access mode (ReadWriteOnce, ReadWriteMany), and Kubernetes automatically matches it with a suitable PV.

### StorageClass (SC)

A StorageClass defines the type of storage available in a cluster. Each SC references a provisioner, such as the AWS EBS CSI driver, and includes parameters like volume type (gp3, io1) or throughput. With this abstraction, applications can dynamically request storage without requiring administrators to manually pre-create volumes.

Together, PVs, PVCs, and StorageClasses provide Kubernetes with a consistent, flexible, and declarative way to manage persistent storage.

## Storage on Amazon EKS

Amazon EKS integrates seamlessly with AWS-managed storage backends, giving developers multiple options depending on their workload:

### Amazon Elastic Block Store (EBS)

**What it is**: Block-level storage volumes attached to individual worker nodes.

**Best for**: Single-AZ workloads like relational databases (MySQL, PostgreSQL) or analytics engines.

**Limitation**: EBS volumes are tied to a single Availability Zone (AZ). If pods move to another AZ, the volume cannot follow.

### Amazon Elastic File System (EFS)

**What it is**: A fully managed, elastic, and scalable NFS file system.

**Best for**: Shared file storage across multiple pods or nodes—ideal for CMS platforms, ML training jobs, or CI/CD pipelines.

**Strength**: Multi-AZ support with high availability.

### Amazon S3 (via CSI driver)

**What it is**: Object storage service integrated with Kubernetes using the S3 CSI driver.

**Best for**: Workloads that require scalable object storage such as image hosting, logs, backups, or big data pipelines.

**Note**: S3 is not a traditional file system—apps must handle object semantics rather than block/file operations.

## Patterns for Providing Storage on EKS

The way you provision storage in Kubernetes depends on workload requirements. The two most common patterns are:

### 1. Static Provisioning

- Storage resources (EBS/EFS volumes) are created manually in AWS.
- Administrators then define Kubernetes PersistentVolumes that map to these resources.
- Applications use PVCs to bind to these predefined volumes.

**Benefits**: Full control, predictable allocation.
**Trade-off**: Manual and less scalable.

**Use case**: Migrating an existing database volume into EKS or when strict compliance requires pre-approved resources.

### 2. Dynamic Provisioning

- Uses StorageClasses with CSI drivers (Container Storage Interface).
- When a pod requests a PVC, Kubernetes automatically provisions the corresponding AWS storage resource.
- The binding happens seamlessly without admin intervention.

**Benefits**: Scalable, automated, and reduces operational effort.
**Trade-off**: Less control over specific underlying resources.

**Use case**: Microservices with varying storage needs, where automation and agility are critical.

### Best Practices for Storage on EKS
- Match workload to storage type:
    - Databases → EBS (high IOPS, low latency).
    - Shared applications → EFS (multi-pod access).
    - Logs, archives → S3 (object storage).

- Design for AZ awareness: Keep in mind that EBS volumes are AZ-bound. Use EFS or S3 for multi-AZ workloads.

- Secure access: Use IAM roles for service accounts (IRSA) instead of node roles to provide pods with fine-grained storage permissions.

- Monitor performance: Use CloudWatch metrics for EBS/EFS and S3 to ensure that storage performance matches workload demand.

- Consider costs: EFS and S3 scale automatically but may incur higher costs compared to provisioned EBS volumes.

## Conclusion

Storage is a foundational component of Kubernetes—especially in Amazon EKS, where workloads can leverage AWS-managed services like EBS, EFS, and S3. By combining PVs, PVCs, and StorageClasses, you can provide flexible, resilient, and workload-specific storage without exposing application developers to infrastructure complexity.

With the right storage strategy, your EKS workloads can scale seamlessly while ensuring data durability, performance, and availability.

**Next steps**: In upcoming blogs, we’ll walk through hands-on demos of setting up EBS, EFS, and S3 storage in EKS using Terraform and Kubernetes manifests, including deploying an nginx container that writes to persistent storage.

## References

- [Kubernetes Documentation – Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)  
- [Kubernetes Documentation – Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)  
- [Amazon EKS – Storage](https://docs.aws.amazon.com/eks/latest/userguide/storage.html)  
- [Amazon EBS – Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AmazonEBS.html)  
- [Amazon EFS – Documentation](https://docs.aws.amazon.com/efs/latest/ug/whatisefs.html)  
- [Amazon S3 – Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html)  
- [AWS Container Storage Interface (CSI) Drivers](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html)  
- [Kubernetes CSI – Container Storage Interface](https://kubernetes-csi.github.io/docs/)  
