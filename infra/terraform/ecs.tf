# ==========================================
# IAM Roles for ECS and EC2
# ==========================================
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs_instance_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs_instance_profile"
  role = aws_iam_role.ecs_instance_role.name
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ==========================================
# ECS Cluster
# ==========================================
resource "aws_ecs_cluster" "main" {
  name = "cloud-design-cluster"
}

# ==========================================
# EC2 Instance (t3.small)
# ==========================================
# Get the latest ECS-optimized Amazon Linux AMI
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "ecs_lt" {
  name_prefix   = "ecs-template"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = "t3.small"

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  vpc_security_group_ids = [aws_security_group.ecs_sg.id]

  # User data to register the EC2 instance with our ECS cluster
  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
              EOF
  )
}

resource "aws_autoscaling_group" "ecs_asg" {
  vpc_zone_identifier = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  desired_capacity    = 3
  max_size            = 3
  min_size            = 3

  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }
}

resource "aws_ecs_capacity_provider" "ec2" {
  name = "ec2-capacity-provider"
  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.ec2.name]
}

# ==========================================
# ONE MASSIVE TASK DEFINITION (All 6 Containers)
# ==========================================
# To fit everything on a 2GB RAM t3.small and let them communicate easily
# over localhost, we put all 6 containers into ONE task definition.
resource "aws_ecs_task_definition" "full_stack" {
  family                   = "full-stack-app"
  network_mode             = "bridge" # Uses standard docker networking on the EC2 host
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  # Three t3.small instances = 6 GiB total RAM
  # Six services × 512 MiB = 3 GiB container memory
  # Placement strategy allows optimal distribution across nodes:
  # Instance 1: api-gateway (512 MiB)
  # Instance 2: billing-app + billing-database + rabbitmq (1536 MiB)
  # Instance 3: inventory-app + inventory-database (1024 MiB)
  container_definitions = jsonencode([
    {
      name      = "rabbitmq"
      image     = "rabbitmq:3-management-alpine"
      memory    = 512
      essential = true
      environment = [
        { name = "RABBITMQ_DEFAULT_USER", value = "rabbitmq_user" },
        { name = "RABBITMQ_DEFAULT_PASS", value = "rabbitmq_password" }
      ]
    },
    {
      name      = "inventory-database"
      image     = "postgres:13-alpine"
      memory    = 512
      essential = true
      environment = [
        { name = "POSTGRES_DB", value = "inventory" },
        { name = "POSTGRES_USER", value = "inventoryuser" },
        { name = "POSTGRES_PASSWORD", value = "inventorypassword" }
      ]
    },
    {
      name      = "billing-database"
      image     = "postgres:13-alpine"
      memory    = 512
      essential = true
      environment = [
        { name = "POSTGRES_DB", value = "billing" },
        { name = "POSTGRES_USER", value = "billinguser" },
        { name = "POSTGRES_PASSWORD", value = "billingpassword" }
      ]
    },
    {
      name      = "inventory-app"
      image     = "${aws_ecr_repository.inventory_app.repository_url}:latest"
      memory    = 512
      essential = true
      links     = ["inventory-database"]
      environment = [
        { name = "INVENTORY_DB_HOST", value = "inventory-database" },
        { name = "INVENTORY_DB_PORT", value = "5432" },
        { name = "INVENTORY_DB_NAME", value = "inventory" },
        { name = "INVENTORY_DB_USER", value = "inventoryuser" },
        { name = "INVENTORY_DB_PASSWORD", value = "inventorypassword" },
        { name = "INVENTORY_PORT", value = "8080" }
      ]
    },
    {
      name      = "billing-app"
      image     = "${aws_ecr_repository.billing_app.repository_url}:latest"
      memory    = 512
      essential = true
      links     = ["billing-database", "rabbitmq"]
      environment = [
        { name = "BILLING_DB_HOST", value = "billing-database" },
        { name = "BILLING_DB_PORT", value = "5432" },
        { name = "BILLING_DB_NAME", value = "billing" },
        { name = "BILLING_DB_USER", value = "billinguser" },
        { name = "BILLING_DB_PASSWORD", value = "billingpassword" },
        { name = "BILLING_PORT", value = "8080" },
        { name = "RABBITMQ_HOST", value = "rabbitmq" },
        { name = "RABBITMQ_USER", value = "rabbitmq_user" },
        { name = "RABBITMQ_PASSWORD", value = "rabbitmq_password" }
      ]
    },
    {
      name      = "api-gateway"
      image     = "${aws_ecr_repository.api_gateway.repository_url}:latest"
      memory    = 512
      essential = true
      links     = ["inventory-app", "billing-app"]
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "INVENTORY_SERVICE_URL", value = "http://inventory-app:8080" },
        { name = "BILLING_SERVICE_URL", value = "http://billing-app:8080" },
        { name = "PORT", value = "3000" }
      ]
    }
  ])
}

# ==========================================
# ECS Service
# ==========================================
resource "aws_ecs_service" "full_stack_service" {
  name            = "full-stack-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.full_stack.arn
  desired_count   = 1
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = aws_lb_target_group.api_gateway.arn
    container_name   = "api-gateway"
    container_port   = 3000
  }
}