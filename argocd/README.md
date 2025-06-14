# Post-Terraform Setup: ArgoCD + ALB Ingress

First: Set Up `kubectl` Access, then install the AWS ALB Ingress Controller and ArgoCD.
Run this command to configure access to the EKS cluster:
```bash
aws eks update-kubeconfig --region eu-central-1 --name infinity-assignment-eks
```

Install AWS ALB Ingress Controller:
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=infinity-assignment-eks \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=eu-central-1 \
  --set vpcId=vpc-07f267d85d41badfe \
  --set ingressClass=alb
```

Install ArgoCD:
```bash
kubectl create namespace argocd

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd -n argocd
```

Expose ArgoCD via the ALB Ingress:
```bash
kubectl apply -f argocd-ingress.yaml
```

Get ArgoCD Admin Password:
```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode; echo
```

Access ArgoCD:
    - Navigate in your browser to the URL: `https://argocd.matanweisz.xyz`
    - Login with username `admin` and the password obtained in the previous step.
