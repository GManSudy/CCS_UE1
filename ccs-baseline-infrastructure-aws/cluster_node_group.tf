resource "aws_iam_role" "eks_worker_node_role" {
  name = "${var.deployment_name}-eks-worker-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Effect = "Allow"
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_role" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonRDSFullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore", # Allows SSH-like access to the nodes, via the AWS Console UI
  ])
  policy_arn = each.value
  role       = aws_iam_role.eks_worker_node_role.name
}

resource "aws_security_group" "eks_worker_node_sg" {
  name        = "${var.deployment_name}-eks-worker-node-sg"
  description = "Security group for EKS worker nodes to allow management access via SSH"
  vpc_id      = aws_eks_cluster.cluster.vpc_config[0].vpc_id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.deployment_name}-eks-worker-node-sg"
  }
}

locals {
  node_group_name = "${var.deployment_name}-eks-cluster-worker-nodes"
}

resource "aws_launch_template" "eks_worker_node" {
  name     = "${var.deployment_name}-eks-worker-node"
  image_id = "ami-044cfe87a44e21605"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
  }
  tags = {
    "eks:cluster-name"   = aws_eks_cluster.cluster.name
    "eks:nodegroup-name" = local.node_group_name
  }
  update_default_version = true
  vpc_security_group_ids = [
    aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id,
    aws_security_group.eks_worker_node_sg.id,
  ]
  user_data = base64encode(templatefile(
    "cluster_nodes_user_data.tftpl", {
      cluster_api_server_endpoint   = aws_eks_cluster.cluster.endpoint
      cluster_certificate_authority = aws_eks_cluster.cluster.certificate_authority[0].data
      cluster_cidr                  = aws_eks_cluster.cluster.kubernetes_network_config[0].service_ipv4_cidr
      cluster_name                  = aws_eks_cluster.cluster.name
      node_group_name               = local.node_group_name
    }
  ))
}

resource "aws_eks_node_group" "eks_worker" {
  node_group_name = local.node_group_name
  cluster_name    = aws_eks_cluster.cluster.name
  node_role_arn   = aws_iam_role.eks_worker_node_role.arn
  launch_template {
    id      = aws_launch_template.eks_worker_node.id
    version = aws_launch_template.eks_worker_node.latest_version
  }
  subnet_ids     = [aws_subnet.public_subnet[0].id]
  instance_types = var.eks_node_group_allowed_instance_types
  scaling_config {
    min_size     = 2
    desired_size = 2
    max_size     = 10
  }
  node_repair_config {
    enabled = true
  }
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_role
  ]
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
