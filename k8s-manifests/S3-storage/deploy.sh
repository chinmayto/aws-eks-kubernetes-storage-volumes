#!/bin/bash

# Script to deploy S3 storage manifests with Pod Identity
# This script automatically gets S3 bucket name from Terraform outputs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying S3 Storage Manifests (Pod Identity)${NC}"

# Check if we're in the right directory
if [ ! -f "../../infrastructure/outputs.tf" ]; then
    echo -e "${RED}Error: Please run this script from the k8s-manifests/S3-storage directory${NC}"
    exit 1
fi

# Check if S3 CSI driver is installed
echo -e "${YELLOW}Checking S3 CSI driver installation...${NC}"
if ! kubectl get pods -n kube-system | grep -q aws-mountpoint-s3-csi-driver; then
    echo -e "${RED}Error: S3 CSI driver not found. Make sure it's installed as an EKS addon.${NC}"
    exit 1
fi

echo -e "${GREEN}S3 CSI driver is installed${NC}"

# Get S3 values from Terraform outputs
echo -e "${YELLOW}Getting S3 values from Terraform...${NC}"
cd ../../infrastructure

S3_BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")

if [ -z "$S3_BUCKET_NAME" ]; then
    echo -e "${RED}Error: Could not get S3 bucket name from Terraform. Make sure you've run 'terraform apply' first.${NC}"
    echo -e "${YELLOW}Note: S3 bucket must be created in your Terraform configuration with proper outputs.${NC}"
    exit 1
fi

echo -e "${GREEN}S3 Bucket Name: $S3_BUCKET_NAME${NC}"

# Go back to k8s manifests directory
cd ../k8s-manifests/S3-storage

# Create temporary files with substituted values
echo -e "${YELLOW}Creating manifests with S3 values...${NC}"

# Storage Class (needs S3_BUCKET_NAME)
sed "s/\${S3_BUCKET_NAME}/$S3_BUCKET_NAME/g" storage-class.yaml > storage-class-final.yaml

# PersistentVolume (needs S3_BUCKET_NAME for static provisioning)
sed "s/\${S3_BUCKET_NAME}/$S3_BUCKET_NAME/g" persistent-volume.yaml > persistent-volume-final.yaml

# Apply manifests
echo -e "${YELLOW}Applying Kubernetes manifests...${NC}"

kubectl apply -f storage-class-final.yaml
kubectl apply -f persistent-volume-final.yaml
kubectl apply -f persistent-volume-claim.yaml
kubectl apply -f nginx-pod.yaml
kubectl apply -f nginx-service.yaml

# Clean up temporary files
rm -f storage-class-final.yaml persistent-volume-final.yaml

echo -e "${GREEN}S3 storage manifests deployed successfully!${NC}"
echo ""
echo -e "${YELLOW}Check deployment status:${NC}"
echo "kubectl get pod nginx-s3-pod"
echo "kubectl get service nginx-s3-service"
echo "kubectl get pvc s3-pvc"
echo "kubectl get pv"
echo ""
echo -e "${YELLOW}Wait for pod to be ready:${NC}"
echo "kubectl wait --for=condition=Ready pod/nginx-s3-pod --timeout=120s"
echo ""
echo -e "${YELLOW}Test nginx web server:${NC}"
echo "kubectl port-forward service/nginx-s3-service 8084:80"
echo "Then visit http://localhost:8084"
echo ""
echo -e "${YELLOW}Check S3 content:${NC}"
echo "kubectl exec nginx-s3-pod -- ls -la /usr/share/nginx/html/"
echo "kubectl exec nginx-s3-pod -- cat /usr/share/nginx/html/index.html"
echo ""
echo -e "${YELLOW}Check S3 bucket content:${NC}"
echo "aws s3 ls s3://$S3_BUCKET_NAME/k8s-storage/"
echo ""
echo -e "${YELLOW}Verify Pod Identity:${NC}"
echo "kubectl describe sa s3-app-sa"
echo "kubectl exec nginx-s3-pod -- env | grep AWS_"
echo ""
echo -e "${YELLOW}Check S3 CSI driver status:${NC}"
echo "kubectl get pods -n kube-system -l app=aws-mountpoint-s3-csi-driver"