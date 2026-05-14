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
# TASK DEFINITION 1: API Gateway
# ==========================================
resource "aws_ecs_task_definition" "api_gateway" {
  family                   = "api-gateway-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  
  # awsvpc mode requires Task-level CPU and Memory
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "api-gateway"
      image     = "${aws_ecr_repository.api_gateway.repository_url}:latest"
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000 # In awsvpc mode, containerPort and hostPort should be identical
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "INVENTORY_SERVICE_URL", value = "http://inventory-app.local:8080" },
        { name = "BILLING_SERVICE_URL", value = "http://billing-app.local:8080" },
        { name = "PORT", value = "3000" },

        { name = "RABBITMQ_HOST", value = "billing-app.local" },
        { name = "RABBITMQ_PORT", value = "5672" },
        { name = "RABBITMQ_USER", value = "rabbitmq_user" },
        { name = "RABBITMQ_PASSWORD", value = "rabbitmq_password" }
      ]
    }
  ])
}

# ==========================================
# TASK DEFINITION 2: Billing Stack
# ==========================================
resource "aws_ecs_task_definition" "billing_stack" {
  family                   = "billing-stack-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  
  cpu                      = "512"
  memory                   = "1536"

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
      name      = "billing-app"
      image     = "${aws_ecr_repository.billing_app.repository_url}:latest"
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "BILLING_DB_HOST", value = "localhost" }, # In awsvpc, containers in the same task communicate via localhost
        { name = "BILLING_DB_PORT", value = "5432" },
        { name = "BILLING_DB_NAME", value = "billing" },
        { name = "BILLING_DB_USER", value = "billinguser" },
        { name = "BILLING_DB_PASSWORD", value = "billingpassword" },
        { name = "BILLING_PORT", value = "8080" },
        { name = "RABBITMQ_HOST", value = "localhost" }, # Same here
        { name = "RABBITMQ_USER", value = "rabbitmq_user" },
        { name = "RABBITMQ_PASSWORD", value = "rabbitmq_password" }
      ]
    }
  ])
}

# ==========================================
# TASK DEFINITION 3: Inventory Stack
# ==========================================
resource "aws_ecs_task_definition" "inventory_stack" {
  family                   = "inventory-stack-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  
  cpu                      = "512"
  memory                   = "1024"

  container_definitions = jsonencode([
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
      name      = "inventory-app"
      image     = "${aws_ecr_repository.inventory_app.repository_url}:latest"
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "INVENTORY_DB_HOST", value = "localhost" }, # awsvpc mode localhost routing
        { name = "INVENTORY_DB_PORT", value = "5432" },
        { name = "INVENTORY_DB_NAME", value = "inventory" },
        { name = "INVENTORY_DB_USER", value = "inventoryuser" },
        { name = "INVENTORY_DB_PASSWORD", value = "inventorypassword" },
        { name = "INVENTORY_PORT", value = "8080" }
      ]
    }
  ])
}

# ==========================================
# ECS Services
# ==========================================
resource "aws_ecs_service" "api_gateway_service" {
  name            = "api-gateway-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api_gateway.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets         = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_gateway.arn
    container_name   = "api-gateway"
    container_port   = 3000
  }
}

resource "aws_ecs_service" "billing_service" {
  name            = "billing-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.billing_stack.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets         = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.billing.arn
  }
}

resource "aws_ecs_service" "inventory_service" {
  name            = "inventory-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.inventory_stack.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets         = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }

    service_registries {
    registry_arn   = aws_service_discovery_service.inventory.arn
  }
}

# ==========================================
# Service Discovery (Cloud Map)
# ==========================================
resource "aws_service_discovery_private_dns_namespace" "local" {
  name        = "local"
  description = "Private DNS namespace for microservices"
  vpc         = aws_subnet.public_1.vpc_id
}

# ==========================================
# Service Discovery Records
# ==========================================
resource "aws_service_discovery_service" "billing" {
  name         = "billing-app"
  namespace_id = aws_service_discovery_private_dns_namespace.local.id

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.local.id
    dns_records {
      ttl  = 10
      type = "A" # Type A works with awsvpc mode
    }
    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "inventory" {
  name = "inventory-app"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.local.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}