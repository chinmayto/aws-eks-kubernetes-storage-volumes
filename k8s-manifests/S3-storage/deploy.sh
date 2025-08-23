#!/bin/bash

# Script to deploy S3 storage manifests with Mountpoint CSI driver and Pod Identity

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying S3 Storage Manifests (Mountpoint CSI Driver with Pod Identity)${NC}"

# Check if we're in the right directory
if [ ! -f "../../infrastructure/outputs.tf" ]; then
    echo -e "${RED}Error: Please run this script from the k8s-manifests/S3-storage directory${NC}"
    exit 1
fi

# Check if S3 CSI driver is installed
echo -e "${YELLOW}Checking S3 Mountpoint CSI driver installation...${NC}"
if ! kubectl get pods -n kube-system | grep -q s3-csi; then
    echo -e "${RED}Error: S3 Mountpoint CSI driver not found. Make sure it's installed as an EKS addon.${NC}"
    exit 1
fi

echo -e "${GREEN}S3 Mountpoint CSI driver is installed${NC}"

# Get S3 values from Terraform outputs
echo -e "${YELLOW}Getting S3 values from Terraform...${NC}"
cd ../../infrastructure

S3_BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")

if [ -z "$S3_BUCKET_NAME" ]; then
    echo -e "${RED}Error: Could not get S3 bucket name from Terraform. Make sure you've run 'terraform apply' first.${NC}"
    echo -e "${YELLOW}Required output: s3_bucket_name${NC}"
    exit 1
fi

echo -e "${GREEN}S3 Bucket Name: $S3_BUCKET_NAME${NC}"

# Go back to k8s manifests directory
cd ../k8s-manifests/S3-storage

# Create temporary files with substituted values
echo -e "${YELLOW}Creating manifests with S3 values...${NC}"

# StorageClass (needs bucket name substitution)
sed "s|YOUR_BUCKET_NAME|$S3_BUCKET_NAME|g" storage-class.yaml > storage-class-final.yaml

# Apply manifests
echo -e "${YELLOW}Applying Kubernetes manifests...${NC}"

kubectl apply -f storage-class-final.yaml
kubectl apply -f service-account.yaml
kubectl apply -f persistent-volume-claim.yaml
kubectl apply -f nginx-pod.yaml
kubectl apply -f nginx-service.yaml

# Wait for pod to be ready
echo -e "${YELLOW}Waiting for pod to be ready...${NC}"
kubectl wait --for=condition=Ready --timeout=300s pod/nginx-s3

# Clean up temporary files
rm -f storage-class-final.yaml

echo -e "${GREEN}S3 storage manifests deployed successfully!${NC}"
echo ""
echo -e "${YELLOW}Check pod status:${NC}"
echo "kubectl get pod nginx-s3"
echo "kubectl get service nginx-s3-service"
echo "kubectl get pvc s3-pvc"
echo ""
echo -e "${YELLOW}Test nginx web server:${NC}"
echo "kubectl port-forward service/nginx-s3-service 8080:80"
echo "Then visit http://localhost:8080"
echo ""
echo -e "${YELLOW}Check S3 content:${NC}"
echo "kubectl exec nginx-s3 -- ls -la /usr/share/nginx/html/"
echo "kubectl exec nginx-s3 -- cat /usr/share/nginx/html/index.html"
echo ""
echo -e "${YELLOW}Check S3 mount:${NC}"
echo "kubectl exec nginx-s3 -- df -h /usr/share/nginx/html"
echo ""
echo -e "${YELLOW}View logs:${NC}"
echo "kubectl logs nginx-s3"
echo ""
echo -e "${YELLOW}Verify Pod Identity:${NC}"
echo "kubectl describe sa s3-csi-driver-sa -n kube-system"