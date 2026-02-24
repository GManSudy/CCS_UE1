# Deployment of aws-infrastructure
* Ensure you have AWS credentials configured for your CLI
* Adapt `main.tf` to point to an S3 state bucket in your own account
* `terraform init`
* `terraform apply -auto-approve`
* Update your `kubeconfig` to point to the cluster: `aws eks update-kubeconfig --region eu-central-1 --name ccs-infra-eks-cluster`
* Ensure `kubectl` can communicate with the cluster: `kubectl get nodes`  
In case you receive an error to provide credentials (but `aws sts get-caller-identity` shows that you have configured credentials), make sure there is an access entry for your principal with `AmazonEKSClusterAdminPolicy` permissions under: AWS EKS -> Your cluster -> Access -> IAM Access Entries
