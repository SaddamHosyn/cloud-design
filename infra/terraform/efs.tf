# ==========================================
# EFS File System for Database Persistence
# ==========================================
resource "aws_efs_file_system" "db_data" {
  creation_token = "cloud-design-db-data"
  encrypted      = true

  tags = {
    Name = "cloud-design-db-efs"
  }
}

# Security Group for EFS (allows NFS from ECS tasks)
resource "aws_security_group" "efs_sg" {
  name        = "efs-security-group"
  description = "Allow NFS traffic from ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
    description     = "Allow NFS from ECS tasks"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EFS Mount Targets in Private Subnets
resource "aws_efs_mount_target" "private_1" {
  file_system_id  = aws_efs_file_system.db_data.id
  subnet_id       = aws_subnet.private_1.id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "private_2" {
  file_system_id  = aws_efs_file_system.db_data.id
  subnet_id       = aws_subnet.private_2.id
  security_groups = [aws_security_group.efs_sg.id]
}

# ==========================================
# EFS Access Points
# ==========================================
resource "aws_efs_access_point" "billing_db" {
  file_system_id = aws_efs_file_system.db_data.id

  posix_user {
    uid = 70
    gid = 70
  }

  root_directory {
    path = "/billing-db-data-v3"
    creation_info {
      owner_uid   = 70
      owner_gid   = 70
      permissions = "0700"
    }
  }

  tags = {
    Name = "billing-db-access-point"
  }
}

resource "aws_efs_access_point" "inventory_db" {
  file_system_id = aws_efs_file_system.db_data.id

  posix_user {
    uid = 70
    gid = 70
  }

  root_directory {
    path = "/inventory-db-data-v3"
    creation_info {
      owner_uid   = 70
      owner_gid   = 70
      permissions = "0700"
    }
  }

  tags = {
    Name = "inventory-db-access-point"
  }
}

resource "aws_efs_access_point" "rabbitmq" {
  file_system_id = aws_efs_file_system.db_data.id

  posix_user {
    uid = 100
    gid = 101
  }

  root_directory {
    path = "/rabbitmq-data-v3"
    creation_info {
      owner_uid   = 100
      owner_gid   = 101
      permissions = "0700"
    }
  }

  tags = {
    Name = "rabbitmq-access-point"
  }
}