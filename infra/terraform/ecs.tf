# ==========================================
# CloudWatch Log Group & Region
# ==========================================
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/cloud-design"
  retention_in_days = 7
}

data "aws_region" "current" {}

# ==========================================
# Secrets Setup
# ==========================================
resource "random_password" "rabbitmq_password" {
  length  = 16
  special = false
}
resource "aws_ssm_parameter" "rabbitmq_password" {
  name  = "/cloud-design/rabbitmq/password"
  type  = "SecureString"
  value = random_password.rabbitmq_password.result
}

resource "random_password" "billing_db_password" {
  length  = 16
  special = false
}
resource "aws_ssm_parameter" "billing_db_password" {
  name  = "/cloud-design/billing-db/password"
  type  = "SecureString"
  value = random_password.billing_db_password.result
}

resource "random_password" "inventory_db_password" {
  length  = 16
  special = false
}
resource "aws_ssm_parameter" "inventory_db_password" {
  name  = "/cloud-design/inventory-db/password"
  type  = "SecureString"
  value = random_password.inventory_db_password.result
}

# ==========================================
# IAM Roles for ECS and EC2
# ==========================================
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs_instance_role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}
resource "aws_iam_role_policy_attachment" "ecs_instance_efs_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientReadWriteAccess"
}
resource "aws_iam_role_policy_attachment" "ecs_instance_ssm_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs_instance_profile"
  role = aws_iam_role.ecs_instance_role.name
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "ecs_execution_secrets_policy"
  role = aws_iam_role.ecs_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["ssm:GetParameters", "ssm:GetParameter"]
        Resource = [
          aws_ssm_parameter.rabbitmq_password.arn,
          aws_ssm_parameter.billing_db_password.arn,
          aws_ssm_parameter.inventory_db_password.arn
        ]
      }
    ]
  })
}

# ==========================================
# ECS Cluster
# ==========================================
resource "aws_ecs_cluster" "main" {
  name = "cloud-design-cluster-v2"
}

# ==========================================
# EC2 Launch Template & ASG
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
              yum install -y amazon-efs-utils
              EOF
  )
}

resource "aws_autoscaling_group" "ecs_asg" {
  vpc_zone_identifier = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  desired_capacity    = 3
  max_size            = 8
  min_size            = 3

  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ecs-instance"
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "ec2" {
  name = "ec2-capacity-provider"
  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.ec2.name]
}

# ==========================================
# TASK DEFINITIONS (Reverted to awsvpc)
# ==========================================
resource "aws_ecs_task_definition" "api_gateway" {
  family                   = "api-gateway-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  cpu                      = "256"
  memory                   = "1024"

  container_definitions = jsonencode([
    {
      name         = "api-gateway"
      image        = "${aws_ecr_repository.api_gateway.repository_url}:v1"
      memory       = 1024
      essential    = true
      portMappings = [{ containerPort = 3000, hostPort = 3000, protocol = "tcp" }]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
        interval    = 15
        timeout     = 5
        retries     = 3
        startPeriod = 180
      }
      environment = [
        { name = "BILLING_SERVICE_URL", value = "http://billing-app.local:8080" },
        { name = "INVENTORY_SERVICE_URL", value = "http://inventory-app.local:8080" },
        { name = "GATEWAY_PORT", value = "3000" },
        { name = "RABBITMQ_HOST", value = "rabbitmq.local" },
        { name = "RABBITMQ_PORT", value = "5672" },
        { name = "RABBITMQ_USER", value = "rabbitmq_user" }
      ]
      secrets = [{ name = "RABBITMQ_PASSWORD", valueFrom = aws_ssm_parameter.rabbitmq_password.arn }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "api-gateway"
        }
      }
    }
  ])
}

# ==========================================
# TASK DEFINITION: RabbitMQ
# ==========================================
resource "aws_ecs_task_definition" "rabbitmq" {
  family                   = "rabbitmq-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "rabbitmq"
      image     = "rabbitmq:3-management-alpine"
      memory    = 512
      essential = true
      environment = [
        { name = "RABBITMQ_DEFAULT_USER", value = "rabbitmq_user" }
      ]
      secrets = [
        { name = "RABBITMQ_DEFAULT_PASS", valueFrom = aws_ssm_parameter.rabbitmq_password.arn }
      ]
      portMappings = [
        { containerPort = 5672, hostPort = 5672, protocol = "tcp" },
        { containerPort = 15672, hostPort = 15672, protocol = "tcp" }
      ]
      healthCheck = {
        command     = ["CMD", "rabbitmq-diagnostics", "ping"]
        interval    = 15
        timeout     = 10
        retries     = 5
        startPeriod = 60
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "rabbitmq"
        }
      }
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
  memory                   = "1024"

  volume {
    name = "billing-db-data"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.db_data.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.billing_db.id
        iam             = "DISABLED"
      }
    }
  }
  container_definitions = jsonencode([
    {
      name      = "billing-database"
      image     = "postgres:13-alpine"
      memory    = 256
      essential = true
      environment = [
        { name = "POSTGRES_DB", value = "billing" },
        { name = "POSTGRES_USER", value = "billinguser" },
        { name = "PGDATA", value = "/data/billing/pgdata" }
      ]
      secrets     = [{ name = "POSTGRES_PASSWORD", valueFrom = aws_ssm_parameter.billing_db_password.arn }]
      mountPoints = [{ sourceVolume = "billing-db-data", containerPath = "/data/billing", readOnly = false }]
      healthCheck = {
        command     = ["CMD-SHELL", "pg_isready -U billinguser -d billing"]
        interval    = 10
        timeout     = 5
        retries     = 5
        startPeriod = 60
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "billing-db"
        }
      }
    },
    {
      name      = "billing-app"
      image     = "${aws_ecr_repository.billing_app.repository_url}:v1"
      memory    = 256
      essential = true
      dependsOn = [
        { containerName = "billing-database", condition = "HEALTHY" }
      ]
      environment = [
        { name = "BILLING_DB_HOST", value = "localhost" },
        { name = "BILLING_DB_PORT", value = "5432" },
        { name = "BILLING_DB_NAME", value = "billing" },
        { name = "BILLING_DB_USER", value = "billinguser" },
        { name = "RABBITMQ_HOST", value = "rabbitmq.local" },
        { name = "RABBITMQ_PORT", value = "5672" },
        { name = "RABBITMQ_USER", value = "rabbitmq_user" },
        { name = "RABBITMQ_QUEUE", value = "billing_queue" }
      ]
      secrets = [
        { name = "BILLING_DB_PASSWORD", valueFrom = aws_ssm_parameter.billing_db_password.arn },
        { name = "RABBITMQ_PASSWORD", valueFrom = aws_ssm_parameter.rabbitmq_password.arn }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "billing-app"
        }
      }
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

  volume {
    name = "inventory-db-data"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.db_data.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.inventory_db.id
        iam             = "DISABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "inventory-database"
      image     = "postgres:13-alpine"
      memory    = 512
      essential = true
      environment = [
        { name = "POSTGRES_DB", value = "inventory" },
        { name = "POSTGRES_USER", value = "inventoryuser" },
        { name = "PGDATA", value = "/data/inventory/pgdata" }
      ]
      secrets     = [{ name = "POSTGRES_PASSWORD", valueFrom = aws_ssm_parameter.inventory_db_password.arn }]
      mountPoints = [{ sourceVolume = "inventory-db-data", containerPath = "/data/inventory", readOnly = false }]
      healthCheck = {
        command     = ["CMD-SHELL", "pg_isready -U inventoryuser -h localhost"]
        interval    = 10
        timeout     = 5
        retries     = 10
        startPeriod = 120
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "inventory-db"
        }
      }
    },
    {
      name      = "inventory-app"
      image     = "${aws_ecr_repository.inventory_app.repository_url}:v1"
      memory    = 512
      essential = true
      dependsOn = [
        { containerName = "inventory-database", condition = "HEALTHY" }
      ]
      portMappings = [{ containerPort = 8080, hostPort = 8080, protocol = "tcp" }]
      environment = [
        { name = "INVENTORY_DB_HOST", value = "localhost" },
        { name = "INVENTORY_DB_PORT", value = "5432" },
        { name = "INVENTORY_DB_NAME", value = "inventory" },
        { name = "INVENTORY_DB_USER", value = "inventoryuser" },
        { name = "INVENTORY_PORT", value = "8080" }
      ]
      secrets = [{ name = "INVENTORY_DB_PASSWORD", valueFrom = aws_ssm_parameter.inventory_db_password.arn }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "inventory-app"
        }
      }
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

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  network_configuration {
    subnets         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_gateway.arn
    container_name   = "api-gateway"
    container_port   = 3000
  }
  # ADDED: ensures ALB and both listeners are fully created before ECS service
  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener.https,
    aws_lb.main,
    aws_ecs_service.rabbitmq_service,
    aws_ecs_service.billing_service,
    aws_ecs_service.inventory_service,
  ]
}

resource "aws_ecs_service" "rabbitmq_service" {
  name            = "rabbitmq-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.rabbitmq.arn
  desired_count   = 1
  launch_type     = "EC2"

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  network_configuration {
    subnets         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.rabbitmq.arn
  }
}

resource "aws_ecs_service" "billing_service" {
  name            = "billing-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.billing_stack.arn
  desired_count   = 1
  launch_type     = "EC2"

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  depends_on = [
    aws_efs_mount_target.private_1,
    aws_efs_mount_target.private_2
  ]

  network_configuration {
    subnets         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
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

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  depends_on = [
    aws_efs_mount_target.private_1,
    aws_efs_mount_target.private_2
  ]

  network_configuration {
    subnets         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.inventory.arn
  }
}

# ==========================================
# Service Discovery (Cloud Map)
# ==========================================
resource "aws_service_discovery_private_dns_namespace" "local" {
  name        = "local"
  description = "Private DNS namespace for microservices"
  vpc         = aws_vpc.main.id
}

resource "aws_service_discovery_service" "billing" {
  name = "billing-app"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.local.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config { failure_threshold = 1 }
}

resource "aws_service_discovery_service" "rabbitmq" {
  name = "rabbitmq"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.local.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config { failure_threshold = 1 }
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
  health_check_custom_config { failure_threshold = 1 }
}