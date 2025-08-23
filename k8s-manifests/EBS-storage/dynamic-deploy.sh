#!/bin/bash

# Script to deploy EBS storage manifests with dynamic volume provisioning

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying EBS Storage Manifests (Dynamic Provisioning)${NC}"

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

# Apply manifests (no substitution needed for dynamic provisioning)
echo -e "${YELLOW}Applying Kubernetes manifests...${NC}"

kubectl apply -f dynamic-storage-class.yaml
kubectl apply -f dynamic-persistent-volume-claim.yaml
kubectl apply -f dynamic-nginx-pod.yaml
kubectl apply -f dynamic-nginx-service.yaml

echo -e "${GREEN}EBS dynamic storage manifests deployed successfully!${NC}"
echo ""
echo -e "${YELLOW}Check deployment status:${NC}"
echo "kubectl get pod nginx-ebs-dynamic-pod"
echo "kubectl get service nginx-ebs-dynamic-service"
echo "kubectl get pvc ebs-dynamic-pvc"
echo "kubectl get pv"
echo ""
echo -e "${YELLOW}Wait for pod to be ready:${NC}"
echo "kubectl wait --for=condition=Ready pod/nginx-ebs-dynamic-pod --timeout=120s"
echo ""
echo -e "${YELLOW}Test nginx web server:${NC}"
echo "kubectl port-forward service/nginx-ebs-dynamic-service 8083:80"
echo "Then visit http://localhost:8083"
echo ""
echo -e "${YELLOW}Check EBS content:${NC}"
echo "kubectl exec nginx-ebs-dynamic-pod -- ls -la /usr/share/nginx/html/"
echo "kubectl exec nginx-ebs-dynamic-pod -- cat /usr/share/nginx/html/index.html"
echo ""
echo -e "${YELLOW}Check dynamically created EBS volume:${NC}"
echo "kubectl exec nginx-ebs-dynamic-pod -- df -h /usr/share/nginx/html"
echo ""
echo -e "${YELLOW}Get EBS volume details:${NC}"
echo "PV_NAME=\$(kubectl get pvc ebs-dynamic-pvc -o jsonpath='{.spec.volumeName}')"
echo "VOLUME_ID=\$(kubectl get pv \$PV_NAME -o jsonpath='{.spec.csi.volumeHandle}')"
echo "aws ec2 describe-volumes --volume-ids \$VOLUME_ID"