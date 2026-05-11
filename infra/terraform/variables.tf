variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "eu-north-1" # Use your preferred region (e.g. us-east-1)
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}