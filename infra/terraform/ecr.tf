# ECR Repository for Inventory App
resource "aws_ecr_repository" "inventory_app" {
  name                 = "cloud-design-inventory-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # Automatically deletes images when we destroy the project

  tags = {
    Name = "inventory-app-repo"
  }
}

# ECR Repository for API Gateway
resource "aws_ecr_repository" "api_gateway" {
  name                 = "cloud-design-api-gateway"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = {
    Name = "api-gateway-repo"
  }
}

# ECR Repository for Billing App
resource "aws_ecr_repository" "billing_app" {
  name                 = "cloud-design-billing-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = {
    Name = "billing-app-repo"
  }
}