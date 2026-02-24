variable "deployment_name" {
  default = "ccs-infra"
}

variable "kubernetes_version" {
  default = "1.34"
}

variable "eks_node_group_allowed_instance_types" {
  default = ["t3a.medium"]
}
