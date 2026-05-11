resource "aws_ecs_cluster" "main" {
  name = "cloud-design-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}