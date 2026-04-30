🎯 Objective

- Deploy a microservices-based app on AWS
- Reuse and build on work from previous projects: **crud-master**, **play-with-containers**, and **orchestrator**
- Set up monitoring, logging, and auto-scaling
- Secure databases (VPC-only access)
- Add managed authentication (AWS Cognito or similar) for public-facing apps
- Handle varying workloads and unexpected failures

🧱 Microservices to Deploy

- inventory-database — PostgreSQL, port 5432
- billing-database — PostgreSQL, port 5432
- inventory-app — connects to inventory-database, port 8080
- billing-app — connects to billing-database + consumes RabbitMQ messages, port 8080
- RabbitMQ — message queue server
- api-gateway-app — routes all incoming requests to other services, port 3000

🏗️ Architecture Design Principles

- Scalability — use AWS Auto Scaling to handle load changes
- Availability — fault-tolerant design, no single point of failure
- Security — encrypt data at rest and in transit, VPC-only DB access, secure API endpoints
- Cost-effectiveness — right-size resources, avoid waste
- Simplicity — don't over-engineer; only add what's needed

🔧 Infrastructure as Code (Terraform)

- Use Terraform to provision all AWS resources
- Covers: EC2 instances, networking (VPC, subnets, security groups), storage (S3 or similar), container infrastructure

🐳 Containerization (Docker)

- Build Docker images for every microservice
- Reuse containerization knowledge and artifacts from **play-with-containers**
- Optimize Dockerfiles — reduce image size and build time

🚀 Deployment (ECS or EKS)

- Use AWS ECS or EKS for container orchestration
- Reuse and adapt solutions from previous projects: **crud-master**, **play-with-containers**, and especially **orchestrator**
- Use the previous orchestrator project as a starting point
- Apply AWS Elastic Load Balancer for load balancing
- Services must communicate securely with each other

📊 Monitoring & Logging

- CloudWatch — AWS-native metrics and alerts
- Prometheus + Grafana — custom metrics visualization
- ELK Stack — log aggregation and search (Elasticsearch, Logstash, Kibana)

⚙️ Optimization

- Set up auto-scaling policies based on load
- Test under different traffic scenarios
- Adjust resource allocation based on results

🔐 Security

- AWS Certificate Manager — HTTPS/TLS
- Amazon API Gateway — secure API endpoints
- AWS Inspector — vulnerability scanning
- AWS Cognito (or similar) — managed auth for public-facing apps
- Databases and private resources accessible only from within the VPC

💰 Cost Management

- Understand the pricing model before deploying
- Set up billing alerts on the AWS dashboard
- Delete/stop unused resources regularly
- Use Spot/Reserved instances where applicable
- Use AWS cost management tools to spot waste

📁 Documentation (README.md)

- Architecture diagrams (well-structured)
- Description of every component
- Explanation of design decisions
- Setup, configuration, prerequisites, and usage instructions
- Must be submitted as part of the solution

📚 Prior Knowledge Expected

- Basic DevOps concepts
- Docker and Kubernetes familiarity
- AWS fundamentals
- Terraform basics
- Monitoring tools: Prometheus, Grafana, ELK
- Understanding of previous projects: **crud-master**, **play-with-containers**, and **orchestrator**

🎭 Role Play Session

- You'll act as a Cloud Engineer presenting your solution
- Be ready to justify architecture decisions
- Explain trade-offs and alternatives you considered
- Be ready to explain how you reused and improved work from **crud-master**, **play-with-containers**, and **orchestrator**
- Tests communication, critical thinking, and depth of understanding

---

---

## 📋 Cloud-Design Project — Audit Questions

---

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

_(Auditor: ask the student to demonstrate using `aws cli`, `docker ps`, `kubectl`, or any other relevant commands)_

**Q23.** Are all the microservices running as expected in the cloud environment, with no errors or connectivity issues?

**Q24.** Is the load balancing configured correctly, effectively distributing traffic across the services?

**Q25.** Are the microservices communicating with each other securely, using proper authentication and encryption methods?

---

### ⚙️ Section 6: Infrastructure Setup Evaluation

_(Auditor: ask the student to demonstrate using `terraform plan` and/or `terraform apply`)_

**Q26.** Is Terraform used effectively to provision and manage resources in the cloud environment?

**Q27.** Does the infrastructure setup follow the architecture design and the project requirements?

---

### 🐳 Section 7: Containerization & Orchestration Assessment

_(Auditor: ask the student to demonstrate using `aws cli`, `docker ps`, `kubectl`, or any other relevant commands)_

**Q28.** Are the Dockerfiles optimized for efficient container builds?

**Q29.** Is the orchestration setup (e.g., Kubernetes manifests or AWS ECS task definitions) configured correctly?

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

---

Yes — here is a clear **what to do locally vs what to do on AWS** plan for your project, keeping a **free-tier-first mindset**. A full always-on deployment of all services in AWS is not realistic on a strict free plan, while AWS documentation still shows small free-tier-eligible EC2 options, limited free RDS usage, and EKS cluster pricing that is not free. [docs.aws.amazon](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-free-tier-usage.html)

## Local work

Do **all heavy development locally** because this is where you can safely run the whole system without worrying about AWS memory, CPU, or hourly charges. This includes Docker builds, Docker Compose for all services, debugging, database setup, RabbitMQ testing, Terraform writing, and Kubernetes manifest testing with Minikube or kind. [aws.amazon](https://aws.amazon.com/rds/postgresql/pricing/)

Do these tasks locally:

- Build Docker images for `inventory-app`, `billing-app`, `api-gateway-app`, RabbitMQ, and the two PostgreSQL services.
- Run the full stack with Docker Compose.
- Verify ports and connectivity:
  - inventory-database → 5432
  - billing-database → 5432
  - inventory-app → 8080
  - billing-app → 8080
  - api-gateway-app → 3000
- Test billing-app consuming RabbitMQ messages.
- Create and test environment variables and secrets structure.
- Write Terraform files and run:
  - `terraform fmt`
  - `terraform validate`
  - `terraform plan`
- If you want Kubernetes in your project, test manifests locally using Minikube or kind instead of paying for EKS. EKS has a per-cluster hourly fee, so it is not the right choice for a strict free-tier approach. [finout](https://www.finout.io/blog/eks-pricing-components-examples-and-7-ways-to-cut-your-costs)
- Set up Prometheus + Grafana locally.
- If required, test ELK locally too, though for a budget-friendly submission CloudWatch in AWS plus local observability is usually enough. [aws.amazon](https://aws.amazon.com/free/)

## AWS work

Use AWS only for the **minimum cloud proof**: network, security, one small compute target, maybe one RDS instance, logging, and documentation-backed evidence that your cloud design works. AWS still provides free-tier-eligible EC2 options and free-tier RDS options for new customers, but the limits are small, so the goal should be a short demo, not a permanent production deployment. [aws.amazon](https://aws.amazon.com/rds/free/)

Do these tasks in AWS:

- Create the VPC, subnets, route tables, internet gateway, and security groups with Terraform.
- Create IAM roles and policies needed for EC2, CloudWatch, and any other AWS service you use.
- Launch **one small EC2 instance** only for demonstration.
- Install Docker and Docker Compose on that EC2 instance.
- Deploy a **minimal version** of the application there.
- Use CloudWatch for basic logs and metrics.
- Optionally use S3 for Terraform state.
- Optionally use **one** RDS PostgreSQL free-tier-eligible instance, then keep `inventory` and `billing` separate using two databases or two schemas in the same PostgreSQL instance. AWS RDS Free Tier for PostgreSQL is limited, so one instance is the safest low-cost choice. [aws.amazon](https://aws.amazon.com/rds/free/)
- Apply security groups so databases are not publicly open.
- If you need HTTPS for the architecture explanation, document ACM and API Gateway in the design, but do not overbuild paid components unless required.

## Best split

This is the best practical split for your project:

| Area                   | Do locally                    | Do on AWS                                                                                                                               |
| ---------------------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Dockerfiles            | Yes                           | No                                                                                                                                      |
| Full microservices run | Yes                           | Only minimal demo                                                                                                                       |
| Docker Compose         | Yes                           | Yes, but only briefly on one EC2                                                                                                        |
| Terraform authoring    | Yes                           | No                                                                                                                                      |
| Terraform apply        | No                            | Yes, only essential infra                                                                                                               |
| Kubernetes manifests   | Yes                           | Optional, avoid EKS on free-tier goal [finout](https://www.finout.io/blog/eks-pricing-components-examples-and-7-ways-to-cut-your-costs) |
| Monitoring             | Prometheus/Grafana            | CloudWatch basics [aws.amazon](https://aws.amazon.com/free/)                                                                            |
| Databases              | Two local Postgres containers | One RDS PostgreSQL instance max [aws.amazon](https://aws.amazon.com/rds/free/)                                                          |
| RabbitMQ               | Local                         | Optional on EC2 demo                                                                                                                    |
| Load testing           | Local                         | Not necessary unless brief demo                                                                                                         |
| README and diagrams    | Yes                           | No                                                                                                                                      |

## Suggested cloud deployment

For a free-tier-friendly submission, use this simple model:

- Local machine:
  - full Docker Compose stack
  - Terraform code
  - Kubernetes local testing
  - Prometheus/Grafana
- AWS:
  - 1 VPC
  - 1 small EC2 instance
  - 1 RDS PostgreSQL instance if needed
  - CloudWatch
  - S3 for state if desired [aws.amazon](https://aws.amazon.com/free/)

That is enough to show:

- You understand AWS networking.
- You can provision infrastructure with Terraform.
- You can deploy containers in the cloud.
- You know how to secure database access.
- You understand observability and scaling concepts.

## What not to do

Avoid these if your goal is free tier:

- Do not use EKS unless you accept charges, because EKS has a cluster fee. [finout](https://www.finout.io/blog/eks-pricing-components-examples-and-7-ways-to-cut-your-costs)
- Do not leave EC2 or RDS running when you are not actively testing, because free-tier benefits are limited by hours and usage. [docs.aws.amazon](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-free-tier-usage.html)
- Do not try to run a full production-style highly available setup 24/7 on free tier, because the project is too large for that budget. [docs.aws.amazon](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-free-tier-usage.html)

## Execution order

Follow this order so you do not get stuck:

1. Build and test every service locally with Docker Compose.
2. Make sure app-to-app communication works locally.
3. Write Terraform for VPC, security groups, EC2, optional RDS, and CloudWatch.
4. Run `terraform plan` locally.
5. Create a minimal AWS deployment.
6. Show only what is necessary in AWS.
7. Stop or destroy resources after demo. [aws.amazon](https://aws.amazon.com/rds/postgresql/pricing/)

## Practical rule

Use this rule while working:  
**If it can be developed, tested, or demonstrated locally, do it locally. If it must prove AWS knowledge, do that small part in AWS.** This is the safest way to finish the project without running into free-tier limits. [aws.amazon](https://aws.amazon.com/free/)
