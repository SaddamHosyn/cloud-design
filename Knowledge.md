## AWS Networking (VPC Core Concepts)

The hardest part of AWS for beginners is the network boundary. You must understand how traffic flows in and out of a Virtual Private Cloud (VPC).

- **VPC and Subnets:** A VPC is your private network in the cloud. You will divide it into Public Subnets (can reach the internet) and Private Subnets (cannot reach the internet directly).
- **Internet Gateways (IGW) and Route Tables:** An IGW allows your public subnets to talk to the outside world. Route tables act as the map telling subnet traffic where to go.
- **Security Groups (SGs):** These are virtual firewalls attached to resources (like your EC2 instances or databases). You must learn to chain them. For example, your Database SG should only allow inbound traffic from your App SG, never from the public internet.

## Translating Kubernetes to AWS ECS

You already understand Pods and Deployments. AWS Elastic Container Service (ECS) uses different terminology for the same concepts. You need to mentally map them:

- **Task Definition:** The equivalent of a Kubernetes Pod manifest. It defines which Docker image to use, environment variables, ports, and memory limits.
- **Task:** A running instance of a Task Definition (equivalent to a running Pod).
- **ECS Service:** The equivalent of a Kubernetes Deployment and Service combined. It ensures a specific number of Tasks stay running and registers them with a Load Balancer.
- **Launch Types:** ECS can run on Fargate (serverless, AWS manages the VM) or EC2 (you manage the VM). For a strict free-tier project, you must use the EC2 launch type with a `t2.micro` or `t3.micro` instance.

## Infrastructure as Code (Terraform Logic)

Terraform does not just run commands; it manages "state." You must understand declarative infrastructure.

- **Declarative vs. Imperative:** You do not tell Terraform _how_ to create a VPC; you tell it _what_ the VPC should look like. Terraform figures out the API calls to make.
- **The State File (`terraform.tfstate`):** Terraform tracks what it has built in this file. If you delete a resource manually in the AWS Console, Terraform's state becomes out of sync. You must learn to rely solely on `terraform apply` and `terraform destroy`.
- **Resource Dependencies:** Terraform builds a dependency graph. If an ECS cluster needs a VPC, Terraform automatically knows to build the VPC first.

## Traffic Routing and Load Balancing

Your project requires an API Gateway and an Application Load Balancer (ALB). You need to understand how user requests travel to your containers.

- **Application Load Balancer (ALB):** Acts as the front door. It receives HTTP/HTTPS traffic and distributes it to your healthy ECS Tasks.
- **Target Groups:** The ALB routes traffic to Target Groups. As ECS starts or stops containers, it dynamically registers and deregisters their IP addresses with the Target Group.
- **API Gateway vs. ALB:** API Gateway is used for API management (authentication with Cognito, rate limiting), while ALB is used for internal load balancing across your microservices.

## AWS IAM (Identity and Access Management)

Security in AWS is strictly deny-by-default. Resources cannot talk to each other without explicit permission.

- **IAM Users vs. Roles:** Users are for humans (you and your teammate). Roles are for machines (your ECS tasks).
- **Task Execution Role vs. Task Role:** A major ECS concept. The _Execution Role_ gives the ECS agent permission to pull your Docker image from ECR and send logs to CloudWatch. The _Task Role_ gives your actual running application code permission to access other AWS resources (like an S3 bucket or a database).

## Observability Paradigms

You must understand the difference between your local observability stack and cloud-native logging.

- **Pull vs. Push Metrics:** Prometheus (which you will use locally) "pulls" metrics by scraping endpoints. AWS CloudWatch requires your applications or agents to "push" logs and metrics to it.
- **CloudWatch Log Groups:** ECS seamlessly pushes container standard output (stdout) directly to CloudWatch. You need to understand how to configure the `awslogs` log driver in your Task Definitions to capture these logs.
