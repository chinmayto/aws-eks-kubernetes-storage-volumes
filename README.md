# Storage on Kubernetes: How to Provide Storage on an Amazon EKS Cluster

When running applications on Kubernetes, storage is one of the most critical aspects to design correctly. Stateless workloads can restart at any time without data loss, but for stateful workloads—like databases, CMS platforms, or logging systems—storage persistence is essential.

In this blog, we will:

1. Explore the fundamentals of storage in Kubernetes.
2. Understand how storage is integrated in Amazon Elastic Kubernetes Service (EKS).
3. Discuss three ways of providing storage for EKS workloads.

## Storage in Kubernetes

Kubernetes provides an abstraction layer for managing storage. Applications don’t directly talk to disks or file systems; instead, they declare what kind of storage they need, and Kubernetes provisions or attaches the right storage resource.

The main building blocks are:
### Persistent Volume (PV)
A Persistent Volume is a representation of a storage resource in the cluster. It is provisioned by the administrator (statically) or dynamically created through a storage class. PVs are independent of pod lifecycles, ensuring data durability.

### Persistent Volume Claim (PVC)
A Persistent Volume Claim is a request made by a pod for storage. PVCs abstract away the implementation details of the underlying storage system. The pod only specifies size and access requirements, while Kubernetes finds a matching PV.

### StorageClass (SC)
A StorageClass defines a way to provision storage dynamically. Each SC references a provisioner (such as the AWS EBS CSI driver) and parameters (like disk type). This enables applications to request storage on-demand without pre-creating volumes.

Together, these three concepts allow Kubernetes workloads to consume storage in a consistent and flexible way.


## Storage on Amazon EKS

Amazon EKS integrates seamlessly with AWS-managed storage backends. The most common options are:

1. **Amazon Elastic Block Store (EBS)**: Provides block-level storage volumes. Best suited for single-AZ workloads such as databases.
2. **Amazon Elastic File System (EFS)**: A fully managed NFS file system that can be mounted simultaneously by multiple pods across multiple AZs. Ideal for shared storage use cases.
3. ***Amazon S3 (via CSI driver)***: Provides object storage integration directly into Kubernetes pods. Useful for workloads dealing with file uploads, backups, and logs.

Each option has its strengths:

* ***EBS*** → High-performance, low-latency block storage (but limited to one AZ).
* ***EFS*** → Shared, scalable, network file system accessible across multiple nodes/AZs.
* ***S3*** → Object storage with global durability, but not a traditional file system.

## Patterns for Providing Storage on EKS

There are several patterns for provisioning storage in EKS, depending on workload requirements:

* ***Static Provisioning***

In static provisioning, the storage resource (such as an EBS or EFS volume) is created beforehand, and then referenced inside Kubernetes as a PersistentVolume. This model gives administrators strict control over storage resources but requires manual effort.

* ***Dynamic Provisioning***

Dynamic provisioning uses StorageClasses and CSI drivers to automate the creation of storage resources. When a PersistentVolumeClaim is created, Kubernetes automatically provisions the necessary backend storage (EBS/EFS) and binds it to the claim. This pattern is widely used because it is flexible, scalable, and reduces operational overhead.

## Conclusion

Storage is a foundational component of Kubernetes, and on EKS it becomes even more powerful with AWS-managed services. By combining Persistent Volumes, Persistent Volume Claims, and StorageClasses, we can flexibly allocate storage for workloads without exposing them to infrastructure complexities.
