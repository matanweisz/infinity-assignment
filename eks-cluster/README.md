# Infinity Assignment - Kubernetes Cluster Setup

## AWS ALB Ingress Controller Setup

Create IAM Policy for ALB Controller:
```bash
# Download the IAM policy document
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json

# Create the IAM policy using the downloaded document
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json
```

Create Service Account for ALB Controller:
```bash
eksctl create iamserviceaccount \
    --region eu-centarl-1 \
    --name aws-load-balancer-controller \
    --namespace kube-system \
    --cluster infinity-assignment-cluster \
    --attach-policy-arn arn:aws:iam::536697238781:policy/AWSLoadBalancerControllerIAMPolicy \
    --approve
```

Install ALB Ingress Controller using Helm:
```bash
# Add the EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install the AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=infinity-assignment-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=eu-centarl-1 \
  --set vpcId=$(aws eks describe-cluster --name infinity-assignment-cluster --query "cluster.resourcesVpcConfig.vpcId" --output text)

# Verify the installation
kubectl get deployment -n kube-system aws-load-balancer-controller
```


