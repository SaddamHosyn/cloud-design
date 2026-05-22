

——————————————————————————————————————————————

General
Check the repository content.
Files that must be inside the repository:

Detailed documentation in the README.md file.

Source code for the microservices and scripts required for deployment.

Configuration files for AWS Infrastructure as Code (IaC), containerization, and orchestration tools.

### Are all the required files present?

Play the role of a stakeholder.
Organize a simulated scenario where learners take on the role of AWS Cloud engineers and present their solution to a team or stakeholder. Evaluate their understanding of the concepts and technologies used in the project, their communication skills, and their ability to think critically about their solution.

Suggested role-play questions include:

### What is the cloud and its associated benefits?

**Answer:** Cloud computing is the on-demand delivery of IT resources — compute, storage, networking, databases — over the internet, managed by a third-party provider instead of your own physical hardware. The key benefits I leveraged in this project are: (1) Elasticity — my ECS services auto-scale from 1 to 5 tasks based on CPU load without me buying new servers; (2) Pay-as-you-go — I only pay for the t3.small instances and resources while they run, no upfront capital expenditure; (3) High availability — my infrastructure spans 2 Availability Zones in eu-north-1, so a single datacenter failure does not bring the system down; (4) Managed services — AWS handles patching, backups, and hardware maintenance for services like Cognito, ALB, and CloudWatch, so I focus on application logic.

### Why is deploying the solution in the cloud preferred over on-premises?

**Answer:** On-premises would require purchasing physical servers, setting up networking, configuring storage arrays, and hiring staff to maintain them — a process that takes weeks and costs thousands upfront. With AWS, I ran `terraform apply` and had the entire infrastructure — VPC, subnets, NAT Gateway, ALB, ECS cluster, EFS, Cognito, CloudWatch — provisioned in under 5 minutes. If I need to tear it down, `terraform destroy` removes everything. I cannot do that with physical hardware. Additionally, scaling on-prem means buying more servers in advance; on AWS, my auto-scaling policies add ECS tasks in 60 seconds when CPU exceeds 70%.

### How would you differentiate between public, private, and hybrid cloud?

**Answer:** Public cloud (what I use) means shared infrastructure managed by AWS — I get isolated resources via VPC but the underlying hardware is shared across customers. Private cloud means dedicated infrastructure (e.g., AWS Outposts or a company's own datacenter running OpenStack) — full control but higher cost and maintenance. Hybrid cloud combines both — for example, keeping sensitive databases on-prem while running stateless compute in AWS, connected via AWS Direct Connect. My project uses public cloud because the data is not regulated and the cost and speed advantages outweigh the marginal isolation benefit of private cloud.

### What drove your decision to select AWS for this project, and what factors did you consider?

**Answer:** I chose AWS for three reasons: (1) ECS is a mature, production-proven container orchestration service that integrates natively with ALB, Cloud Map, ECR, and CloudWatch — this reduced my integration effort compared to self-managing Kubernetes; (2) Cognito provides managed JWT-based authentication out of the box, so I did not need to build a custom auth service; (3) AWS has the largest market share and the most documentation, meaning troubleshooting was faster. I also considered GCP (GKE) and Azure (ACS), but ECS's simpler model (no control plane fees, no YAML manifests) aligned better with the project's scope.

### Can you describe your microservices application's AWS-based architecture and the interaction between its components?

**Answer:** The system has 4 ECS services running in private subnets across 2 AZs. The API Gateway (Flask, port 3000) sits behind an Application Load Balancer that terminates HTTP/HTTPS traffic. It validates Cognito JWTs and proxies requests to two backend services discovered via AWS Cloud Map DNS: (1) Inventory Stack — a Flask app (port 8080) + PostgreSQL database that handles movie CRUD operations; (2) Billing Stack — a Python RabbitMQ consumer + PostgreSQL database. For billing, the API Gateway publishes messages directly to a standalone RabbitMQ service (discovered at rabbitmq.local:5672), and the billing-app consumer picks them up asynchronously. All databases persist data on encrypted EFS volumes with Access Points. Services communicate via awsvpc networking — each task gets its own private IP and ENI, with security groups restricting traffic so only the ALB can reach the API Gateway, and only ECS tasks can reach each other.

### How did you manage and optimize the cost of your AWS solution?

**Answer:** Five specific measures: (1) I use t3.small instances (2 vCPU, 2GB) which are the smallest instances that can run my workloads — right-sized, not over-provisioned; (2) Container memory allocations are tuned per service: 256 MiB for lightweight apps, 512 MiB for databases, 1024 MiB for the API gateway; (3) Auto-scaling policies scale down to 1 task per service during low traffic, so I am not paying for idle containers; (4) I use a single NAT Gateway instead of one per AZ — this saves ~$30/month and is acceptable for a non-production workload; (5) CloudWatch log retention is set to 7 days, preventing unbounded storage costs.

### What measures did you implement to ensure application security on AWS, and what AWS security best practices did you adhere to?

**Answer:** I implemented defense in depth across multiple layers: (1) Network isolation — all ECS tasks run in private subnets with no public IPs; outbound traffic goes through a NAT Gateway; (2) Security groups — the ALB SG allows only ports 80/443 from the internet; the ECS SG allows inbound only from the ALB SG plus a self-referencing rule for east-west service traffic; the EFS SG allows NFS (2049) only from the ECS SG; (3) Secrets management — all passwords (RabbitMQ, billing DB, inventory DB) are auto-generated by Terraform's random_password resource and stored in SSM Parameter Store as SecureString, injected into containers via the ECS secrets block — never hardcoded in code or environment variables; (4) Authentication — AWS Cognito issues JWTs, and the API Gateway validates them at the application level using PyJWT + JWKS before allowing any request to reach backend services; (5) Encryption — EFS is encrypted at rest (encrypted = true), ALB serves HTTPS on port 443 with an ACM certificate; (6) Container security — all Dockerfiles run as non-root user (appuser), and ECR has scan_on_push = true for vulnerability scanning on every image push.

### What AWS monitoring and logging tools did you utilize, and how did they assist in identifying and troubleshooting application issues?

**Answer:** I use CloudWatch for both logging and monitoring. Every container logs to the /ecs/cloud-design log group with per-service stream prefixes (api-gateway/*, billing-app/*, billing-db/*, inventory-app/*, inventory-db/*, rabbitmq/*). This allowed me to diagnose the RabbitMQ memory crash loop by filtering logs with `aws logs filter-log-events --log-stream-name-prefix rabbitmq` and seeing the system_memory_high_watermark errors. I also provisioned a custom CloudWatch Dashboard (cloud-design-dashboard) with 4 widgets: cluster-level CPU/Memory utilization, and per-service CPU/Memory utilization. This gives real-time visibility into whether any service is approaching its resource limits. During the billing resilience test, I used `aws logs tail /ecs/cloud-design --follow --log-stream-name-prefix billing-app` to watch the consumer process queued messages in real time.

### Can you describe the AWS auto-scaling policies you implemented and how they help your application accommodate varying workloads?

**Answer:** I implemented Target Tracking Scaling on all three ECS services (api-gateway, billing, inventory). Each service scales between 1 and 5 tasks. The target metric is ECSServiceAverageCPUUtilization at 70%. When CPU exceeds 70%, AWS automatically launches new tasks within 60 seconds (scale-out cooldown). When load drops, tasks are removed after a 300-second cooldown (scale-in) to prevent flapping. The underlying EC2 Auto Scaling Group scales from 3 to 8 instances to provide capacity for the new tasks. This is defined in autoscaling.tf using aws_appautoscaling_target and aws_appautoscaling_policy resources. You can verify it live by running: `aws application-autoscaling describe-scaling-policies --service-namespace ecs --region eu-north-1`

### How did you optimize Docker images for each microservice, and how did this impact build times, image sizes?

**Answer:** All three Dockerfiles (api-gateway, billing-app, inventory-app) use multi-stage builds. Stage 1 (builder) installs gcc and compiles Python dependencies into a virtual environment. Stage 2 (runtime) starts from a clean python:3.9-slim base, copies only the pre-built virtual environment — gcc and build tools are not included in the final image. This reduces image size significantly because the build toolchain (which can be 200+ MB) is discarded. Additional optimizations: (1) pip install --no-cache-dir prevents pip from storing download caches inside the image; (2) apt-get install --no-install-recommends avoids pulling unnecessary suggested packages; (3) rm -rf /var/lib/apt/lists/* removes the apt cache after installing packages; (4) A non-root user (appuser) is created for runtime security. The result is lightweight, secure images that build faster on subsequent runs due to Docker layer caching.

### If you had to redo this project, what modifications would you make to your approach or the technologies you used?

**Answer:** Three changes: (1) I would use Amazon RDS instead of containerized PostgreSQL on EFS — RDS provides automated backups, point-in-time recovery, and read replicas out of the box, which I had to manage manually with EFS Access Points and POSIX permissions; (2) I would evaluate AWS Fargate instead of EC2 launch type — Fargate eliminates the need to manage EC2 instances entirely, though it costs more per vCPU; (3) I would set up a CI/CD pipeline using AWS CodePipeline + CodeBuild from day one — currently image builds and pushes are manual, which is error-prone and slows iteration. I would also use a real domain with Route 53 instead of the self-signed TLS certificate.

### How can your AWS solution be expanded or altered to cater to future requirements like adding new microservices or migrating to a different cloud provider?

**Answer:** Adding a new microservice is straightforward: (1) Create a new ECR repository in ecr.tf; (2) Create a new ECS task definition and service in ecs.tf; (3) Register it in Cloud Map under the .local namespace — it immediately becomes discoverable by other services via DNS (e.g., new-service.local); (4) Add a proxy route in the API Gateway's __init__.py. No infrastructure redesign is needed. For migrating to another cloud provider, Terraform's provider model is portable — the same patterns (VPC, subnets, load balancer, container service, managed auth) exist on GCP (Cloud Run, Identity Platform) and Azure (ACI, Entra ID). The application code itself is cloud-agnostic Python/Flask with no AWS SDK dependencies.

### What challenges did you face during the project and how did you address them?

**Answer:** Four major challenges: (1) EFS Permission Deadlock — ECS Docker agent tried to chown EFS mount paths, which Access Points prohibit. I fixed this by using neutral PGDATA paths (/data/billing/pgdata) and aligning Access Point POSIX UIDs (70) with the PostgreSQL container user; (2) RabbitMQ Memory Crash Loop — when bundled with billing containers sharing 1536 MiB, RabbitMQ hit system_memory_high_watermark on every startup. I extracted it into its own standalone ECS service with 512 MiB dedicated memory; (3) Service Discovery DNS Propagation — after task restarts, Cloud Map DNS records took time to update, causing Name or service not known errors. I set TTL=10s and failure_threshold=1 for fast deregistration; (4) Cognito Integration — initially tried ALB-level authenticate-cognito which requires OAuth hosted UI. I pivoted to application-level JWT validation using PyJWT + JWKS, giving full control over error messages and working seamlessly with Postman.

### How did you ensure your documentation's clarity and completeness, and what measures did you take to make it easily understandable and maintainable?

**Answer:** I structured the README to serve two audiences: operators (who deploy) and auditors (who verify). It includes: (1) An ASCII architecture diagram so the system layout is understood at a glance; (2) A table of contents for quick navigation; (3) Step-by-step setup instructions with exact, copy-pasteable commands; (4) Decision tables explaining why each technology was chosen, not just what was used; (5) A dedicated Verification Commands section so auditors can independently confirm the deployment; (6) An OpenAPI spec (openapi.yaml) and Postman collection for machine-readable and interactive API documentation; (7) Terraform files as living documentation — the infrastructure is fully described in code, so the docs can never drift from reality. The billing resilience test has its own detailed runbook with window/prompt markers to prevent common mistakes.

### Were the learners able to answer all the questions correctly?

*Note for Auditee: Answer clearly, stay confident, and if asked something outside your immediate knowledge, refer to how you would find the answer in AWS documentation. Your prepared answers cover the bulk of the expected questions.*


### Did the learners demonstrate a thorough understanding of the concepts and technologies used in the project?

*Note for Auditee: Demonstrate this by walking the auditor through the Terraform code and Postman requests naturally. Use proper terminology (e.g., "ECS Tasks" instead of just "containers", "JWT" instead of "token").*


### Were the learners able to communicate effectively and justify their decisions?

*Note for Auditee: Keep explanations structured: State the decision, explain the "Why" (cost, scalability, simplicity), and point to the specific implementation (e.g., "We chose ECS over EKS because... as seen in ecs.tf").*


### Could the learners critically evaluate their solution and consider alternative strategies?

*Note for Auditee: You have a "Challenges" and "Future Improvements" section ready. Use it to show you know your system's limits and how to improve it (e.g., moving from EFS Postgres to RDS).*

Review the Architecture Design.
Review the learner's architecture design, ensuring that it meets the project requirements:

### Scalability: Does the architecture utilize AWS services to manage varying workloads and scale as required?

**Proof:** Yes. All three ECS services (api-gateway, billing, inventory) have Target Tracking auto-scaling policies configured in `autoscaling.tf`. Each service scales from 1 to 5 tasks when CPU exceeds 70%. The EC2 Auto Scaling Group scales from 3 to 8 instances. Verify with:
```bash
aws application-autoscaling describe-scaling-policies --service-namespace ecs --region eu-north-1
```

### Availability: Is the architecture designed to be fault-tolerant and maintain high availability, even during component failures?

**Proof:** Yes. The infrastructure spans 2 Availability Zones (eu-north-1a and eu-north-1b). Private subnets exist in both AZs. EFS mount targets are in both AZs. The ALB distributes traffic across both AZs. If one AZ fails, services continue running in the other. The billing resilience test also proves that the system handles a complete service failure gracefully — messages queue in RabbitMQ and are processed when the service recovers.

### Security: Does the architecture integrate AWS security best practices, including data encryption, use of AWS VPC, secure API endpoints, and managed authentication using AWS Cognito or a similar service?

**Proof:** Yes. (1) All ECS tasks run in private subnets inside a VPC with no public IPs; (2) EFS is encrypted at rest (`encrypted = true` in `efs.tf`); (3) ALB serves HTTPS on port 443 with an ACM certificate (`alb.tf`); (4) All passwords are stored in SSM Parameter Store as SecureString — never in code; (5) Cognito User Pool issues JWTs, validated by the API Gateway at the application level using PyJWT + JWKS; (6) ECR repositories have `scan_on_push = true` for vulnerability scanning. Verify security groups with:
```bash
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$(aws ec2 describe-vpcs --filters 'Name=tag:Name,Values=cloud-design-vpc' --query 'Vpcs[0].VpcId' --output text --region eu-north-1)" --region eu-north-1 --query 'SecurityGroups[*].{Name:GroupName,Rules:IpPermissions}'
```

### Cost-effectiveness: Is the architecture designed to be cost-effective on AWS without compromising performance, security, or scalability?

**Proof:** Yes. I use t3.small instances (cheapest viable option), right-sized container memory per service (256–1024 MiB), a single NAT Gateway (saves ~$30/month vs one per AZ), auto-scaling that scales down to 1 task during low traffic, and 7-day CloudWatch log retention to prevent unbounded costs.

### Simplicity: Is the AWS architecture straightforward and free of unnecessary complexity while still fulfilling project requirements?

**Proof:** Yes. The entire infrastructure is defined in ~10 Terraform files with clear separation (vpc.tf, ecs.tf, alb.tf, efs.tf, cognito.tf, etc.). I use ECS instead of Kubernetes to avoid control plane complexity. Services discover each other via simple DNS names (rabbitmq.local, inventory-app.local) through Cloud Map. No unnecessary Lambda functions, API Gateway (AWS service), or Step Functions — just the essential components.

### Did the architecture design and choice of services align with all the project requirements above?

### Were the learners able to design a cost-effective architecture that meets the project requirements?

Check the learner documentation in the
README.md
file.
### Does the README.md file contain all the necessary information about the solution (prerequisites, setup, configuration, usage, ...)?

**Proof:** Yes. The README.md contains: Table of Contents, Why Cloud & Why AWS section, Architecture Overview with ASCII diagram, Repository Structure, Prerequisites, Infrastructure Setup (step-by-step), Building and Pushing Docker Images, Deployment verification, Authentication (Cognito) with login flow, full API Reference with Postman examples, Billing Resilience test procedure, Monitoring and Logging, Auto-Scaling policies, Security measures, Verification Commands, Cost Optimization, Challenges and Lessons Learned, Future Improvements, and Documentation Approach.

### Is the documentation provided by the learner clear and complete, including well-structured diagrams and thorough descriptions?

**Proof:** Yes. The README includes an ASCII architecture diagram showing the full flow from Internet → ALB → API Gateway → Backend Services → EFS. It uses decision tables to explain why each technology was chosen. It provides copy-pasteable commands for every step. The OpenAPI spec (openapi.yaml) and Postman collection (CRUD_Master.postman_collection.json) provide machine-readable and interactive API documentation.

Verify the deployment. Ask the learner to show you, the auditor, the use of
aws cli
, and either
kubectl
(for EKS) or relevant ECS commands, as well as
docker ps
if applicable.
### Was the learner able to show you the proper usage of the commands to verify the deployment of the microservices in the cloud environment?

**Proof:** Yes. Run the following commands to verify all services are deployed and running:
```bash
# List all services and their running task counts
aws ecs describe-services \
  --cluster cloud-design-cluster-v2 \
  --services api-gateway-service rabbitmq-service billing-service inventory-service \
  --region eu-north-1 \
  --query 'services[*].{Name:serviceName,Status:status,Running:runningCount,Desired:desiredCount}' \
  --output table

# List all running tasks
aws ecs list-tasks --cluster cloud-design-cluster-v2 --desired-status RUNNING --region eu-north-1

# Check task definitions
aws ecs describe-task-definition --task-definition api-gateway-task --region eu-north-1 --query 'taskDefinition.containerDefinitions[*].name'
aws ecs describe-task-definition --task-definition rabbitmq-task --region eu-north-1 --query 'taskDefinition.containerDefinitions[*].name'
aws ecs describe-task-definition --task-definition billing-stack-task --region eu-north-1 --query 'taskDefinition.containerDefinitions[*].name'
aws ecs describe-task-definition --task-definition inventory-stack-task --region eu-north-1 --query 'taskDefinition.containerDefinitions[*].name'
```
For docker ps, SSM into an EC2 instance and run:
```bash
aws ssm start-session --target <INSTANCE_ID> --region eu-north-1
# Then inside the session:
sudo docker ps
```

### Are all the microservices running as expected in the cloud environment, with no errors or connectivity issues?

**Proof:** Yes. All 4 services show runningCount=1 and desiredCount=1. Health checks confirm each container is healthy. Verify with:
```bash
aws ecs describe-services \
  --cluster cloud-design-cluster-v2 \
  --services api-gateway-service rabbitmq-service billing-service inventory-service \
  --region eu-north-1 \
  --query 'services[*].{Name:serviceName,Running:runningCount,Desired:desiredCount}' \
  --output table
```

### Is the load balancing configured correctly, effectively distributing traffic across the services?

**Proof:** Yes. The Application Load Balancer (cloud-design-alb) listens on ports 80 and 443 and forwards traffic to the api-gateway target group (port 3000) using IP-based targeting (awsvpc mode). The ALB health check hits /health on the API Gateway. Verify with:
```bash
# Show ALB details
aws elbv2 describe-load-balancers --names cloud-design-alb --region eu-north-1

# Show target group health
aws elbv2 describe-target-groups --names api-gateway-tg-final --region eu-north-1 --query 'TargetGroups[0].TargetGroupArn' --output text | xargs -I {} aws elbv2 describe-target-health --target-group-arn {} --region eu-north-1
```

### Are the microservices communicating with each other securely, using proper authentication and encryption methods?

**Proof:** Yes. (1) All inter-service traffic stays within the VPC private subnets — no traffic leaves the private network; (2) Security groups enforce that only the ALB can reach the API Gateway, and only ECS tasks can communicate with each other (self-referencing rule); (3) EFS uses transit encryption (`transit_encryption = "ENABLED"` in ecs.tf volume configurations); (4) External API access requires a valid Cognito JWT token — requests without a Bearer token receive 401 Unauthorized. Verify Cloud Map service discovery is working:
```bash
aws servicediscovery list-services --region eu-north-1 --query 'Services[*].{Name:Name,Id:Id}' --output table
```

Verify API functionality through the API Gateway.
### Can the learner successfully create a movie by sending a POST request through the API Gateway, and does the request return a successful response code?

**Proof:** Yes. Open Postman and use the CRUD_Master collection:
1. First obtain a Cognito JWT token (use the auth request in the collection)
2. Set the `accessToken` variable in Postman
3. Send POST to `http://<ALB_URL>/api/movies` with body:
```json
{
  "title": "Inception",
  "description": "A mind-bending thriller by Christopher Nolan"
}
```
4. Headers: `Authorization: Bearer {{accessToken}}` and `Content-Type: application/json`
5. Expected: HTTP 201 Created with the movie object in the response body

### Can the learner retrieve the created movies by sending a GET request through the API Gateway, and does the response contain the expected data?

**Proof:** Yes. In Postman:
1. Send GET to `http://<ALB_URL>/api/movies` with header `Authorization: Bearer {{accessToken}}`
2. Expected: HTTP 200 OK with a JSON array containing the movie(s) you just created, including id, title, and description fields
3. You can also filter by title: GET `http://<ALB_URL>/api/movies?title=Inception`

Verify billing service and messaging queue resilience.

### When the billing service is stopped, can the learner send a billing request through the API Gateway without errors?

### After restarting the billing service, does the learner demonstrate that the queued billing request was processed successfully?

---

Here is a fully detailed, copy‑pasteable runbook that covers all the gotchas you hit (like “sh: SELECT: command not found” and “psql: command not found”). I’ll be very explicit about:

Which window you’re in

What prompt you should see

Exact commands for shell vs psql so you don’t mix them up

We’ll still use user_id = '9999' as the test user.

0. Windows and prompts

Open these:

Window A – Mac terminal: AWS CLI commands (aws ...)
Prompt looks like:
saddam.hussain@saddam cloud-design %

Window B – SSM session on EC2 host: Docker commands (sudo docker ...)
Prompt looks like:
sh-4.2$

Window C – Postman: POST /api/billing

Inside Docker you have two levels:

EC2 shell: sh-4.2$ → run sudo docker ... here

Postgres container shell: / # → run psql ... here

Inside psql: billing=# → run SQL (SELECT ...) here

If you see sh-4.2$ and type SELECT ..., you’ll get sh: SELECT: command not found, because that’s shell, not psql. That’s exactly the error you saw.

1. Make sure billing service is running (starting point)

Where: Window A (Mac terminal, saddam.hussain@saddam)

Check if billing is running:

```bash
aws ecs describe-services \
--cluster cloud-design-cluster-v2 \
--services billing-service \
--region eu-north-1 \
--query 'services[0].runningCount'
```

If you see 1 → billing worker is running, good.

If you see 0 → start it:

```bash
aws ecs update-service \
--cluster cloud-design-cluster-v2 \
--service billing-service \
--region eu-north-1 \
--desired-count 1
```

Then re-run the describe-services command until the output is 1.paste.txt

2. Open a psql session to billing DB

2.1. SSM into the EC2 instance that runs billing DB

Where: Window A

Set the container instance ARN (this is constant for your setup):paste.txt

```bash
THIRD_CI_ARN=arn:aws:ecs:eu-north-1:011237053542:container-instance/cloud-design-cluster-v2/325b9abf0b374944b2e191fa16596a2a
```

Get the EC2 instance ID:

```bash
THIRD_INSTANCE_ID=$(aws ecs describe-container-instances \
--cluster cloud-design-cluster-v2 \
--container-instances "$THIRD_CI_ARN" \
--region eu-north-1 \
--query 'containerInstances[0].ec2InstanceId' \
--output text)
```

Start SSM session:

```bash
aws ssm start-session --target $THIRD_INSTANCE_ID --region eu-north-1
```

Now you are in Window B with prompt:

```text
sh-4.2$
```

2.2. Find the running billing DB container

Where: Window B (sh-4.2$)

```bash
sudo docker ps -a | grep -Ei 'billing-database|postgres'
```

Look for the line with Status starting with Up ... (healthy) for ecs-billing-stack-task-36-billing-database-..., for example:paste.txt

```text
b9fbead3d3f7 postgres:13-alpine "docker-entrypoint.s…" 4 minutes ago Up 4 minutes (healthy) ecs-billing-stack-task-36-billing-database-e8e8e0a0b181fbcbbb01
```

Here the running billing DB container ID is:

```text
b9fbead3d3f7
```

Use that ID (don’t use <...> placeholders literally).

Enter the container:

```bash
sudo docker exec -it b9fbead3d3f7 sh
```

Now you’re inside the container, prompt looks like:

```text
/ #
```

If you are at / # you do not run aws or sudo docker here; that’s only at sh-4.2$.

2.3. Start psql inside the container

Where: inside the container (/ #)

Run:

```bash
psql -U billinguser -d billing
```

If this shows:

```text
psql (13.23)
Type "help" for help.

billing=#
```

you are inside psql on the billing DB.

From now on:

If the prompt is billing=# → run SQL (SELECT, \dt, etc.).

If the prompt is / # → you’re in the container shell (run psql or env, not SELECT).

If the prompt is sh-4.2$ → you’re on EC2 shell (run aws, sudo docker, not psql or SELECT).

3. BEFORE: check the table for user 9999

Where: psql prompt (billing=#)

Run:

```sql
SELECT * FROM orders WHERE user_id = '9999';
```

If you get (0 rows) → perfect, 9999 is clean and ready for the test.

If you already see a row (like you do now), pick another id (e.g. 10001) and use that id consistently for the rest of the test.

Assume you use 9999 and the result is (0 rows); this is your before snapshot.

Leave psql open on this prompt.

4. STOP billing app (consumer)

Where: Window A (Mac, saddam.hussain@saddam)

Stop billing:

```bash
aws ecs update-service \
--cluster cloud-design-cluster-v2 \
--service billing-service \
--region eu-north-1 \
--desired-count 0
```

Now confirm it is really stopped:

```bash
aws ecs describe-services \
--cluster cloud-design-cluster-v2 \
--services billing-service \
--region eu-north-1 \
--query 'services[0].runningCount'
```

Wait until this prints:

```text
0
```

That is your proof that the billing app is stopped.paste.txt

RabbitMQ and the billing DB remain running.

5. Send POST /api/billing while billing is stopped

Where: Window C (Postman)

Request details:

Method: POST

URL: http://<your-alb-or-gateway>/api/billing

Important: Use the JSON field names your API expects (from your Postman collection), not the DB column names.paste.txt

Body:

```json
{
"userid": 9999,
"numberofitems": 3,
"totalamount": 12.34
}
```

Click Send.

Expected response:

HTTP 200 OK

JSON body like:

```json
{
"message": "Order accepted and queued for processing",
"order": {
"userid": 9999,
"numberofitems": 3,
"totalamount": 12.34
}
}
```

That proves:

API → RabbitMQ works

It doesn’t care that billing worker is down now

Take a screenshot of this.

6. While billing is still STOPPED: check DB again

Where: Window B, psql (billing=#)

You must be at billing=#. If you are at / # or sh-4.2$, first re-run psql -U billinguser -d billing to get back into psql.

Run:

```sql
SELECT * FROM orders WHERE user_id = '9999';
```

Expected:

```text
(0 rows)
```

This is the key part:

Request accepted and queued

Billing worker is stopped

DB still has no row for 9999

So the message is sitting in RabbitMQ, not in Postgres yet.

Take a screenshot.

7. START billing app again

Where: Window A (Mac)

Start billing:

```bash
aws ecs update-service \
--cluster cloud-design-cluster-v2 \
--service billing-service \
--region eu-north-1 \
--desired-count 1
```

Wait until:

```bash
aws ecs describe-services \
--cluster cloud-design-cluster-v2 \
--services billing-service \
--region eu-north-1 \
--query 'services[0].runningCount'
```

returns:

```text
1
```

Now billing worker is running again.paste.txt

Optionally watch logs:

```bash
aws logs tail /ecs/cloud-design \
--since 5m \
--follow \
--region eu-north-1 \
--log-stream-name-prefix billing-app
```

You should see a log entry where billing processes your queued order.paste.txt

8. AFTER: check DB to see the new row

Where: Window B, psql (billing=#)

Wait ~20–30 seconds after runningCount=1, then:

```sql
SELECT * FROM orders WHERE user_id = '9999';
```

Expected:

1 row like the one you already observed for a previous run:

```text
id | user_id | number_of_items | total_amount | created_at 
----+---------+-----------------+--------------+----------------------------
6 | 9999 | 3 | 12.34 | 2026-05-22 10:08:09.565612
(1 row)
```

Now you have the precise story:

Before: SELECT ... WHERE user_id='9999'; → 0 rows

Billing stopped (runningCount=0)

POST /api/billing → 200 OK “queued”

While stopped: SELECT ... → still 0 rows

Billing started (runningCount=1)

After: SELECT ... → 1 row for user 9999

That is an air‑tight demonstration that RabbitMQ queued the message while billing app was down and delivered it once billing restarted.

---
Evaluate the infrastructure setup. Ask the learner
to show you
, the auditor, the use of the commands
terraform plan
and/or
terraform apply
to answer the following questions.
### Is Terraform used effectively to provision and manage resources in the cloud environment?

**Proof:** Yes. The entire infrastructure is managed by Terraform across ~10 files: main.tf (providers), variables.tf (inputs), vpc.tf (networking), alb.tf (load balancer), ecs.tf (cluster, task definitions, services, Cloud Map), ecr.tf (container registries), efs.tf (persistent storage), cognito.tf (authentication), autoscaling.tf (scaling policies), dashboard.tf (monitoring). Run to verify:
```bash
cd infra/terraform
terraform plan
```
If the output shows "No changes. Your infrastructure matches the configuration." — this proves Terraform is managing the full infrastructure and it matches the desired state.

### Does the infrastructure setup follow the architecture design and the project requirements?

**Proof:** Yes. `terraform plan` confirms the deployed infrastructure matches the Terraform code. The architecture follows the design: VPC with public/private subnets across 2 AZs, ALB in public subnets, ECS tasks in private subnets, EFS for persistence, Cognito for auth, CloudWatch for monitoring, auto-scaling for elasticity. Every requirement from the project spec is implemented as a Terraform resource.

Assess containerization and orchestration. Ask the learner
to show you
, the auditor, the use of the commands
aws cli
,
docker ps
, and/or
kubectl
or any other necessary with the right options to answer the following questions.
### Are the Dockerfiles optimized for efficient container builds?

**Proof:** Yes. All Dockerfiles use multi-stage builds (Stage 1: builder with gcc for compilation, Stage 2: clean python:3.9-slim runtime). Optimizations include: `--no-cache-dir` for pip, `--no-install-recommends` for apt, `rm -rf /var/lib/apt/lists/*` to remove cache, non-root user (appuser) for security. You can inspect the Dockerfiles directly:
```bash
cat api-gateway/Dockerfile
cat billing-app/Dockerfile
cat inventory-app/Dockerfile
```

### Is the orchestration setup (e.g., Kubernetes manifests or AWS ECS task definitions) configured correctly?

**Proof:** Yes. I use ECS with 4 task definitions, each with awsvpc networking, proper health checks, container dependency ordering (billing-app waits for billing-database to be HEALTHY), and Cloud Map service discovery. Verify the task definitions:
```bash
aws ecs describe-task-definition --task-definition api-gateway-task --region eu-north-1 --query 'taskDefinition.{Family:family,CPU:cpu,Memory:memory,Containers:containerDefinitions[*].name}'
aws ecs describe-task-definition --task-definition rabbitmq-task --region eu-north-1 --query 'taskDefinition.{Family:family,CPU:cpu,Memory:memory,Containers:containerDefinitions[*].name}'
aws ecs describe-task-definition --task-definition billing-stack-task --region eu-north-1 --query 'taskDefinition.{Family:family,CPU:cpu,Memory:memory,Containers:containerDefinitions[*].name}'
aws ecs describe-task-definition --task-definition inventory-stack-task --region eu-north-1 --query 'taskDefinition.{Family:family,CPU:cpu,Memory:memory,Containers:containerDefinitions[*].name}'
```

Evaluate monitoring and logging.
### Are monitoring and logging dashboards providing useful insights into the application performance and health?

**Proof:** Yes. (1) CloudWatch Logs: all containers log to /ecs/cloud-design with per-service stream prefixes (api-gateway/*, billing-app/*, billing-db/*, inventory-app/*, inventory-db/*, rabbitmq/*). Verify:
```bash
aws logs describe-log-groups --log-group-name-prefix /ecs/cloud-design --region eu-north-1
aws logs tail /ecs/cloud-design --since 10m --region eu-north-1
```
(2) CloudWatch Dashboard: a custom dashboard named cloud-design-dashboard with 4 widgets (cluster CPU, cluster Memory, per-service CPU, per-service Memory). View it in the AWS Console or verify:
```bash
aws cloudwatch list-dashboards --region eu-north-1
```

Assess optimization efforts.
### Are the auto-scaling policies configured correctly to handle varying workloads?

**Proof:** Yes. Three Target Tracking Scaling policies are configured in autoscaling.tf. Each targets ECSServiceAverageCPUUtilization at 70%, with scale-out cooldown of 60 seconds and scale-in cooldown of 300 seconds. Min capacity = 1, Max capacity = 5 per service. Verify:
```bash
aws application-autoscaling describe-scaling-policies --service-namespace ecs --region eu-north-1 --query 'ScalingPolicies[*].{Service:ResourceId,Target:TargetTrackingScalingPolicyConfiguration.TargetValue}' --output table
```

### Does the application and resource allocation remain efficient under different load scenarios?

**Proof:** Yes. Container memory is right-sized per workload: API Gateway gets 1024 MiB (handles request routing + JWT validation), databases get 256–512 MiB, apps get 256–512 MiB. Under low load, each service runs 1 task (minimum). Under high load, auto-scaling adds tasks up to 5, and the EC2 ASG adds instances up to 8 to support them. The auto-scaling cooldowns (60s out / 300s in) prevent flapping.

Check security best practices.
### Has the learner implemented security best practices, such as using HTTPS, securing API endpoints, restricting database access to the VPC, and regularly scanning for vulnerabilities?

**Proof:** Yes. (1) HTTPS: ALB listens on port 443 with an ACM TLS certificate (see alb.tf); (2) Secure API endpoints: all business endpoints require a valid Cognito JWT Bearer token — the API Gateway validates the token signature, expiration, and issuer using PyJWT + JWKS; (3) Database access restricted to VPC: databases run inside ECS tasks in private subnets, no port mappings to the host, no public IPs — only containers within the same task can reach the database on localhost; (4) Vulnerability scanning: all ECR repositories have `scan_on_push = true`, meaning every image push triggers an automated vulnerability scan. Verify ECR scan results:
```bash
aws ecr describe-image-scan-findings --repository-name cloud-design-api-gateway --image-id imageTag=v1 --region eu-north-1
```

### When accessing the API Gateway without valid authentication credentials, is the request correctly rejected?

**Proof:** Yes. In Postman, send a GET request to `http://<ALB_URL>/api/movies` WITHOUT setting the Authorization header. The response will be:
- HTTP 401 Unauthorized
- Body: `{"error": "Unauthorized", "message": "Missing Bearer token"}`

If you send a request with an invalid/expired token, the response will be:
- HTTP 401 Unauthorized
- Body: `{"error": "Unauthorized", "message": "Token verification failed: ..."}`

This proves the API Gateway rejects all unauthenticated or incorrectly authenticated requests.

### Can the learner demonstrate the managed authentication configuration (e.g., Cognito) used to protect the API Gateway?

**Proof:** Yes. The Cognito User Pool and App Client are provisioned in `cognito.tf`. A test user (audit-user@example.com) is pre-created by Terraform. The API Gateway validates JWTs at the application level in `api-gateway/app/__init__.py` using the `verify_cognito_token()` function which downloads signing keys from Cognito's JWKS endpoint. Verify the Cognito setup:
```bash
aws cognito-idp list-user-pools --max-results 10 --region eu-north-1
aws cognito-idp list-users --user-pool-id <POOL_ID> --region eu-north-1
```
To obtain a token, use the Postman collection or run:
```bash
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id <APP_CLIENT_ID> \
  --auth-parameters USERNAME=audit-user@example.com,PASSWORD=<YOUR_PASSWORD> \
  --region eu-north-1
```
The returned `IdToken` or `AccessToken` is used as the Bearer token in all authenticated API requests.