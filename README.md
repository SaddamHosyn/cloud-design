# Cloud Design — Microservices on AWS ECS

A production-grade, cloud-native microservices platform deployed on **AWS ECS (EC2 launch type)** using **Terraform** as the sole Infrastructure-as-Code tool. The system implements a movie inventory CRUD API with an asynchronous billing pipeline backed by RabbitMQ, secured by **AWS Cognito JWT authentication**, and monitored via **CloudWatch**.

This project demonstrates the end-to-end lifecycle of deploying, securing, monitoring, and scaling a distributed system in a **public cloud** environment. By leveraging AWS managed services, the solution eliminates the operational overhead of on-premises infrastructure — no physical servers to rack, no OS patching, no capacity forecasting — while gaining elastic scalability, built-in high availability across multiple Availability Zones, and a pay-as-you-go cost model.

---

## Table of Contents

- [Why Cloud and Why AWS](#why-cloud-and-why-aws)
- [Architecture Overview](#architecture-overview)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Infrastructure Setup](#infrastructure-setup)
- [Building and Pushing Docker Images](#building-and-pushing-docker-images)
- [Deployment](#deployment)
- [Authentication (AWS Cognito)](#authentication-aws-cognito)
- [API Reference](#api-reference)
- [Billing Resilience (Message Queue)](#billing-resilience-message-queue)
- [Monitoring and Logging](#monitoring-and-logging)
- [Auto-Scaling](#auto-scaling)
- [Security](#security)
- [Verification Commands](#verification-commands)
- [Cost Optimization](#cost-optimization)
- [Challenges and Lessons Learned](#challenges-and-lessons-learned)
- [Future Improvements](#future-improvements)
- [Teardown](#teardown)

---

## Why Cloud and Why AWS

### Cloud vs On-Premises

Deploying this solution in the cloud rather than on-premises provides several critical advantages:

| Factor | On-Premises | Cloud (AWS) |
|---|---|---|
| **Scalability** | Buy and provision hardware weeks in advance | Scale from 1 to 5+ tasks in under 60 seconds via auto-scaling |
| **Availability** | Single datacenter, single point of failure | Multi-AZ deployment across 2 Availability Zones by default |
| **Cost model** | Large upfront CapEx for servers | Pay-per-use OpEx — stop resources and stop paying |
| **Maintenance** | Team manages OS patches, networking, storage | AWS manages underlying infrastructure |
| **Time to deploy** | Weeks for procurement and setup | `terraform apply` provisions the entire stack in ~5 minutes |

### Why AWS Specifically

AWS was selected for this project based on the following factors:

- **ECS (Elastic Container Service)** — a mature container orchestration platform that integrates natively with ALB, Cloud Map, ECR, and CloudWatch, reducing integration complexity compared to self-managed Kubernetes
- **Cognito** — provides managed user authentication with JWT issuance and JWKS endpoints, eliminating the need to build a custom auth service
- **Cloud Map** — enables DNS-based service discovery so microservices find each other by name (`inventory-app.local`, `rabbitmq.local`) without hardcoded IPs
- **EFS** — provides shared, encrypted, multi-AZ persistent storage that survives container restarts — critical for database data
- **SSM Parameter Store** — securely stores passwords as `SecureString` entries, injected directly into containers at runtime
- **CloudWatch** — unified logging and monitoring with custom dashboards, no third-party tools required

### Cloud Deployment Models

This project uses the **public cloud** model (shared AWS infrastructure, isolated via VPC). For organizations with regulatory constraints, AWS also supports **private cloud** (AWS Outposts) and **hybrid cloud** (Direct Connect + on-prem integration). The architecture is portable — the same Terraform modules could target a private or hybrid deployment with minimal changes to the provider configuration.

---

## Architecture Overview

```
                        ┌──────────────────────────────────────────────┐
                        │               AWS Cloud (eu-north-1)         │
                        │                                              │
  Internet              │   ┌──────────────────────────────────┐       │
     │                  │   │        Public Subnets (2 AZs)    │       │
     ▼                  │   │  ┌────────────────────────────┐  │       │
┌─────────┐             │   │  │   Application Load Balancer│  │       │
│  Client  │────────────┼───┼──│   (HTTP :80 / HTTPS :443)  │  │       │
└─────────┘             │   │  └──────────┬─────────────────┘  │       │
                        │   └─────────────┼────────────────────┘       │
                        │                 │                            │
                        │   ┌─────────────▼────────────────────┐       │
                        │   │       Private Subnets (2 AZs)    │       │
                        │   │                                  │       │
                        │   │  ┌───────────────────────────┐   │       │
                        │   │  │     API Gateway (ECS)     │   │       │
                        │   │  │  JWT Cognito Validation   │   │       │
                        │   │  │  Port 3000                │   │       │
                        │   │  └─────┬──────────┬──────────┘   │       │
                        │   │        │          │              │       │
                        │   │   ┌────▼────┐ ┌───▼───────────┐ │       │
                        │   │   │Inventory│ │  RabbitMQ     │ │       │
                        │   │   │ Stack   │ │  (standalone) │ │       │
                        │   │   │ (ECS)   │ │  Port 5672    │ │       │
                        │   │   │         │ └───┬───────────┘ │       │
                        │   │   │ Postgres│     │             │       │
                        │   │   │ + App   │ ┌───▼───────────┐ │       │
                        │   │   │  :8080  │ │ Billing Stack │ │       │
                        │   │   └────┬────┘ │ Postgres+App  │ │       │
                        │   │        │      └───┬───────────┘ │       │
                        │   │   ┌────▼──────────▼──────┐      │       │
                        │   │   │    EFS (Encrypted)    │      │       │
                        │   │   │  Persistent Storage   │      │       │
                        │   │   └───────────────────────┘      │       │
                        │   └──────────────────────────────────┘       │
                        └──────────────────────────────────────────────┘
```

### Key Design Decisions

| Concern | Decision | Rationale |
|---|---|---|
| **Orchestration** | ECS on EC2 (not Fargate) | Full control over instance types, cost-effective for learning |
| **Networking** | `awsvpc` mode | Each task gets its own ENI and private IP for security isolation |
| **Service Discovery** | AWS Cloud Map (`.local` namespace) | DNS-based discovery without hardcoded IPs |
| **Authentication** | Cognito JWT at application level | API Gateway validates JWTs directly using PyJWT + JWKS |
| **Message Queue** | RabbitMQ as a standalone ECS service | Decoupled from billing stack to avoid memory pressure and enable independent scaling |
| **Persistence** | EFS with Access Points | Encrypted, multi-AZ, POSIX-enforced ownership per service |
| **Secrets** | SSM Parameter Store (SecureString) | No credentials in code or environment variables |
| **IaC** | Terraform (~10 `.tf` files) | Declarative, reproducible, and auditable infrastructure |

### Component Summary

| Service | Task Definition | Containers | Port | Service Discovery |
|---|---|---|---|---|
| **API Gateway** | `api-gateway-task` | api-gateway | 3000 | — (behind ALB) |
| **RabbitMQ** | `rabbitmq-task` | rabbitmq | 5672, 15672 | `rabbitmq.local` |
| **Billing Stack** | `billing-stack-task` | billing-database, billing-app | 5432, internal | `billing-app.local` |
| **Inventory Stack** | `inventory-stack-task` | inventory-database, inventory-app | 5432, 8080 | `inventory-app.local` |

---

## Repository Structure

```
cloud-design/
├── api-gateway/              # API Gateway microservice (Flask + RabbitMQ publisher)
│   ├── Dockerfile            # Multi-stage build (python:3.9-slim)
│   ├── entrypoint.sh         # Container entrypoint script
│   ├── requirements.txt      # Python dependencies (Flask, pika, PyJWT)
│   ├── server.py             # Main entry point
│   └── app/
│       └── __init__.py       # Routes, Cognito JWT verification, proxy logic
├── billing-app/              # Billing consumer microservice (RabbitMQ consumer)
│   ├── Dockerfile            # Multi-stage build
│   ├── server.py             # RabbitMQ consumer entry point
│   └── app/                  # Flask app + consumer logic
├── inventory-app/            # Inventory CRUD microservice (Flask + PostgreSQL)
│   ├── Dockerfile            # Multi-stage build
│   ├── server.py             # Flask server entry point
│   └── app/                  # Flask app, models, routes
├── billing-database/         # PostgreSQL config for billing
├── inventory-database/       # PostgreSQL config for inventory
├── rabbitmq/                 # RabbitMQ configuration
├── infra/terraform/          # All Terraform IaC files
│   ├── main.tf               # Provider configuration (AWS, TLS, Random)
│   ├── variables.tf          # Input variables (region, VPC CIDR)
│   ├── vpc.tf                # VPC, subnets, NAT Gateway, security groups
│   ├── alb.tf                # ALB, target groups, HTTP/HTTPS listeners
│   ├── ecs.tf                # ECS cluster, task definitions, services, Cloud Map
│   ├── ecr.tf                # ECR repositories with vulnerability scanning
│   ├── efs.tf                # EFS file system, mount targets, access points
│   ├── cognito.tf            # Cognito user pool, app client, test user
│   ├── autoscaling.tf        # ECS service auto-scaling policies
│   └── dashboard.tf          # CloudWatch monitoring dashboard
├── openapi.yaml              # OpenAPI 3.0 specification
├── CRUD_Master.postman_collection.json  # Postman collection for testing
└── README.md                 # This file
```

---

## Prerequisites

- **AWS CLI v2** — configured with credentials (`aws configure`)
- **Terraform** ≥ 1.5
- **Docker** — for building container images
- **An AWS account** with permissions for ECS, ECR, VPC, ALB, EFS, Cognito, CloudWatch, SSM, IAM
- **Region**: `eu-north-1` (Stockholm) — configurable in `variables.tf`

---

## Infrastructure Setup

### 1. Initialize Terraform

```bash
cd infra/terraform
terraform init
```

### 2. Review the Plan

```bash
terraform plan
```

This shows all resources to be created: VPC, subnets, NAT Gateway, ALB, ECS cluster, task definitions, EFS, Cognito, CloudWatch dashboard, auto-scaling policies, and more.

### 3. Apply the Infrastructure

```bash
terraform apply
```

Terraform will output the ALB DNS name:

```
alb_url = "cloud-design-alb-XXXXXXXXX.eu-north-1.elb.amazonaws.com"
```

---

## Building and Pushing Docker Images

All three custom microservices must be built and pushed to ECR.

### Authenticate Docker with ECR

```bash
aws ecr get-login-password --region eu-north-1 | \
  docker login --username AWS --password-stdin \
  <ACCOUNT_ID>.dkr.ecr.eu-north-1.amazonaws.com
```

### Build and Push Each Service

```bash
# API Gateway
cd api-gateway
docker build --platform linux/amd64 -t cloud-design-api-gateway:v1 .
docker tag cloud-design-api-gateway:v1 <ACCOUNT_ID>.dkr.ecr.eu-north-1.amazonaws.com/cloud-design-api-gateway:v1
docker push <ACCOUNT_ID>.dkr.ecr.eu-north-1.amazonaws.com/cloud-design-api-gateway:v1

# Billing App
cd ../billing-app
docker build --platform linux/amd64 -t cloud-design-billing-app:v1 .
docker tag cloud-design-billing-app:v1 <ACCOUNT_ID>.dkr.ecr.eu-north-1.amazonaws.com/cloud-design-billing-app:v1
docker push <ACCOUNT_ID>.dkr.ecr.eu-north-1.amazonaws.com/cloud-design-billing-app:v1

# Inventory App
cd ../inventory-app
docker build --platform linux/amd64 -t cloud-design-inventory-app:v1 .
docker tag cloud-design-inventory-app:v1 <ACCOUNT_ID>.dkr.ecr.eu-north-1.amazonaws.com/cloud-design-inventory-app:v1
docker push <ACCOUNT_ID>.dkr.ecr.eu-north-1.amazonaws.com/cloud-design-inventory-app:v1
```

> **Note:** Use `--platform linux/amd64` if building on an Apple Silicon Mac.

### Docker Image Optimization

All Dockerfiles use **multi-stage builds**:
- **Stage 1 (builder):** Installs build dependencies (gcc) and Python packages into a virtual environment
- **Stage 2 (runtime):** Copies only the virtual environment and application code into a clean `python:3.9-slim` image
- A non-root `appuser` is created for security

---

## Deployment

After `terraform apply` and image pushes, ECS automatically deploys the services. Verify with:

```bash
# Check all services are RUNNING
aws ecs describe-services \
  --cluster cloud-design-cluster-v2 \
  --services api-gateway-service rabbitmq-service billing-service inventory-service \
  --query 'services[*].{Service:serviceName,Running:runningCount,Desired:desiredCount}' \
  --output table

# List running tasks
aws ecs list-tasks --cluster cloud-design-cluster-v2 --desired-status RUNNING

# Check service discovery DNS records
aws route53 list-resource-record-sets \
  --hosted-zone-id <HOSTED_ZONE_ID> \
  --query 'ResourceRecordSets[?Type==`A`].{Name:Name,IP:ResourceRecords[0].Value}' \
  --output table
```

---

## Authentication (AWS Cognito)

All business endpoints (`/api/movies/*`, `/api/billing`) require a valid **Cognito JWT** in the `Authorization: Bearer <token>` header. Health/readiness endpoints (`/health`, `/ready`) are unauthenticated.

### How It Works

1. Cognito User Pool issues JWTs upon successful login
2. The API Gateway application validates tokens using the JWKS endpoint
3. Both `id_token` and `access_token` are accepted
4. Token signature, expiration, issuer, and audience/client_id are verified

### Obtaining a Token

A test user is provisioned by Terraform:
- **Username:** `audit-user@example.com`
- **Temporary Password:** `TempPass123!`

#### Step 1: First Login (Set Permanent Password)

```bash
# Initial auth (returns NEW_PASSWORD_REQUIRED challenge)
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id <APP_CLIENT_ID> \
  --auth-parameters USERNAME=audit-user@example.com,PASSWORD=TempPass123!

# Complete challenge with new password
aws cognito-idp respond-to-auth-challenge \
  --client-id <APP_CLIENT_ID> \
  --challenge-name NEW_PASSWORD_REQUIRED \
  --challenge-responses USERNAME=audit-user@example.com,NEW_PASSWORD=NewSecurePass123! \
  --session <SESSION_FROM_PREVIOUS_RESPONSE>
```

#### Step 2: Subsequent Logins

```bash
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id <APP_CLIENT_ID> \
  --auth-parameters USERNAME=audit-user@example.com,PASSWORD=NewSecurePass123!
```

The response contains `AccessToken` and `IdToken`. Use either as the Bearer token.

### Unauthenticated Request (Should Be Rejected)

```bash
# No token → 401 Unauthorized
curl http://<ALB_URL>/api/movies
# Response: {"error":"Unauthorized","message":"Missing Bearer token"}
```

---

## API Reference

**Base URL:** `http://<ALB_DNS_NAME>`

All endpoints except `/health` and `/ready` require `Authorization: Bearer <JWT>`.

### Movies (Inventory)

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/movies` | List all movies (supports `?title=` filter) |
| `POST` | `/api/movies` | Create a new movie |
| `GET` | `/api/movies/{id}` | Get a movie by ID |
| `PUT` | `/api/movies/{id}` | Update a movie (partial updates) |
| `DELETE` | `/api/movies/{id}` | Delete a movie |
| `DELETE` | `/api/movies` | Delete all movies |

#### Example: Create a Movie

```bash
TOKEN="<your-jwt-token>"

curl -X POST http://<ALB_URL>/api/movies \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Inception", "description": "A mind-bending thriller"}'
```

#### Example: Get All Movies

```bash
curl http://<ALB_URL>/api/movies \
  -H "Authorization: Bearer $TOKEN"
```

### Billing (Async via RabbitMQ)

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/billing` | Submit order (queued in RabbitMQ) |

```bash
curl -X POST http://<ALB_URL>/api/billing \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "20", "number_of_items": "5", "total_amount": "49.99"}'
```

Returns `200 OK` immediately. The order is published to the `billing_queue` in RabbitMQ and processed asynchronously by the billing-app consumer.

### Health Check (No Auth Required)

```bash
curl http://<ALB_URL>/health
```

For a complete API specification, see [openapi.yaml](openapi.yaml).

---

## Billing Resilience (Message Queue)

The billing system demonstrates **message queue resilience**:

1. Orders are published to a **durable** RabbitMQ queue (`billing_queue`)
2. Messages have `delivery_mode=2` (persistent — survive RabbitMQ restarts)
3. The billing-app consumes messages asynchronously

### Resilience Test

> [!IMPORTANT]
> A fully detailed, exact step-by-step runbook for this audit scenario (complete with specific terminal windows, prompt markers, SSM targets, and PostgreSQL verification commands) is available at [billing_resilience_runbook.md](billing_resilience_runbook.md).


```bash
# 1. Stop the billing service
aws ecs update-service --cluster cloud-design-cluster-v2 \
  --service billing-service --desired-count 0

# 2. Send a billing request (should still return 200 — queued in RabbitMQ)
curl -X POST http://<ALB_URL>/api/billing \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"99","number_of_items":"2","total_amount":"19.99"}'

# 3. Restart billing service
aws ecs update-service --cluster cloud-design-cluster-v2 \
  --service billing-service --desired-count 1

# 4. Check billing-app logs to verify the queued message was processed
aws logs filter-log-events \
  --log-group-name /ecs/cloud-design \
  --log-stream-name-prefix billing-app \
  --start-time $(( $(date +%s) - 300 ))000 \
  --query 'events[*].message'
```

---

## Monitoring and Logging

### CloudWatch Logs

All containers log to the `/ecs/cloud-design` log group with per-service stream prefixes:
- `api-gateway/*`
- `rabbitmq/*`
- `billing-db/*`, `billing-app/*`
- `inventory-db/*`, `inventory-app/*`

```bash
# Tail logs in real time
aws logs tail /ecs/cloud-design --follow --since 5m

# Filter for a specific service
aws logs filter-log-events \
  --log-group-name /ecs/cloud-design \
  --log-stream-name-prefix api-gateway
```

### CloudWatch Dashboard

A custom dashboard (`cloud-design-dashboard`) is provisioned with 4 widgets:
- **ECS Cluster CPU Utilization** (aggregate)
- **ECS Cluster Memory Utilization** (aggregate)
- **Per-Service CPU Utilization** (api-gateway, billing, inventory)
- **Per-Service Memory Utilization** (api-gateway, billing, inventory)

View it in the [CloudWatch Console](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#dashboards:name=cloud-design-dashboard).

---

## Auto-Scaling

Each ECS service has **Target Tracking Scaling** based on CPU utilization:

| Service | Min Tasks | Max Tasks | CPU Target | Scale-Out Cooldown | Scale-In Cooldown |
|---|---|---|---|---|---|
| api-gateway-service | 1 | 5 | 70% | 60s | 300s |
| billing-service | 1 | 5 | 70% | 60s | 300s |
| inventory-service | 1 | 5 | 70% | 60s | 300s |

The underlying EC2 Auto Scaling Group scales from **3 to 8 instances** to support increased task demand.

---

## Security

### Network Security

- **VPC Isolation**: All ECS tasks run in **private subnets** with no public IPs
- **NAT Gateway**: Private tasks access the internet (ECR, CloudWatch) through a NAT Gateway in a public subnet
- **Security Groups**:
  - ALB SG → allows inbound 80/443 from `0.0.0.0/0`
  - ECS SG → allows inbound only from ALB SG + self-referencing rule for east-west traffic
  - EFS SG → allows NFS (2049) only from ECS SG

### Data Security

- **HTTPS**: ALB serves traffic on port 443 with TLS (ACM certificate)
- **HTTP Redirect**: Port 80 forwards traffic to the API gateway
- **EFS Encryption**: Data at rest is encrypted (`encrypted = true`)
- **EFS Access Points**: POSIX UID/GID enforcement per database (UID 70 for PostgreSQL)

### Secrets Management

All passwords are auto-generated and stored in **SSM Parameter Store** as `SecureString`:

| Secret | SSM Path |
|---|---|
| RabbitMQ password | `/cloud-design/rabbitmq/password` |
| Billing DB password | `/cloud-design/billing-db/password` |
| Inventory DB password | `/cloud-design/inventory-db/password` |

Passwords are injected into containers via the ECS `secrets` block — never exposed in environment variables or code.

### Authentication

- **Cognito User Pool** with password policy (8+ chars, uppercase, lowercase, numbers)
- All API endpoints require valid JWT (except `/health` and `/ready`)
- Tokens are validated at the application level using the Cognito JWKS endpoint

### Container Image Security

- **ECR vulnerability scanning** enabled (`scan_on_push = true`) on all repositories
- Non-root users inside containers (`appuser`)
- Multi-stage builds minimize attack surface

---

## Verification Commands

These commands can be used during an audit to demonstrate the deployment:

```bash
# ─── Cluster and Services ───
aws ecs list-clusters
aws ecs describe-services --cluster cloud-design-cluster-v2 \
  --services api-gateway-service rabbitmq-service billing-service inventory-service \
  --query 'services[*].{Name:serviceName,Status:status,Running:runningCount,Desired:desiredCount}' \
  --output table

# ─── Task Details ───
aws ecs list-tasks --cluster cloud-design-cluster-v2 --desired-status RUNNING
aws ecs describe-tasks --cluster cloud-design-cluster-v2 \
  --tasks <TASK_ARN> --query 'tasks[0].containers[*].{Name:name,Status:lastStatus}'

# ─── Task Definitions ───
aws ecs describe-task-definition --task-definition api-gateway-task
aws ecs describe-task-definition --task-definition rabbitmq-task
aws ecs describe-task-definition --task-definition billing-stack-task
aws ecs describe-task-definition --task-definition inventory-stack-task

# ─── Load Balancer ───
aws elbv2 describe-load-balancers --names cloud-design-alb
aws elbv2 describe-target-health --target-group-arn <TG_ARN>

# ─── Auto-Scaling ───
aws application-autoscaling describe-scaling-policies --service-namespace ecs

# ─── ECR Vulnerability Scanning ───
aws ecr describe-image-scan-findings \
  --repository-name cloud-design-api-gateway --image-id imageTag=v1

# ─── Cognito ───
aws cognito-idp describe-user-pool --user-pool-id <POOL_ID>
aws cognito-idp describe-user-pool-client --user-pool-id <POOL_ID> --client-id <CLIENT_ID>

# ─── Terraform ───
cd infra/terraform
terraform plan   # Should show "No changes"
terraform apply  # Confirms infrastructure matches desired state
```

---

## Teardown

To destroy all AWS resources:

```bash
cd infra/terraform
terraform destroy
```

> **Warning:** This deletes all infrastructure including EFS data, Cognito users, and CloudWatch logs.

---

## Cost Optimization

- **t3.small** instances — balance of cost and capability for a microservices workload
- **Right-sized containers** — memory allocations tuned per service (256–1024 MiB)
- **Auto-scaling** — scales down to 1 task per service during low traffic
- **Single NAT Gateway** — reduces cost vs. one-per-AZ (acceptable for non-production)
- **7-day log retention** — prevents unbounded CloudWatch Logs costs

---

## Postman Collection

A pre-configured Postman collection is included at [`CRUD_Master.postman_collection.json`](CRUD_Master.postman_collection.json).

### Variables

| Variable | Description |
|---|---|
| `baseUrl` | ALB DNS URL |
| `accessToken` | Cognito JWT (paste after login) |
| `movieId` | ID of a movie for single-resource operations |

Import the collection into Postman, set the `accessToken` variable, and run the requests.

---

## Challenges and Lessons Learned

### 1. EFS Volume Permission Errors

**Problem:** ECS tasks failed with `CannotCreateContainerError` because the Docker agent attempted to `chown` EFS mount paths, which EFS Access Points prohibit.

**Solution:** Moved mount paths to neutral subdirectories (e.g., `/data/billing/pgdata` instead of `/var/lib/postgresql/data`) and aligned Access Point POSIX UIDs with container users (UID 70 for PostgreSQL).

### 2. RabbitMQ Memory Watermark Crash Loop

**Problem:** When RabbitMQ was bundled inside the billing task (3 containers sharing 1536 MiB), it triggered `system_memory_high_watermark` on every startup and entered a crash loop.

**Solution:** Extracted RabbitMQ into its own standalone ECS service with a dedicated 512 MiB allocation and its own Service Discovery entry (`rabbitmq.local`). This also improves operational independence — RabbitMQ can be restarted without affecting the billing database.

### 3. Service Discovery DNS Propagation

**Problem:** After task restarts, the Cloud Map DNS records (`billing-app.local`) sometimes took time to propagate, causing `Name or service not known` errors from the API gateway.

**Solution:** Configured TTL=10s on DNS records and ensured the ECS service health check custom config has `failure_threshold = 1` so unhealthy instances are quickly deregistered and replaced.

### 4. Cognito Authentication Migration

**Problem:** Initially, Cognito was configured as an ALB-level `authenticate-cognito` action, which requires a hosted UI domain and OAuth flows — complex for API-only usage.

**Solution:** Moved to **application-level JWT validation** using PyJWT + Cognito JWKS. The API Gateway downloads the signing keys from Cognito's `/.well-known/jwks.json` endpoint and validates every request's Bearer token directly. This gives full control over error messages and works seamlessly with programmatic clients (curl, Postman).

---

## Future Improvements

If this project were to evolve into a production system, the following modifications would be considered:

| Area | Current State | Future Improvement |
|---|---|---|
| **Database** | Containerized PostgreSQL on EFS | Migrate to **Amazon RDS** for automated backups, replication, and patching |
| **Compute** | ECS on EC2 (self-managed instances) | Evaluate **AWS Fargate** to eliminate EC2 instance management entirely |
| **TLS Certificate** | Self-signed ACM cert | Use **ACM with a real domain** + Route 53 for trusted HTTPS |
| **CI/CD** | Manual `docker build` + `docker push` | Implement **CodePipeline + CodeBuild** for automated image builds on git push |
| **Multi-region** | Single region (eu-north-1) | Deploy across 2+ regions with Route 53 latency-based routing |
| **New microservices** | 3 services | Cloud Map allows adding new services by registering them in the `local` namespace — no infrastructure changes needed |
| **Cloud portability** | AWS-only | Terraform's provider model means the same patterns could target GCP or Azure with provider swaps |
| **Observability** | CloudWatch logs + dashboard | Add **X-Ray** for distributed tracing across API Gateway → RabbitMQ → Billing App |

---

## Documentation Approach

This documentation was structured to serve both **operators** (who need to deploy and maintain the system) and **auditors** (who need to verify compliance):

- **Architecture diagrams** provide a visual overview before diving into details
- **Step-by-step instructions** with copy-pasteable commands ensure reproducibility
- **Decision tables** (Key Design Decisions, Cost Optimization) explain *why* each choice was made, not just *what* was done
- **Verification commands** give auditors ready-made commands to independently confirm the deployment state
- **The OpenAPI spec** (`openapi.yaml`) and **Postman collection** provide machine-readable and interactive API documentation
- **Terraform files** serve as living documentation — the infrastructure is fully described in code, ensuring the docs never drift from reality
