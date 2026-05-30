# Operational Manual

**Multi-Cloud DevOps Pipeline — Step-by-Step Deployment & Teardown Guide**

This manual provides detailed, sequential instructions for deploying and tearing down the entire multi-cloud infrastructure. Follow each step in order.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Local Development Setup](#2-local-development-setup)
3. [AWS Account Preparation](#3-aws-account-preparation)
4. [GCP Account Preparation](#4-gcp-account-preparation)
5. [Terraform Backend Bootstrap](#5-terraform-backend-bootstrap)
6. [Configure Variables](#6-configure-variables)
7. [Deploy Infrastructure](#7-deploy-infrastructure)
8. [Push Docker Images to ECR](#8-push-docker-images-to-ecr)
9. [Verify Services](#9-verify-services)
10. [Azure Entra ID Setup](#10-azure-entra-id-setup)
11. [CI/CD Pipeline Setup](#11-cicd-pipeline-setup)
12. [Monitoring & Alerts Verification](#12-monitoring--alerts-verification)
13. [Evidence Collection Checklist](#13-evidence-collection-checklist)
14. [Teardown & Cleanup](#14-teardown--cleanup)
15. [Cost Control](#15-cost-control)
16. [Troubleshooting](#16-troubleshooting)

---

## 1. Prerequisites

### Required Software

| Tool | Version | Installation |
|---|---|---|
| Terraform | >= 1.0 | https://developer.hashicorp.com/terraform/install |
| AWS CLI | v2 | https://aws.amazon.com/cli/ |
| Docker Desktop | Latest | https://www.docker.com/products/docker-desktop/ |
| Git | Latest | https://git-scm.com/downloads |
| gcloud CLI | Latest | https://cloud.google.com/sdk/docs/install |

> **Alternative:** If Terraform is not installed locally, you can run it via Docker:
> ```powershell
> docker run --rm -v "${PWD}/terraform:/workspace" -w /workspace hashicorp/terraform:latest <command>
> ```

### Required Accounts

| Account | Free Tier? | Sign Up |
|---|---|---|
| AWS | Yes (12 months) | https://aws.amazon.com/free/ |
| Google Cloud | Yes ($300 credit) | https://cloud.google.com/free |
| Azure | Yes ($200 credit) | https://azure.microsoft.com/en-us/free/ |

### Verify Tools

```powershell
terraform version
aws --version
docker --version
git --version
gcloud --version
```

---

## 2. Local Development Setup

Test the microservices locally before deploying to the cloud.

### 2.1 Start Services

```powershell
cd assessment-1-multicloud-devops
docker compose up --build -d
```

This starts four containers:
- **dynamodb-local** — DynamoDB emulator (port 8000 internal)
- **fake-gcs-server** — GCP Storage emulator (port 4443)
- **service-a** — Python FastAPI app (port 8000)
- **service-b** — Bun TypeScript app (port 3000)

### 2.2 Verify Health

```powershell
# Service A
Invoke-WebRequest -Uri http://localhost:8000/health -UseBasicParsing | Select-Object -ExpandProperty Content

# Service B
Invoke-WebRequest -Uri http://localhost:3000/health -UseBasicParsing | Select-Object -ExpandProperty Content
```

### 2.3 Test Service A — CRUD Operations

```powershell
# Create a transaction
Invoke-WebRequest -Uri http://localhost:8000/transactions `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"amount": 99.99, "description": "Test transaction"}' `
  -UseBasicParsing | Select-Object -ExpandProperty Content

# List transactions
Invoke-WebRequest -Uri http://localhost:8000/transactions -UseBasicParsing | Select-Object -ExpandProperty Content
```

### 2.4 Stop Local Services

```powershell
docker compose down
```

> **Screenshot opportunity:** Capture the health check responses and CRUD test results.

---

## 3. AWS Account Preparation

### 3.1 Configure AWS CLI

```powershell
aws configure
```

Enter:
- **Access Key ID:** (from IAM console)
- **Secret Access Key:** (from IAM console)
- **Default region:** `ap-southeast-2`
- **Output format:** `json`

### 3.2 Verify Credentials

```powershell
aws sts get-caller-identity
```

Expected output shows your account ID, user ARN, and user ID.

### 3.3 Note Your Account ID

```powershell
$AWS_ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
Write-Host "Account ID: $AWS_ACCOUNT_ID"
```
# TEMP TBR $AWS_ACCOUNT_ID=587601535321 / Account ID: 587601535321

Save this — you'll need it for `terraform.tfvars`.

---

## 4. GCP Account Preparation

### 4.1 Authenticate

```powershell
gcloud auth login
gcloud auth application-default login
```

### 4.2 Create or Select Project

```powershell
# List existing projects
gcloud projects list

# Create a new project (if needed)
gcloud projects create multicloud-devops-project --name="MultiCloud DevOps"

# Set active project
gcloud config set project multicloud-devops-project
```

### 4.3 Enable Required APIs

```powershell
gcloud services enable storage.googleapis.com
gcloud services enable iam.googleapis.com
```

### 4.4 Note Your Project ID

```powershell
gcloud config get-value project
```

Save this — you'll need it for `terraform.tfvars`.

---
## multicloud-devops-project - temp project ID to be replaced in tfvars

## 5. Terraform Backend Bootstrap

The remote backend (S3 bucket + DynamoDB table) must exist before `terraform init` can use it.

### 5.1 Create State Bucket

```powershell
aws s3api create-bucket `
  --bucket multicloud-devops-tfstate `
  --region ap-southeast-2 `
  --create-bucket-configuration LocationConstraint=ap-southeast-2

aws s3api put-bucket-versioning `
  --bucket multicloud-devops-tfstate `
  --versioning-configuration Status=Enabled
```

### 5.2 Create Lock Table

```powershell
aws dynamodb create-table `
  --table-name terraform-state-lock `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST `
  --region ap-southeast-2
```

### 5.3 Verify

```powershell
aws s3 ls s3://multicloud-devops-tfstate
aws dynamodb describe-table   --table-name terraform-state-lock   --region ap-southeast-2   --query "Table.TableStatus"   --output text
```

> **Screenshot opportunity:** Capture the S3 bucket and DynamoDB table in the AWS Console.

---

## 6. Configure Variables

### 6.1 Create tfvars File

```powershell
cd terraform
Copy-Item terraform.tfvars.example terraform.tfvars
```

### 6.2 Edit terraform.tfvars

Open `terraform.tfvars` and fill in your actual values:

```hcl
# Required — replace with your values
aws_account_id          = "123456789012"
gcp_project_id          = "multicloud-devops-project"

# Optional — customise if needed
project_name            = "multicloud-devops"
environment             = "dev"
aws_region              = "ap-southeast-2"
gcp_region              = "australia-southeast1"
notification_email      = "your.email@example.com"

# CI/CD — fill in after creating CodeStar connection (Step 11)
github_repo             = "singhameesha91/assessment-1-multicloud-devops"
github_branch           = "main"
codestar_connection_arn = ""
```

> **Important:** Do not commit `terraform.tfvars` to Git — it may contain sensitive values.

---

## 7. Deploy Infrastructure

### 7.1 Initialise Terraform

```powershell
cd terraform
terraform init
```

> **Screenshot opportunity:** Capture the `terraform init` output showing provider installation and backend setup.

### 7.2 Validate Configuration

```powershell
terraform validate
```

Expected: `Success! The configuration is valid.`

> **Screenshot opportunity:** Capture the validation success message.

### 7.3 Plan Deployment

```powershell
terraform plan
```

Review the plan carefully. It should show ~50+ resources to create.

> **Screenshot opportunity:** Capture the plan summary showing resource counts.

### 7.4 Apply

```powershell
terraform apply
```

Type `yes` when prompted. This takes approximately 5-10 minutes.

> **Screenshot opportunity:** Capture the `Apply complete!` message and the outputs.

### 7.5 Record Outputs

```powershell
terraform output
```

Note the ALB DNS names — you'll need them to verify services.

---

## 8. Push Docker Images to ECR

The ECS services need container images in ECR before they can start.

### Using PowerShell Script (Recommended)

```powershell
cd ..    # Back to project root
.\scripts\push-images.ps1
```

### Manual Steps (if script doesn't work)

```powershell
$REGION = "ap-southeast-2"
$ACCOUNT = aws sts get-caller-identity --query Account --output text
$ECR_URI = "$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"

# Login to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

# Build and push Service A
docker build -t "$ECR_URI/service-a:latest" services/service-a
docker push "$ECR_URI/service-a:latest"

# Build and push Service B
docker build -t "$ECR_URI/service-b:latest" services/service-b
docker push "$ECR_URI/service-b:latest"
```

> **Screenshot opportunity:** Capture ECR repositories showing pushed images in the AWS Console.

### 8.1 Force ECS Service Update

After pushing images, force ECS to pull the new images:

```powershell
aws ecs update-service --cluster devops-cluster --service multicloud-devops-dev-service-a --force-new-deployment --region ap-southeast-2
aws ecs update-service --cluster devops-cluster --service multicloud-devops-dev-service-b --force-new-deployment --region ap-southeast-2
```

Wait 2-3 minutes for tasks to start.

---

## 9. Verify Services

### 9.1 Get ALB DNS Names

```powershell
cd terraform
$ALB_A = terraform output -raw alb_service_a_dns
$ALB_B = terraform output -raw alb_service_b_dns
Write-Host "Service A: http://$ALB_A"
Write-Host "Service B: http://$ALB_B"
```

### 9.2 Test Service Endpoints

```powershell
# Service A health check
Invoke-WebRequest -Uri "http://$ALB_A/health" -UseBasicParsing | Select-Object -ExpandProperty Content

# Service B health check
Invoke-WebRequest -Uri "http://$ALB_B/health" -UseBasicParsing | Select-Object -ExpandProperty Content

# Service A — create a transaction
Invoke-WebRequest -Uri "http://$ALB_A/transactions" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"amount": 50.00, "description": "Cloud transaction test", "user_id":"ameesha_test001"}' `
  -UseBasicParsing | Select-Object -ExpandProperty Content
```

> **Screenshot opportunity:** Capture the service responses via browser or PowerShell.

### 9.3 Verify ECS Tasks Running

```powershell
aws ecs list-tasks --cluster multicloud-devops-dev-devops-cluster --service-name multicloud-devops-dev-service-a --region ap-southeast-2
aws ecs list-tasks --cluster multicloud-devops-dev-devops-cluster --service-name multicloud-devops-dev-service-b --region ap-southeast-2
```

> **Screenshot opportunity:** Capture running tasks in the ECS Console.

---

## 10. Azure Entra ID Setup

Follow the detailed guide: [docs/entra-id-setup.md](docs/entra-id-setup.md)

**Summary:**
1. Create Enterprise Application in Azure Entra ID
2. Configure SAML SSO with AWS sign-in URL
3. Set up claims (RoleSessionName + Role)
4. Download Federation Metadata XML
5. Place XML in `terraform/entra-id-metadata.xml`
6. Re-run `terraform apply` to create the SAML provider
7. Assign users and test SSO login

> **Screenshot opportunities:**
> - Enterprise Application creation
> - SAML configuration page
> - Claims setup
> - Successful AWS Console login via Entra SSO
> - Conditional Access / MFA policy

---

## 11. CI/CD Pipeline Setup

### 11.1 Create CodeStar Connection

This must be done manually in the AWS Console:

1. Go to **AWS Console → Developer Tools → Settings → Connections** 
[codepipeline-> connections ]
2. Click **Create connection**
3. Select **GitHub** → Name it `multicloud-devops-github`
4. Click **Connect to GitHub** → authorise in the GitHub popup
5. Copy the **Connection ARN**

### 11.2 Update terraform.tfvars

```hcl
codestar_connection_arn = "arn:aws:codestar-connections:ap-southeast-2:123456789012:connection/xxxx-xxxx-xxxx"
github_repo             = "your-username/assessment-1-multicloud-devops"
```

### 11.3 Re-apply Terraform

```powershell
cd terraform
terraform apply
```

### 11.4 Trigger Pipeline

Push a commit to the `main` branch to trigger the pipeline:

```powershell
git add .
git commit -m "Trigger CI/CD pipeline"
git push origin main
```

### 11.5 Monitor Pipeline

Go to **AWS Console → CodePipeline** and watch the stages:
1. **Source** — pulls from GitHub
2. **Build** — parallel CodeBuild for both services (Docker image build + push to ECR)
3. **Deploy** — parallel CodeBuild blue/green deploy for both services (ALB listener swap)

> **Screenshot opportunities:**
> - CodeStar connection (Settings → Connections)
> - Pipeline overview showing all stages
> - Successful build logs for both services
> - Successful blue/green deployment (ALB listener swap) for both services

---

## 12. Monitoring & Alerts Verification

### 12.1 Check CloudWatch Logs

```powershell
# List log groups
aws logs describe-log-groups --region ap-southeast-2 --query "logGroups[*].logGroupName" --output table
```

Go to **AWS Console → CloudWatch → Log Groups** and verify container logs appear.

### 12.2 Check Alarms

```powershell
aws cloudwatch describe-alarms --region ap-southeast-2 --query "MetricAlarms[*].[AlarmName,StateValue]" --output table
```

Expected: 4 alarms (service-a-cpu-high, service-a-cpu-low, service-b-cpu-high, service-b-cpu-low).

### 12.3 Check Autoscaling

```powershell
aws application-autoscaling describe-scalable-targets --service-namespace ecs --region ap-southeast-2 --output table
```

### 12.4 Test SNS (Optional)

If you configured `notification_email`, check your inbox for a subscription confirmation email and confirm it.

> **Screenshot opportunities:**
> - CloudWatch log groups with container output
> - 4 CloudWatch alarms
> - Autoscaling policies
> - SNS topic and subscription

---

## 13. Evidence Collection Checklist

Collect all evidence **before** tearing down. Screenshots should be placed in `docs/screenshots/`.

### IaC Evidence
- [ ] `terraform init` output
- [ ] `terraform validate` output
- [ ] `terraform plan` output (summary)
- [ ] `terraform apply` output (completion message)
- [ ] `terraform output` (all outputs)
- [ ] Terraform file structure (folder listing)
- [ ] State backend — S3 bucket in console
- [ ] State backend — DynamoDB lock table in console

### AWS Infrastructure
- [ ] VPC in console
- [ ] Subnets (2 AZs) in console
- [ ] Internet Gateway in console
- [ ] Route table in console
- [ ] ALB security group — rules showing port 80/443
- [ ] ECS security group — rules showing ingress only from ALB SG
- [ ] 2 ALBs in console
- [ ] 4 target groups (2 blue + 2 green) in console
- [ ] 2 ECR repositories with images
- [ ] ECS cluster in console
- [ ] 2 task definitions in console
- [ ] 2 ECS services with running tasks
- [ ] DynamoDB transactions table

### Monitoring
- [ ] CloudWatch log groups (2 ECS + 2 CodeBuild)
- [ ] Container log output
- [ ] 4 CloudWatch alarms
- [ ] 4 autoscaling policies
- [ ] SNS topic

### CI/CD
- [ ] 4 CodeBuild projects (2 build + 2 deploy)
- [ ] Build logs showing successful image push
- [ ] Deploy logs showing ALB listener swap (blue/green)
- [ ] CodePipeline overview
- [ ] Successful pipeline run (all stages green)
- [ ] Blue/green deployment evidence (listener forwarding to green TG)

### Multi-Cloud
- [ ] GCP Cloud Storage bucket
- [ ] GCP service account

### Azure Entra ID
- [ ] Enterprise Application
- [ ] SAML configuration
- [ ] Claims setup
- [ ] AWS IAM SAML provider
- [ ] Federated IAM roles (DevOpsEngineer, ReadOnlyAuditor)
- [ ] Conditional Access / MFA policy
- [ ] Successful AWS Console login via Entra SSO

### Service Testing
- [ ] Service A health check response
- [ ] Service A CRUD operation response
- [ ] Service B health check response
- [ ] Browser showing ALB endpoints

---

## 14. Teardown & Cleanup

> **Do this after collecting ALL evidence.** Resources incur charges while running.

### 14.1 Destroy Terraform Resources

**PowerShell:**
```powershell
.\scripts\destroy.ps1
```

**Manual:**
```powershell
cd terraform
terraform destroy
```

Type `yes` when prompted (or type `destroy` if using the script).

### 14.2 Clean Up Manual Resources

These are not managed by Terraform and must be deleted manually:

| Resource | Where | How |
|---|---|---|
| S3 state bucket | AWS Console → S3 | Empty bucket first, then delete |
| DynamoDB lock table | AWS Console → DynamoDB | Delete table |
| CodeStar connection | AWS Console → Developer Tools → Connections | Delete connection |
| Entra Enterprise App | Azure Portal → Entra ID → Enterprise Applications | Delete application |

### 14.3 Verify No Resources Remain

```powershell
# Check for remaining ECS services
aws ecs list-clusters --region ap-southeast-2

# Check for remaining ALBs
aws elbv2 describe-load-balancers --region ap-southeast-2 --query "LoadBalancers[*].LoadBalancerName"

# Check for remaining ECR repos
aws ecr describe-repositories --region ap-southeast-2

# Check GCP bucket
gcloud storage ls
```

All should return empty results.

> **Screenshot opportunity:** Capture the `terraform destroy` output and verification that no resources remain.

### 14.4 Check AWS Billing

Go to **AWS Console → Billing & Cost Management → Bills** and verify no unexpected charges.

> **Screenshot opportunity:** Capture the billing dashboard showing minimal or zero charges.

---

## 15. Cost Control

### During Development
- Use `docker compose` locally — no cloud charges
- Keep Fargate tasks at minimum size (256 CPU / 512 MiB)
- Use DynamoDB PAY_PER_REQUEST — no cost when idle
- GCP free tier covers Cloud Storage for small usage

### During Evidence Collection
- Deploy → collect screenshots → destroy within 1-2 hours
- Estimated cost for 2 hours: **< $0.25**

### Cost Estimates (if left running)

| Resource | Daily Cost (approx.) |
|---|---|
| 2 × Fargate tasks (256/512) | $0.50 |
| 2 × ALB | $1.10 |
| DynamoDB (on-demand, idle) | $0.00 |
| S3 (minimal storage) | $0.00 |
| CloudWatch (basic) | $0.00 |
| GCP Cloud Storage (minimal) | $0.00 |
| **Total** | **~$1.60/day** |

---

## 16. Troubleshooting

### Terraform init fails with backend error

**Cause:** S3 bucket or DynamoDB table doesn't exist yet.
**Fix:** Complete Step 5 (Backend Bootstrap) first. Or temporarily comment out the `backend "s3"` block in `backend.tf`, run `terraform init` with local state, then uncomment and re-init.

### ECS tasks fail to start (STOPPED status)

**Cause:** No Docker image in ECR, or image pull errors.
**Fix:**
1. Push images first (Step 8)
2. Check task stopped reason: `aws ecs describe-tasks --cluster devops-cluster --tasks <TASK_ARN> --region ap-southeast-2`

### ALB returns 503

**Cause:** No healthy targets in the target group.
**Fix:**
1. Check ECS tasks are running
2. Check health check path (`/health` for both services)
3. Check security group allows traffic from ALB to ECS on the correct port

### Terraform destroy fails

**Cause:** Some resources have dependencies or deletion protection.
**Fix:**
1. ECR repos: `force_delete = true` is set, so images are deleted automatically
2. S3 bucket: `force_destroy = true` is set
3. GCP bucket: `force_destroy = true` is set
4. If a blue/green deployment is in progress, wait for it to finish

### CodePipeline fails at Source stage

**Cause:** CodeStar connection not set up or not authorised.
**Fix:** Complete Step 11.1 (Create CodeStar Connection) in the AWS Console and update `terraform.tfvars`.

### SAML login fails with "Not authorized"

**Cause:** Role claim format incorrect or metadata XML not loaded.
**Fix:** See [docs/entra-id-setup.md](docs/entra-id-setup.md) troubleshooting section.

### Docker Compose services won't start

**Cause:** Port conflicts.
**Fix:** Check nothing else is using ports 8000 or 3000:
```powershell
netstat -ano | findstr ":8000 :3000"
```
