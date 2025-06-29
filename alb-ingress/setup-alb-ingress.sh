#!/bin/bash

set -euo pipefail # fail on error

# -----------------------------------
# CONFIG: update for each cluster run
# -----------------------------------
PROJECT_NAME="infinity-assignment"
CLUSTER_NAME="prod-cluster"
AWS_REGION="eu-central-1"
SERVICE_ACCOUNT_NAME="aws-load-balancer-controller"
NAMESPACE="kube-system"
CHART_VERSION="1.7.1"
CONTROLLER_IMAGE_TAG="v2.7.1"

# -----------------------------------
# 1. Get AWS account & OIDC info
# -----------------------------------
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Using AWS Account: ${ACCOUNT_ID}"

# Optional sanity check:
echo "Getting cluster OIDC provider..."
OIDC_PROVIDER=$(aws eks describe-cluster \
    --name ${CLUSTER_NAME} \
    --region ${AWS_REGION} \
    --query "cluster.identity.oidc.issuer" \
    --output text | sed 's~https://~~')
echo "OIDC Provider: $OIDC_PROVIDER"

# IAM Role ARN should match the cluster:
IAM_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${PROJECT_NAME}-${CLUSTER_NAME}-alb-controller-role"
echo "Using IAM Role: $IAM_ROLE_ARN"

# -----------------------------------
# 2. Get VPC ID automatically
# -----------------------------------
VPC_ID=$(aws eks describe-cluster \
    --name ${CLUSTER_NAME} \
    --region ${AWS_REGION} \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)

if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
    echo "ERROR: VPC ID could not be determined for cluster $CLUSTER_NAME"
    exit 1
fi

echo "Using VPC ID: $VPC_ID"

# -----------------------------------
# 3. Create namespace & ServiceAccount
# -----------------------------------
kubectl get namespace $NAMESPACE >/dev/null 2>&1 || kubectl create namespace $NAMESPACE

if ! kubectl get sa $SERVICE_ACCOUNT_NAME -n $NAMESPACE >/dev/null 2>&1; then
    kubectl create sa $SERVICE_ACCOUNT_NAME -n $NAMESPACE
    echo "Created ServiceAccount $SERVICE_ACCOUNT_NAME"
else
    echo "ServiceAccount $SERVICE_ACCOUNT_NAME already exists"
fi

# -----------------------------------
# 4. Annotate SA with IAM Role
# -----------------------------------
kubectl annotate sa $SERVICE_ACCOUNT_NAME \
    -n $NAMESPACE \
    "eks.amazonaws.com/role-arn=${IAM_ROLE_ARN}" \
    --overwrite

echo "Annotated ServiceAccount with IAM Role"

# -----------------------------------
# 5. Helm repo & upgrade/install
# -----------------------------------
helm repo add eks https://aws.github.io/eks-charts || true
helm repo update

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n $NAMESPACE \
    --set clusterName=$CLUSTER_NAME \
    --set region=$AWS_REGION \
    --set vpcId=$VPC_ID \
    --set serviceAccount.create=false \
    --set serviceAccount.name=$SERVICE_ACCOUNT_NAME \
    --set image.tag=$CONTROLLER_IMAGE_TAG \
    --version $CHART_VERSION

# -----------------------------------
# 6. Confirm Deployment
# -----------------------------------
echo "ALB Ingress Controller status:"
kubectl rollout status deployment/aws-load-balancer-controller -n $NAMESPACE

echo "ALB Ingress Controller installation complete for cluster: $CLUSTER_NAME"
