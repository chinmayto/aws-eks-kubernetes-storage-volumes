#!/bin/bash

# Script to deploy EFS storage manifests with static volume provisioning
# This script automatically gets EFS file system ID from Terraform outputs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying EFS Storage Manifests (Static Provisioning)${NC}"

# Check if we're in the right directory
if [ ! -f "../../infrastructure/outputs.tf" ]; then
    echo -e "${RED}Error: Please run this script from the k8s-manifests/EFS-storage directory${NC}"
    exit 1
fi

# Check if EFS CSI driver is installed
echo -e "${YELLOW}Checking EFS CSI driver installation...${NC}"
if ! kubectl get pods -n kube-system | grep -q efs-csi; then
    echo -e "${RED}Error: EFS CSI driver not found. Make sure it's installed as an EKS addon.${NC}"
    exit 1
fi

echo -e "${GREEN}EFS CSI driver is installed${NC}"

# Get EFS values from Terraform outputs
echo -e "${YELLOW}Getting EFS values from Terraform...${NC}"
cd ../../infrastructure

EFS_FILE_SYSTEM_ID=$(terraform output -raw efs_file_system_id 2>/dev/null || echo "")

if [ -z "$EFS_FILE_SYSTEM_ID" ]; then
    echo -e "${RED}Error: Could not get EFS file system ID from Terraform. Make sure you've run 'terraform apply' first.${NC}"
    echo -e "${YELLOW}Note: EFS file system must be created in your Terraform configuration with proper outputs.${NC}"
    exit 1
fi

echo -e "${GREEN}EFS File System ID: $EFS_FILE_SYSTEM_ID${NC}"

# Go back to k8s manifests directory
cd ../k8s-manifests/EFS-storage

# Create temporary files with substituted values
echo -e "${YELLOW}Creating manifests with EFS values...${NC}"

# Persistent Volume (only file that needs EFS_FILE_SYSTEM_ID for static provisioning)
sed "s/\${EFS_FILE_SYSTEM_ID}/$EFS_FILE_SYSTEM_ID/g" static-persistent-volume.yaml > static-persistent-volume-final.yaml

# Apply manifests
echo -e "${YELLOW}Applying Kubernetes manifests...${NC}"

kubectl apply -f static-storage-class.yaml
kubectl apply -f static-persistent-volume-final.yaml
kubectl apply -f static-persistent-volume-claim.yaml
kubectl apply -f static-nginx-pod.yaml
kubectl apply -f static-nginx-service.yaml

# Clean up temporary files
rm -f static-persistent-volume-final.yaml

echo -e "${GREEN}EFS storage manifests deployed successfully!${NC}"
echo ""
echo -e "${YELLOW}Check deployment status:${NC}"
echo "kubectl get pod nginx-efs-static-pod"
echo "kubectl get service nginx-efs-static-service"
echo "kubectl get pvc efs-static-pvc"
echo "kubectl get pv efs-static-pv"
echo ""
echo -e "${YELLOW}Wait for pod to be ready:${NC}"
echo "kubectl wait --for=condition=Ready pod/nginx-efs-static-pod --timeout=120s"
echo ""
echo -e "${YELLOW}Test nginx web server:${NC}"
echo "kubectl port-forward service/nginx-efs-static-service 8080:80"
echo "Then visit http://localhost:8080"
echo ""
echo -e "${YELLOW}Check EFS content:${NC}"
echo "kubectl exec nginx-efs-static-pod -- ls -la /usr/share/nginx/html/"
echo "kubectl exec nginx-efs-static-pod -- cat /usr/share/nginx/html/index.html"