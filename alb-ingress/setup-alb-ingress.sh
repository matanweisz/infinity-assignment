#!/bin/bash

# AWS Load Balancer Controller Install Script for EKS Cluster

# --------- Configuration Variables ---------
PROJECT_NAME="infinity-assignment"
CLUSTER_NAME="backend-cluster"
AWS_REGION="eu-central-1"
SERVICE_ACCOUNT_NAME="aws-load-balancer-controller"
NAMESPACE="kube-system"
CHART_VERSION="1.7.1"         # Latest stable as of writing
CONTROLLER_IMAGE_TAG="v2.7.1" # Match with Helm chart version
VPC_ID="vpc-0890523b650026664"

# Construct IAM Role ARN dynamically using project name
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IAM_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${PROJECT_NAME}-lb-controller-role"

# --------- Fetch VPC ID Automatically ---------
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=*${PROJECT_NAME}-vpc*" \
    --query "Vpcs[0].VpcId" \
    --output text \
    --region $AWS_REGION)

if [[ $VPC_ID == "None" || -z "$VPC_ID" ]]; then
    echo "VPC not found with name containing: ${PROJECT_NAME}-vpc"
    exit 1
fi

# --------- 1. Create Namespace (if not exists) ---------
kubectl get namespace $NAMESPACE >/dev/null 2>&1 || kubectl create namespace $NAMESPACE

# --------- 2. Create Service Account ---------
kubectl get serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE >/dev/null 2>&1 ||
    kubectl create serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE

# --------- 3. Annotate Service Account with IAM Role ---------
kubectl annotate serviceaccount $SERVICE_ACCOUNT_NAME \
    -n $NAMESPACE \
    eks.amazonaws.com/role-arn=$IAM_ROLE_ARN \
    --overwrite

# --------- 4. Add and Update Helm Repo ---------
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# --------- 5. Install ALB Controller via Helm ---------
helm upgrade --install $SERVICE_ACCOUNT_NAME eks/aws-load-balancer-controller \
    -n $NAMESPACE \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=false \
    --set serviceAccount.name=$SERVICE_ACCOUNT_NAME \
    --set region=$AWS_REGION \
    --set vpcId=$VPC_ID \
    --set image.tag=$CONTROLLER_IMAGE_TAG \
    --version $CHART_VERSION

kubectl get deployment -n kube-system aws-load-balancer-controller

echo "ALB Ingress Controller installation completed for cluster: $CLUSTER_NAME"
