resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.deployment_name}-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Effect = "Allow"
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_role" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_eks_cluster" "cluster" {
  name     = "${var.deployment_name}-eks-cluster"
  version  = var.kubernetes_version
  role_arn = aws_iam_role.eks_cluster_role.arn
  vpc_config {  backend "s3" {
    region = "eu-central-1"
    bucket = "terraform-state-bucket-wurscht1"
    key    = "aws-infrastructure.tfstate"
  }
    subnet_ids              = aws_subnet.private_subnet[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
  }
  access_config {
    authentication_mode = "API"
  }
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_role
  ]
}
