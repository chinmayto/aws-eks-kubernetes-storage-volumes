#!/bin/bash

# Script to deploy EFS storage manifests with dynamic volume provisioning

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying EFS Storage Manifests (Dynamic Provisioning)${NC}"

# Check if we're in the right directory
if [ ! -f "../../infrastructure/outputs.tf" ]; then
    echo -e "${RED}Error: Please run this script from the k8s-manifests/EFS-storage directory${NC}"
    exit 1
fi

# Get EFS values from Terraform outputs
echo -e "${YELLOW}Getting EFS values from Terraform...${NC}"
cd ../../infrastructure

EFS_FILE_SYSTEM_ID=$(terraform output -raw efs_file_system_id 2>/dev/null || echo "")

if [ -z "$EFS_FILE_SYSTEM_ID" ]; then
    echo -e "${RED}Error: Could not get EFS file system ID from Terraform. Make sure you've run 'terraform apply' first.${NC}"
    exit 1
fi

echo -e "${GREEN}EFS File System ID: $EFS_FILE_SYSTEM_ID${NC}"

# Go back to k8s manifests directory
cd ../k8s-manifests/EFS-storage

# Create temporary files with substituted values
echo -e "${YELLOW}Creating manifests with EFS values...${NC}"

# Storage Class (needs EFS_FILE_SYSTEM_ID for dynamic provisioning)
sed "s/\${EFS_FILE_SYSTEM_ID}/$EFS_FILE_SYSTEM_ID/g" dynamic-storage-class.yaml > dynamic-storage-class-final.yaml

# Apply manifests
echo -e "${YELLOW}Applying Kubernetes manifests...${NC}"

kubectl apply -f dynamic-storage-class-final.yaml
kubectl apply -f dynamic-persistent-volume-claim.yaml
kubectl apply -f dynamic-nginx-pod.yaml
kubectl apply -f dynamic-nginx-service.yaml

# Clean up temporary files
rm -f dynamic-storage-class-final.yaml

echo -e "${GREEN}EFS dynamic storage manifests deployed successfully!${NC}"
echo ""
echo -e "${YELLOW}Check deployment status:${NC}"kubectl get pv

echo "kubectl get pod nginx-efs-dynamic-pod"
echo "kubectl get service nginx-efs-dynamic-service"
echo "kubectl get pvc efs-dynamic-pvc"
echo "kubectl get pv"
echo ""
echo -e "${YELLOW}Wait for pod to be ready:${NC}"
echo "kubectl wait --for=condition=Ready pod/nginx-efs-dynamic-pod --timeout=120s"
echo ""
echo -e "${YELLOW}Test nginx web server:${NC}"
echo "kubectl port-forward service/nginx-efs-dynamic-service 8081:80"
echo "Then visit http://localhost:8081"
echo ""
echo -e "${YELLOW}Check EFS content:${NC}"
echo "kubectl exec nginx-efs-dynamic-pod -- ls -la /usr/share/nginx/html/"
echo "kubectl exec nginx-efs-dynamic-pod -- cat /usr/share/nginx/html/index.html"
echo ""
echo -e "${YELLOW}Check dynamically created access point:${NC}"
echo "aws efs describe-access-points --file-system-id $EFS_FILE_SYSTEM_ID"