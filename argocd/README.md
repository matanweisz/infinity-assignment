# Post-Terraform Setup: ArgoCD + ALB Ingress

1. Install AWS ALB Ingress Controller:
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

2. Install ArgoCD:
```bash
kubectl create namespace argocd

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd -n argocd
```

3. Expose ArgoCD via the ALB Ingress:
```bash
kubectl apply -f argocd-ingress.yaml
```

4. Get ArgoCD Admin Password:
```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode; echo
```

5. Access ArgoCD:
   - Navigate in your browser to the URL: `https://argocd.matanweisz.xyz`
   - Login with username `admin` and the password obtained in the previous step.
