# Cloud-Design Project

### AWS Microservices Deployment — Full Project Reference

---

## 🎯 Objective

- Deploy a microservices-based app on AWS
- Reuse and build on work from previous projects: crud-master, play-with-containers, and orchestrator
- Set up monitoring, logging, and auto-scaling
- Secure databases (VPC-only access)
- Add managed authentication (AWS Cognito or similar) for public-facing apps
- Handle varying workloads and unexpected failures

---

## 🧱 Microservices to Deploy

- **inventory-database** — PostgreSQL, port 5432
- **billing-database** — PostgreSQL, port 5432
- **inventory-app** — connects to inventory-database, port 8080
- **billing-app** — connects to billing-database + consumes RabbitMQ messages, port 8080
- **RabbitMQ** — message queue server
- **api-gateway-app** — routes all incoming requests to other services, port 3000

---

## 🏗️ Architecture Design Principles

- **Scalability** — use AWS Auto Scaling to handle load changes
- **Availability** — fault-tolerant design, no single point of failure
- **Security** — encrypt data at rest and in transit, VPC-only DB access, secure API endpoints
- **Cost-effectiveness** — right-size resources, avoid waste
- **Simplicity** — don't over-engineer; only add what's needed

---

## 🔧 Infrastructure as Code (Terraform)

- Use Terraform to provision all AWS resources
- Covers: EC2 instances, networking (VPC, subnets, security groups), storage (S3 or similar), container infrastructure

---

## 🐳 Containerization (Docker)

- Build Docker images for every microservice
- Reuse containerization knowledge and artifacts from play-with-containers
- Optimize Dockerfiles — reduce image size and build time

---

## 🚀 Deployment — ECS

- Use AWS ECS for container orchestration
- Reuse and adapt solutions from previous projects: crud-master, play-with-containers, and especially orchestrator
- Use the previous orchestrator project as a starting point
- Apply AWS Elastic Load Balancer for load balancing
- Services must communicate securely with each other

---

## 📊 Monitoring & Logging

- **CloudWatch** — AWS-native metrics and alerts
- **Prometheus + Grafana** — custom metrics visualization
- **ELK Stack** — log aggregation and search (Elasticsearch, Logstash, Kibana)

---

## ⚙️ Optimization

- Set up auto-scaling policies based on load
- Test under different traffic scenarios
- Adjust resource allocation based on results

---

## 🔐 Security

- **AWS Certificate Manager** — HTTPS/TLS
- **Amazon API Gateway** — secure API endpoints
- **AWS Inspector** — vulnerability scanning
- **AWS Cognito (or similar)** — managed auth for public-facing apps
- Databases and private resources accessible only from within the VPC

---

## 💰 Cost Management

- Understand the pricing model before deploying
- Set up billing alerts on the AWS dashboard
- Delete/stop unused resources regularly
- Use Spot/Reserved instances where applicable
- Use AWS cost management tools to spot waste

---

## 📁 Documentation (README.md)

- Architecture diagrams (well-structured)
- Description of every component
- Explanation of design decisions
- Setup, configuration, prerequisites, and usage instructions
- Must be submitted as part of the solution

---

## 📚 Prior Knowledge Expected

- Basic DevOps concepts
- Docker familiarity
- AWS fundamentals
- Terraform basics
- Monitoring tools: Prometheus, Grafana, ELK
- Understanding of previous projects: crud-master, play-with-containers, and orchestrator

---

## 🎭 Role Play Session

- You'll act as a Cloud Engineer presenting your solution
- Be ready to justify architecture decisions
- Explain trade-offs and alternatives you considered
- Be ready to explain how you reused and improved work from crud-master, play-with-containers, and orchestrator
- Tests communication, critical thinking, and depth of understanding

---

## 📋 Cloud-Design Project — Audit Questions

### 📁 Section 1: General Repository Check

**Q1.** Are all the required files present in the repository, including the README.md, source code for microservices, deployment scripts, and configuration files for IaC, containerization, and orchestration tools?

---

### 🎭 Section 2: Role Play — Stakeholder Scenario

**Q2.** What is the cloud and what are its associated benefits?

**Q3.** Why is deploying the solution in the cloud preferred over on-premises?

**Q4.** How would you differentiate between public, private, and hybrid cloud?

**Q5.** What drove your decision to select AWS for this project, and what factors did you consider?

**Q6.** Can you describe your microservices application's AWS-based architecture and the interaction between its components?

**Q7.** How did you manage and optimize the cost of your AWS solution?

**Q8.** What measures did you implement to ensure application security on AWS, and what AWS security best practices did you adhere to?

**Q9.** What AWS monitoring and logging tools did you utilize, and how did they assist in identifying and troubleshooting application issues?

**Q10.** Can you describe the AWS auto-scaling policies you implemented and how they help your application accommodate varying workloads?

**Q11.** How did you optimize Docker images for each microservice, and how did it influence build times and image sizes?

**Q12.** If you had to redo this project, what modifications would you make to your approach or the technologies you used?

**Q13.** How can your AWS solution be expanded or altered to cater to future requirements like adding new microservices or migrating to a different cloud provider?

**Q14.** What challenges did you face during the project and how did you address them?

**Q15.** How did you ensure your documentation's clarity and completeness, and what measures did you take to make it easily understandable and maintainable?

---

### 🏗️ Section 3: Architecture Design Review

**Q16.** Does the architecture utilize AWS services to manage varying workloads and scale as required?

**Q17.** Is the architecture designed to be fault-tolerant and maintain high availability, even during component failures?

**Q18.** Does the architecture integrate AWS security best practices, such as data encryption, use of AWS VPC, and secure API endpoints with managed authentication?

**Q19.** Is the architecture designed to be cost-effective on AWS without compromising performance, security, or scalability?

**Q20.** Is the AWS architecture straightforward and free of unnecessary complexity while still fulfilling the project requirements?

---

### 📄 Section 4: Documentation Review (README.md)

**Q21.** Does the README.md file contain all the necessary information about the solution, including prerequisites, setup, configuration, and usage instructions?

**Q22.** Is the documentation clear and complete, with well-structured diagrams and thorough descriptions of all components?

---

### 🚀 Section 5: Deployment Verification

> Auditor: ask the student to demonstrate using `aws cli`, `docker ps`, `aws ecs`, or any other relevant commands.

**Q23.** Are all the microservices running as expected in the cloud environment, with no errors or connectivity issues?

**Q24.** Is the load balancing configured correctly, effectively distributing traffic across the services?

**Q25.** Are the microservices communicating with each other securely, using proper authentication and encryption methods?

---

### ⚙️ Section 6: Infrastructure Setup Evaluation

> Auditor: ask the student to demonstrate using `terraform plan` and/or `terraform apply`.

**Q26.** Is Terraform used effectively to provision and manage resources in the cloud environment?

**Q27.** Does the infrastructure setup follow the architecture design and the project requirements?

---

### 🐳 Section 7: Containerization & Orchestration Assessment

> Auditor: ask the student to demonstrate using `aws cli`, `docker ps`, `aws ecs`, or any other relevant commands.

**Q28.** Are the Dockerfiles optimized for efficient container builds?

**Q29.** Is the orchestration setup (e.g., AWS ECS task definitions and services) configured correctly?

---

### 📊 Section 8: Monitoring & Logging Evaluation

**Q30.** Are the monitoring and logging dashboards providing useful insights into the application's performance and health?

---

### 📈 Section 9: Optimization Assessment

**Q31.** Are the auto-scaling policies configured correctly to handle varying workloads?

**Q32.** Does the application and resource allocation remain efficient under different load scenarios?

---

### 🔐 Section 10: Security Best Practices Check

**Q33.** Has the student implemented security best practices, such as using HTTPS, securing API endpoints, and regularly scanning for vulnerabilities?

---

## ✅ Local vs AWS — What to Do Where

### Local Work

Do all heavy development locally because this is where you can safely run the whole system without worrying about AWS memory, CPU, or hourly charges. This includes Docker builds, Docker Compose for all services, debugging, database setup, RabbitMQ testing, and Terraform writing.

Do these tasks locally:

- Build Docker images for inventory-app, billing-app, api-gateway-app, RabbitMQ, and the two PostgreSQL services.
- Run the full stack with Docker Compose.
- Verify ports and connectivity:
  - inventory-database → 5432
  - billing-database → 5432
  - inventory-app → 8080
  - billing-app → 8080
  - api-gateway-app → 3000
- Test billing-app consuming RabbitMQ messages.
- Create and test environment variables and secrets structure.
- Write Terraform files and run: `terraform fmt`, `terraform validate`, `terraform plan`
- Set up Prometheus + Grafana locally.
- If required, test ELK locally too, though for a budget-friendly submission CloudWatch in AWS plus local observability is usually enough.

### AWS Work

Use AWS only for the minimum cloud proof: network, security, one small compute target, maybe one RDS instance, logging, and documentation-backed evidence that your cloud design works.

Do these tasks in AWS:

- Create the VPC, subnets, route tables, internet gateway, and security groups with Terraform.
- Create IAM roles and policies needed for ECS, EC2 if used, CloudWatch, and any other AWS service you use.
- Create an ECS cluster for the application.
- Push Docker images to a container registry such as Amazon ECR.
- Create ECS task definitions for the microservices.
- Create ECS services to run the containers.
- Use an Application Load Balancer for public traffic.
- Use CloudWatch for basic logs and metrics.
- Optionally use S3 for Terraform state.
- Optionally use one RDS PostgreSQL instance, then keep inventory and billing separate using two databases or two schemas in the same PostgreSQL instance.
- Apply security groups so databases are not publicly open.
- If you need HTTPS for the architecture explanation, document ACM and API Gateway in the design, but do not overbuild paid components unless required.

### Best Split Table

| Area                   | Do Locally                    | Do on AWS                       |
| ---------------------- | ----------------------------- | ------------------------------- |
| Dockerfiles            | Yes                           | No                              |
| Full microservices run | Yes                           | Only minimal demo               |
| Docker Compose         | Yes                           | No                              |
| Terraform authoring    | Yes                           | No                              |
| Terraform apply        | No                            | Yes, only essential infra       |
| ECS task definitions   | Yes                           | Yes                             |
| Monitoring             | Prometheus/Grafana            | CloudWatch basics               |
| Databases              | Two local Postgres containers | One RDS PostgreSQL instance max |
| RabbitMQ               | Local                         | Optional in AWS demo            |
| Load testing           | Local                         | Not necessary unless brief demo |
| README and diagrams    | Yes                           | No                              |

### Suggested Cloud Deployment

For a free-tier-friendly submission, use this simple model:

**Local machine:**

- Full Docker Compose stack
- Terraform code
- Prometheus/Grafana

**AWS:**

- 1 VPC
- 1 ECS cluster
- ECS services for the application containers
- 1 RDS PostgreSQL instance if needed
- CloudWatch
- S3 for state if desired

That is enough to show:

- You understand AWS networking.
- You can provision infrastructure with Terraform.
- You can deploy containers in the cloud.
- You know how to secure database access.
- You understand observability and scaling concepts.

### What NOT To Do

- Do not overbuild the environment with unnecessary managed services.
- Do not leave compute, databases, or load balancers running when you are not actively testing.
- Do not try to run a full production-style highly available setup 24/7 on a strict free-tier mindset, because the project is too large for that budget.

### Execution Order

Follow this order so you do not get stuck:

1. Build and test every service locally with Docker Compose.
2. Make sure app-to-app communication works locally.
3. Write Terraform for VPC, security groups, ECS-related resources, optional RDS, and CloudWatch.
4. Run `terraform plan` locally.
5. Create a minimal AWS deployment.
6. Show only what is necessary in AWS.
7. Stop or destroy resources after demo.

### Practical Rule

> If it can be developed, tested, or demonstrated locally, do it locally. If it must prove AWS knowledge, do that small part in AWS.

---

## 👥 Team AWS Account Access (IMPORTANT — Remember This!)

When working as a two-person team, one person owns the AWS account and grants the teammate access via IAM. Here is exactly how to do it.

### Option 1: IAM User (Simplest — Recommended for This Project)

One person owns the AWS account, then creates an IAM user for the teammate:

1. Go to **IAM → Users → Create User** in the AWS Console.
2. Give them a username.
3. Attach a permission policy — `AdministratorAccess` is easiest, or `PowerUserAccess` if you want to be safer.
4. Enable **Console access** and share the generated password.
5. Share your **Account ID** (found top-right in the AWS console).

The teammate logs in at:

```
https://<your-account-id>.signin.aws.amazon.com/console
```

### Option 2: IAM Identity Center (More Proper, Slightly More Setup)

AWS's recommended way for teams. Go to **IAM Identity Center → Enable**, add users, assign permissions. Better for larger teams but overkill for two people.

### For CLI Access (Terraform, AWS CLI)

After creating the IAM user, also create **Access Keys** so the teammate can use Terraform and AWS CLI:

1. Go to **IAM → Users → your teammate's user → Security credentials → Create access key**.
2. Share the Access Key ID and Secret Access Key securely.
3. Teammate runs on their machine:

```bash
aws configure
# Enter: Access Key ID, Secret Access Key, region (e.g. eu-north-1), output format (json)
```

Then Terraform and AWS CLI will work for them too.

### Practical Tip for This Project

Since you are splitting work (one does Terraform/infra, one does containers/ECS), agree on **one shared AWS account** with the account owner creating an IAM user for the other. That way both can run `terraform apply` and check ECS/CloudWatch without confusion about who deployed what.

### Summary: Who Does What

| Task                        | Person 1 (Account Owner) | Person 2 (IAM User)   |
| --------------------------- | ------------------------ | --------------------- |
| Create AWS account          | Yes                      | No                    |
| Create IAM user             | Yes                      | No                    |
| Share Account ID + password | Yes                      | No                    |
| Run `aws configure`         | Yes (own creds)          | Yes (IAM creds)       |
| Run `terraform apply`       | Yes                      | Yes (with IAM access) |
| View ECS / CloudWatch       | Yes                      | Yes (with IAM access) |
| Billing & account settings  | Yes                      | No (root only)        |

> ⚠️ **IMPORTANT:** Never share the root account credentials. Always use IAM users for day-to-day work. Set up billing alerts so you are notified if costs spike unexpectedly.

the faster way is to avoid doing most of the setup in the AWS console and move to a text-first workflow: Terraform for infrastructure, AWS CLI for inspection, and a small set of reusable command templates you can copy into AI when something breaks. Terraform turns AWS configuration into files, which makes setups reproducible and much easier to reuse than clicking through the console.

Faster workflow
For this project, the console should be used only when it is genuinely easier to visualize something, like checking CloudWatch logs, ALB target health, or Cognito settings.
Most repeatable setup should live in Terraform files, because manual console work is hard to reproduce and easy to forget or misconfigure later.

What to use instead
Use these three layers:

Terraform for VPC, subnets, security groups, IAM roles, ECS cluster, ECS services, ALB, and optional RDS.

AWS CLI for checking status, logs, ECS tasks, load balancers, and security groups.

Docker Compose locally for the full stack before touching AWS, which matches the project’s own recommendation to do heavy development and testing locally.

Use this rule for every project item:

If it creates infrastructure, put it in Terraform.

If it checks runtime state, use AWS CLI.

If it is heavy dev or integration work, do it locally with Docker Compose.

If it is easier to inspect visually, open the console after the resource already exists.
That is the cleanest and fastest way to handle a project of this size without drowning in AWS console clicking.

To stay effectively “free of cost”, the plan needs to be adjusted to minimize or completely avoid paid AWS services and to fit within AWS Free Tier limits where possible. Below is the updated step‑by‑step plan with that constraint baked in.

---

---

## Step 1 – Team AWS account and IAM setup (two‑person access)

- One person is **Account Owner** (root): creates AWS account, manages billing, and sets Free Tier/billing alerts.
- Account Owner creates one **IAM user** for the teammate with console + programmatic access (`AdministratorAccess` or similar).
- Teammate logs in using the `https://<account-id>.signin.aws.amazon.com/console` URL.
- For CLI/Terraform, Account Owner creates **access keys** for the IAM user; both run `aws configure` (each with their own keys, same region).
- Rule: never share root credentials; all daily work via IAM users.

---

## Step 2 – Agree on workflow: text‑first, local‑first, free‑tier‑aware

- Text‑first:
  - If it creates infra → Terraform file.
  - If it checks runtime state → AWS CLI.
  - If it’s heavy dev/debug → Docker Compose locally.
  - Console only when visual is easier (CloudWatch logs, ALB health, Cognito UI).
- Local‑first:
  - All dev, integration, and full‑stack runs done locally.
- Free‑tier‑aware:
  - Only minimal AWS infra, short‑lived, and always torn down after tests.

---

## Step 3 – Clarify project scope and success criteria

- “Done” means:
  - All six microservices containerized.
  - Full stack works in Docker Compose (with RabbitMQ and two Postgres DBs).
  - Minimal but real AWS deployment (VPC, ECS, ALB, maybe RDS) created with Terraform and validated.
  - Monitoring and logging:
    - Locally: Prometheus + Grafana, optional ELK.
    - AWS: CloudWatch logs and basic metrics.
  - Security: VPC‑only DB access, HTTPS + API auth design (Cognito/API Gateway).
  - Cost: kept inside free/near‑zero by limiting what runs in AWS and for how long.
  - README and diagrams cover all 33 audit questions.

---

## Step 4 – Repository structure and reuse of old projects

- Set up a clean repo structure:
  - `services/inventory-app`
  - `services/billing-app`
  - `services/api-gateway-app`
  - `services/shared` (if some code from crud-master/orchestrator is shared)
  - `infra/terraform`
  - `local/docker-compose`
  - `docs/` (architecture diagrams, audit notes)
- Reuse:
  - `crud-master` for CRUD logic and app structure.
  - `play-with-containers` for Dockerfile patterns.
  - `orchestrator` for service integration patterns, ports, and flows.
- Keep previous projects as references (or git submodules) instead of copy‑pasting random code.

---

## Step 5 – Containerize all microservices (100% local)

- Write/optimize Dockerfiles for:
  - `inventory-app` (port 8080).
  - `billing-app` (port 8080, consumes RabbitMQ).
  - `api-gateway-app` (port 3000).
  - `inventory-database` (Postgres, 5432).
  - `billing-database` (Postgres, 5432).
  - `RabbitMQ` (AMQP + management ports).
- Optimizations for Q11:
  - Use slim/alpine images where reasonable.
  - Use multi‑stage builds if building binaries.
  - Add `.dockerignore` to avoid copying node_modules/build artifacts.
  - Pin base image versions for reproducibility.
- Build and run each container individually to confirm ports and health endpoints.

---

## Step 6 – Local golden environment with Docker Compose

- Create `local/docker-compose/docker-compose.yml` that runs all six services together.
- Wire up networks:
  - Use service names as hostnames (e.g. `inventory-database`).
- Verify routing:
  - `api-gateway-app` → `inventory-app` → `inventory-database`.
  - `api-gateway-app` → `billing-app` → `billing-database`.
  - `billing-app` consumes messages from RabbitMQ.
- This is your **primary** environment for demos and debugging.

---

## Step 7 – Local observability: Prometheus, Grafana, optional ELK

- Extend Docker Compose to include:
  - Prometheus (scraping apps or exporters).
  - Grafana (dashboards for latency, error rate, throughput).
  - Optional ELK (Elasticsearch, Logstash, Kibana) for local log aggregation.
- Prove:
  - You can instrument and visualize metrics (Q30).
  - You understand monitoring beyond simple logs.

---

## Step 8 – Design AWS architecture on paper/diagrams

- Draw diagrams for:
  - VPC with public subnets (ALB, maybe NAT) and private subnets (ECS tasks).
  - ECS cluster running the app containers.
  - Optional: RDS Postgres instance in DB subnets with two DBs/schemas for inventory/billing.
  - ALB routing to ECS services.
  - CloudWatch for logs and metrics.
  - API Gateway + Cognito in front of public endpoints (even if partly only in design).
- Mark **what runs locally vs AWS** clearly (for the “Local vs AWS” section and cost story).

---

## Step 9 – Author Terraform for networking and security (local only so far)

- In `infra/terraform`:
  - VPC, subnets, route tables, internet gateway, NAT (if needed).
  - Security groups:
    - ALB SG: inbound 80/443, outbound to ECS.
    - ECS SG: inbound from ALB SG, outbound to DB and internet via NAT.
    - DB SG: inbound only from ECS SG on 5432.
  - VPC DNS hostnames/service discovery settings.
- Run `terraform fmt`, `terraform validate`, `terraform plan` but do **not** apply yet.

---

## Step 10 – Terraform IAM, ECS cluster, and supporting resources

- IAM:
  - ECS task execution role (pull from ECR, send logs to CloudWatch).
  - ECS task role (for app access to RDS/Secrets if used).
- ECS cluster resource.
- CloudWatch log groups for each app (small retention, suits free tier).
- Optional S3 + DynamoDB for remote Terraform state (or keep local for zero cost).
- Again, validate and plan only.

---

## Step 11 – Build/push images to ECR (minimal set)

- Create ECR repositories via Terraform or console (once).
- Tag and push:
  - At least `api-gateway-app`.
  - At least one backend app (inventory or billing).
- Keep tag count low and repos small to avoid noticeable storage cost.

---

## Step 12 – Minimal AWS deployment with ECS (Free Tier‑friendly)

- Run `terraform apply` to create:
  - VPC + subnets + SGs.
  - ECS cluster.
  - ECS task definitions and services for minimal set (e.g. api-gateway + one backend).
- Use EC2 launch type for ECS with a `t2.micro`/`t3.micro` instance from Free Tier.
- Optionally, create ALB via Terraform to expose api-gateway publicly.
- Validate:
  - Tasks are running.
  - ALB target health is OK.
  - Requests through ALB reach your app.

---

## Step 13 – Database strategy (RDS vs local containers under constraints)

- RDS:
  - Write Terraform for a small RDS Postgres instance in DB subnets (design and code).
  - For absolute free‑tier safety, either:
    - Keep RDS **design‑only** (do not apply), and explain in role‑play how it would be used.
    - Or create a very small instance briefly during demo windows, then destroy it immediately.
- For runtime:
  - Use local Postgres containers for serious load tests.
  - Ensure app configs can switch between local DB and RDS endpoint via environment variables.

---

## Step 14 – Security and managed authentication

- Network security:
  - Confirm DB is not publicly accessible.
  - Confirm only ALB/API Gateway are public.
- TLS:
  - Provision ACM certificate (free).
  - Configure ALB HTTPS listener (443) as part of Terraform.
- API Auth:
  - Design and possibly implement:
    - Cognito user pool + app client.
    - API Gateway with Cognito authorizer protecting your public APIs.
  - Even if minimal/temporary, you must be able to explain this clearly in Q8/Q18 answers.

---

## Step 15 – AWS monitoring, logging, and auto‑scaling

- Monitoring/logging:
  - ECS tasks send logs to CloudWatch log groups.
  - Optionally enable ALB access logs.
  - Use CloudWatch metrics (CPU, memory, request count) to build simple dashboards/alarms.
- Auto‑scaling:
  - Configure ECS Service Auto Scaling policies based on CPU or request count.
  - Run a short load test to trigger scaling once.
  - Show how this answers Q10, Q16, Q31.

---

## Step 16 – Cost management and teardown routines

- In Billing console:
  - Set Free Tier and cost alarms.
- Tag all resources with `Project=CloudDesign`, `Owner=<your-name>`.
- Create a teardown script/checklist:
  - Scale ECS services to 0.
  - Stop/terminate EC2 instances.
  - Delete ALB.
  - Delete RDS if created.
  - Optionally delete ECR images.
  - Run `terraform destroy` to drop the whole stack.
- Make sure this is **practiced** so you do not accidentally leave things running.

---

## Step 17 – README, diagrams, and explicit audit mapping

- README must include:
  - Architecture diagrams.
  - Explanation of microservices and ports.
  - Local setup (Docker Compose, Prometheus, Grafana, optional ELK).
  - AWS setup (Terraform commands, AWS CLI verification examples).
  - Security measures (VPC‑only DB, HTTPS, auth).
  - Cost and Free Tier strategy.
- Create a separate `AUDIT_NOTES.md` (or README section) where you map each of the 33 questions to:
  - Code files (Dockerfiles, Terraform).
  - CLI commands/screenshots.
  - Diagrams and design choices.

---

## Step 18 – Role‑play rehearsal, final tests, and clean‑up

- Role‑play:
  - Practice answering Q2–Q15 with stakeholder language (non‑technical and technical).
  - Practice explaining trade‑offs, why AWS, why ECS, why Terraform, why local‑first.
- Final tests:
  - Run full local stack with Docker Compose + observability.
  - Run minimal AWS deployment once more, confirm everything works.
- Final clean‑up:
  - Capture screenshots.
  - Tear down AWS (terraform destroy, check for leftovers).
  - Check billing shows near‑zero cost.

---
