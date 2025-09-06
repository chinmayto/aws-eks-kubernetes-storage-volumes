#!/bin/bash

# Script to deploy EBS storage manifests with static volume provisioning
# This script automatically gets EBS volume ID from Terraform outputs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying EBS Storage Manifests (Static Provisioning)${NC}"

# Check if we're in the right directory
if [ ! -f "../../infrastructure/outputs.tf" ]; then
    echo -e "${RED}Error: Please run this script from the k8s-manifests/EBS-storage directory${NC}"
    exit 1
fi

# Check if EBS CSI driver is installed
echo -e "${YELLOW}Checking EBS CSI driver installation...${NC}"
if ! kubectl get pods -n kube-system | grep -q ebs-csi; then
    echo -e "${RED}Error: EBS CSI driver not found. Make sure it's installed as an EKS addon.${NC}"
    exit 1
fi

echo -e "${GREEN}EBS CSI driver is installed${NC}"

# Get EBS values from Terraform outputs
echo -e "${YELLOW}Getting EBS values from Terraform...${NC}"
cd ../../infrastructure

EBS_VOLUME_ID=$(terraform output -raw ebs_volume_id 2>/dev/null || echo "")

if [ -z "$EBS_VOLUME_ID" ]; then
    echo -e "${RED}Error: Could not get EBS volume ID from Terraform. Make sure you've run 'terraform apply' first.${NC}"
    echo -e "${YELLOW}Note: You need to create an EBS volume in your Terraform configuration and output its ID.${NC}"
    exit 1
fi

echo -e "${GREEN}EBS Volume ID: $EBS_VOLUME_ID${NC}"

# Go back to k8s manifests directory
cd ../k8s-manifests/EBS-storage

# Create temporary files with substituted values
echo -e "${YELLOW}Creating manifests with EBS values...${NC}"

# Persistent Volume (only file that needs EBS_VOLUME_ID for static provisioning)
sed "s/\${EBS_VOLUME_ID}/$EBS_VOLUME_ID/g" static-persistent-volume.yaml > static-persistent-volume-final.yaml

# Apply manifests
echo -e "${YELLOW}Applying Kubernetes manifests...${NC}"

kubectl apply -f static-storage-class.yaml
kubectl apply -f static-persistent-volume-final.yaml
kubectl apply -f static-persistent-volume-claim.yaml
kubectl apply -f static-nginx-pod.yaml
kubectl apply -f static-nginx-service.yaml

# Clean up temporary files
rm -f static-persistent-volume-final.yaml

echo -e "${GREEN}EBS storage manifests deployed successfully!${NC}"
echo ""
echo -e "${YELLOW}Check deployment status:${NC}"
echo "kubectl get pod nginx-ebs-static-pod"
echo "kubectl get service nginx-ebs-static-service"
echo "kubectl get pvc ebs-static-pvc"
echo "kubectl get pv ebs-static-pv"
echo ""
echo -e "${YELLOW}Wait for pod to be ready:${NC}"
echo "kubectl wait --for=condition=Ready pod/nginx-ebs-static-pod --timeout=120s"
echo ""
echo -e "${YELLOW}Test nginx web server:${NC}"
echo "kubectl port-forward service/nginx-ebs-static-service 8082:80"
echo "Then visit http://localhost:8082"
echo ""
echo -e "${YELLOW}Check EBS content:${NC}"
echo "kubectl exec nginx-ebs-static-pod -- ls -la /usr/share/nginx/html/"
echo "kubectl exec nginx-ebs-static-pod -- cat /usr/share/nginx/html/index.html"
echo ""
echo -e "${YELLOW}Check EBS volume attachment:${NC}"
echo "kubectl exec nginx-ebs-static-pod -- df -h /usr/share/nginx/html"