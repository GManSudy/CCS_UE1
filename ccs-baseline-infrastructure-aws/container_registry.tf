resource "aws_ecr_repository" "repository" {
  name         = "${var.deployment_name}-ecr-repository"
  force_delete = true
}
