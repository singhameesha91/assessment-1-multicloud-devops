# Implementation Document

**Multi-Cloud DevOps Pipeline — Technical Implementation Details**

This document explains the technical decisions, architecture rationale, security model, and implementation details for each component of the multi-cloud infrastructure.

---

## Table of Contents

1. [Architecture Design](#1-architecture-design)
2. [Infrastructure as Code Strategy](#2-infrastructure-as-code-strategy)
3. [Microservices Design](#3-microservices-design)
4. [Networking & Security](#4-networking--security)
5. [Container Platform](#5-container-platform)
6. [Data & Storage](#6-data--storage)
7. [CI/CD Pipeline](#7-cicd-pipeline)
8. [Monitoring & Autoscaling](#8-monitoring--autoscaling)
9. [Identity Federation](#9-identity-federation)
10. [Multi-Cloud Integration](#10-multi-cloud-integration)
11. [Security Analysis](#11-security-analysis)
12. [Cost Optimisation](#12-cost-optimisation)
13. [Challenges & Resolutions](#13-challenges--resolutions)
14. [Future Improvements](#14-future-improvements)

---

## 1. Architecture Design

### 1.1 Overview

The solution deploys two containerised microservices on AWS ECS Fargate, with a fully automated CI/CD pipeline using CodePipeline and CodeBuild (blue/green deployment via ALB listener swapping). Application assets are stored in GCP Cloud Storage to satisfy the multi-cloud requirement, and Azure Entra ID provides federated identity for secure AWS Console access.

### 1.2 Cloud Provider Responsibilities

| Provider | Responsibility | Justification |
|---|---|---|
| **AWS** | Compute (ECS Fargate), networking (VPC/ALB), CI/CD, monitoring, data (DynamoDB) | Primary platform as specified by the assessment brief |
| **GCP** | Application asset storage (Cloud Storage) | Demonstrates real multi-cloud data flow; Service B writes/reads assets cross-cloud |
| **Azure** | Identity federation (Entra ID SAML SSO) | Required by the assessment for federated AWS Console access |

### 1.3 Region Selection

All resources are deployed to the **Sydney** region on each provider:
- AWS: `ap-southeast-2`
- GCP: `australia-southeast1`

This minimises latency for cross-cloud communication between Service B (ECS in AWS) and GCP Cloud Storage, and reflects a realistic deployment for an Australia-based organisation.

---

## 2. Infrastructure as Code Strategy

### 2.1 Tool Choice — Terraform

Terraform was chosen over CloudFormation for:
- **Multi-cloud support** — single tool manages AWS and GCP resources
- **State management** — explicit state tracking with remote backend
- **Modular structure** — resources split across logical files
- **Provider ecosystem** — well-maintained AWS (~5.0) and GCP (~5.0) providers

### 2.2 File Organisation

Terraform files are split by domain rather than by resource type:

| File | Domain |
|---|---|
| `providers.tf` | Provider configuration and version pinning |
| `variables.tf` | All input parameters with defaults |
| `outputs.tf` | Key resource identifiers and endpoints |
| `backend.tf` | Remote state configuration |
| `vpc.tf` | VPC, subnets, IGW, routes |
| `security-groups.tf` | ALB and ECS security groups |
| `ecr.tf` | Container registries |
| `ecs-cluster.tf` | Fargate cluster |
| `iam.tf` | All IAM roles and policies |
| `alb-service-a.tf` / `alb-service-b.tf` | Load balancers and target groups |
| `ecs-service-a.tf` / `ecs-service-b.tf` | Task definitions and services |
| `cloudwatch.tf` | Monitoring alarms |
| `autoscaling.tf` | Scaling targets and policies |
| `sns.tf` | Notification topic |
| `s3.tf` | Pipeline artifacts bucket |
| `codebuild.tf` / `codepipeline.tf` | CI/CD resources (build + blue/green deploy) |
| `gcp-storage.tf` | GCP Cloud Storage bucket and IAM |
| `saml-entra-id.tf` | Azure Entra ID SAML federation |

### 2.3 State Management

**Remote backend:** S3 bucket with DynamoDB locking.

```hcl
backend "s3" {
  bucket         = "multicloud-devops-tfstate"
  key            = "assessment-1/terraform.tfstate"
  region         = "ap-southeast-2"
  dynamodb_table = "terraform-state-lock"
  encrypt        = true
}
```

**Why S3 + DynamoDB:**
- S3 provides durable, versioned state storage
- DynamoDB provides distributed locking to prevent concurrent modifications
- Both are in the AWS free tier for minimal usage
- Encryption at rest enabled by default

### 2.4 Variables & Defaults

All parameters are defined in `variables.tf` with sensible defaults. Only two variables are required (no default): `aws_account_id` and `gcp_project_id`.

This allows the infrastructure to be deployed with minimal configuration while remaining fully customisable.

---

## 3. Microservices Design

### 3.1 Service A — Transaction API

| Attribute | Value |
|---|---|
| Language | Python 3.12 |
| Framework | FastAPI |
| Database | AWS DynamoDB |
| Port | 8000 |
| Base image | python:3.12-slim |

**Endpoints:**
- `GET /health` — health check
- `GET /transactions` — list all transactions
- `GET /transactions/{id}` — get single transaction
- `POST /transactions` — create transaction
- `DELETE /transactions/{id}` — delete transaction

**Why FastAPI:** Lightweight, async-capable, automatic OpenAPI documentation, and excellent for containerised APIs.

### 3.2 Service B — Asset Manager

| Attribute | Value |
|---|---|
| Language | TypeScript |
| Runtime | Bun 1.1 |
| Storage | GCP Cloud Storage |
| Port | 3000 |
| Base image | oven/bun:1.1-alpine |

**Endpoints:**
- `GET /health` — health check
- `GET /assets` — list assets in GCP bucket
- `POST /assets/upload` — upload file to GCP bucket
- `GET /assets/:name` — download file from GCP bucket
- `DELETE /assets/:name` — delete file from GCP bucket

**Why Bun:** Fast startup time (important for Fargate cold starts), native TypeScript support, compact container image (~150MB).

### 3.3 Local Development

Both services support local development using emulators:
- **DynamoDB Local** — Amazon's official DynamoDB emulator
- **fake-gcs-server** — Open-source GCP Storage emulator

Services detect the emulator endpoints via environment variables (`DYNAMODB_ENDPOINT`, `GCS_ENDPOINT`), enabling identical code paths in local and cloud environments.

---

## 4. Networking & Security

### 4.1 VPC Design

```
VPC: 10.0.0.0/16 (65,536 IPs)
├── Public Subnet AZ1: 10.0.1.0/24 (256 IPs) — ap-southeast-2a
├── Public Subnet AZ2: 10.0.2.0/24 (256 IPs) — ap-southeast-2b
├── Internet Gateway
└── Route Table: 0.0.0.0/0 → IGW
```

**Design decisions:**
- **Public subnets only** — Fargate tasks with public IPs avoid the need for NAT Gateway ($32/month), appropriate for this assessment scope
- **Two AZs** — satisfies the high-availability requirement; ALBs and ECS services span both
- **/24 subnets** — 256 IPs per subnet, sufficient for the task count

### 4.2 Security Groups

**ALB Security Group:**
- Inbound: TCP 80 (HTTP) and TCP 443 (HTTPS) from `0.0.0.0/0`
- Outbound: All traffic

**ECS Tasks Security Group:**
- Inbound: TCP 8000 and TCP 3000 from ALB Security Group **only**
- Outbound: All traffic (needed for ECR image pulls, DynamoDB, GCP API calls)

**Key principle:** ECS tasks are not directly reachable from the internet. Traffic must flow through the ALB, which performs health checks and load balancing.

The security groups use the modern `aws_vpc_security_group_ingress_rule` / `egress_rule` resources rather than inline rules, for better state management and clarity.

---

## 5. Container Platform

### 5.1 ECR Repositories

Two repositories with:
- **Scan on push** — automatic vulnerability scanning
- **Lifecycle policy** — retain only the last 5 images to control storage costs
- **Force delete** — allows Terraform to clean up repos with images during destroy

### 5.2 ECS Cluster

Single Fargate cluster with **Container Insights** enabled for enhanced monitoring (CPU, memory, network metrics at the task level).

### 5.3 Task Definitions

| Setting | Value | Rationale |
|---|---|---|
| CPU | 256 (0.25 vCPU) | Smallest Fargate size, sufficient for demo APIs |
| Memory | 512 MiB | Minimum for 256 CPU |
| Network mode | awsvpc | Required for Fargate |
| Log driver | awslogs | Sends stdout/stderr to CloudWatch Logs |

### 5.4 ECS Services

Each service:
- Runs in both AZs via the ALB
- Uses `ECS` deployment controller with script-managed blue/green via ALB listener swap
- Has `lifecycle { ignore_changes = [task_definition] }` to prevent Terraform from fighting with the deploy script over the active task definition
- Starts with `desired_count = 1`, scaled by autoscaling policies

### 5.5 IAM Roles (Least Privilege)

| Role | Purpose | Permissions |
|---|---|---|
| ECS Task Execution | Pull images, write logs | `AmazonECSTaskExecutionRolePolicy` (managed) |
| Service A Task | Application-level access | DynamoDB CRUD on transactions table only |
| Service B Task | Application-level access | Minimal (GCP access via service account key, not IAM) |

---

## 6. Data & Storage

### 6.1 DynamoDB — Transactions Table

| Setting | Value | Rationale |
|---|---|---|
| Billing mode | PAY_PER_REQUEST | Zero cost when idle, no capacity planning needed |
| Partition key | `transaction_id` (String) | High cardinality, unique per record |
| Encryption | AWS-owned key (default) | Free, sufficient for assessment |

### 6.2 S3 — Pipeline Artifacts

| Setting | Value |
|---|---|
| Access | Private (block all public access) |
| Encryption | AES-256 (SSE-S3) |
| Force destroy | Enabled (for clean teardown) |

Stores CodePipeline artifacts (source ZIP, build outputs) between pipeline stages.

### 6.3 GCP Cloud Storage — Application Assets

| Setting | Value |
|---|---|
| Storage class | STANDARD |
| Location | australia-southeast1 |
| Access control | Uniform bucket-level |
| Force destroy | Enabled |

A dedicated GCP service account has `roles/storage.objectAdmin` scoped to this bucket only (not project-wide).

---

## 7. CI/CD Pipeline

### 7.1 Pipeline Architecture

```
Source (GitHub)
    │
    ├── Build Service A (CodeBuild)  ──┐
    │                                   ├── Parallel (run_order = 1)
    ├── Build Service B (CodeBuild)  ──┘
    │
    ├── Deploy Service A (CodeBuild) ──┐
    │   (ALB listener swap)             ├── Parallel (run_order = 1)
    └── Deploy Service B (CodeBuild) ──┘
        (ALB listener swap)
```

### 7.2 Source Stage

Uses AWS CodeStar Connections to poll a GitHub repository. The connection must be created manually in the AWS Console (one-time setup), and the ARN is passed to Terraform via `codestar_connection_arn`.

### 7.3 Build Stage — CodeBuild

Each CodeBuild project:
- Uses `aws/codebuild/standard:7.0` image (Ubuntu 22.04, Docker pre-installed)
- Runs in **privileged mode** (required for `docker build`)
- Logs to CloudWatch (7-day retention)
- Timeout: 15 minutes

**Build steps** (from `buildspec-service-*.yml`):
1. Login to ECR
2. `docker build` with git commit SHA as tag
3. `docker push` to ECR
4. Generate `imagedefinitions-*.json` for the deploy stage

### 7.4 Deploy Stage — CodeBuild (ALB Listener Swap)

**Blue/green deployment** for each ECS service (without CodeDeploy):
- **Mechanism:** ALB listener swap via a CodeBuild deploy project
- **Traffic routing:** Instant cutover (listener default action change)
- **Health validation:** Waits for ECS service stability before swapping
- **Auto-rollback:** If health checks fail, reverts to previous task def and listener

Each service has two target groups (blue and green) and two listeners:
- **Port 80** (production) — points to the currently active TG
- **Port 8080** (test) — points to the standby TG for pre-swap validation

During deployment:
1. Deploy script determines which TG is currently live ("blue")
2. Registers a new task definition with the updated image
3. Updates the ECS service to deploy new tasks on the "green" TG
4. Waits for new tasks to pass health checks (service stability)
5. Swaps the production listener (port 80) from blue → green
6. Next deployment reverses roles (old green becomes new blue)

### 7.5 IAM Roles for CI/CD

| Role | Key Permissions |
|---|---|
| CodeBuild | ECR push, CloudWatch Logs, S3 artifacts, ECS update, ELB modify listener, PassRole |
| CodePipeline | S3, CodeStar, CodeBuild start |

All follow least-privilege principle — each role has only the permissions needed for its specific function.

---

## 8. Monitoring & Autoscaling

### 8.1 CloudWatch Alarms

| Alarm | Metric | Threshold | Action |
|---|---|---|---|
| service-a-cpu-high | CPUUtilization | > 70% for 2 min | Scale out + SNS |
| service-a-cpu-low | CPUUtilization | < 30% for 2 min | Scale in + SNS |
| service-b-cpu-high | CPUUtilization | > 70% for 2 min | Scale out + SNS |
| service-b-cpu-low | CPUUtilization | < 30% for 2 min | Scale in + SNS |

### 8.2 Autoscaling Policies

| Policy | Type | Adjustment | Cooldown |
|---|---|---|---|
| Scale out (×2) | Step scaling | +1 task | 60 seconds |
| Scale in (×2) | Step scaling | -1 task | 60 seconds |

**Scaling range:** Minimum 1 task, maximum 4 tasks per service.

**Why step scaling over target tracking:** Step scaling provides explicit control over when and how scaling occurs, making it easier to demonstrate and explain for the assessment. Target tracking is simpler but less visible in terms of the scaling logic.

### 8.3 SNS Notifications

One SNS topic receives all alarm notifications. An email subscription is conditionally created only if `notification_email` is provided (avoids errors when no email is set).

### 8.4 CloudWatch Logs

Log groups with 7-day retention for:
- Service A container logs
- Service B container logs
- CodeBuild project logs (Service A)
- CodeBuild project logs (Service B)

---

## 9. Identity Federation

### 9.1 SAML 2.0 Flow

```
User → Azure Entra ID (authenticate + MFA)
     → SAML Assertion (contains role claim)
     → AWS STS AssumeRoleWithSAML
     → AWS Console (role-based session)
```

### 9.2 AWS-Side Configuration (Terraform)

- `aws_iam_saml_provider` — registers Entra ID's metadata (certificate + endpoints)
- `aws_iam_role.entra_devops_engineer` — trusts the SAML provider, attached `PowerUserAccess`
- `aws_iam_role.entra_readonly_auditor` — trusts the SAML provider, attached `ViewOnlyAccess`

### 9.3 Azure-Side Configuration (Manual)

Documented in `docs/entra-id-setup.md`. Key steps:
1. Create Enterprise Application (AWS Single-Account Access)
2. Configure SAML claims (RoleSessionName, Role)
3. Export Federation Metadata XML
4. Assign users/groups to app roles

### 9.4 Role Mapping

| Entra ID App Role | AWS IAM Role | Permissions |
|---|---|---|
| DevOpsEngineer | `multicloud-dev-devops-engineer` | `PowerUserAccess` — full service access except IAM management |
| ReadOnlyAuditor | `multicloud-dev-readonly-auditor` | `ViewOnlyAccess` — read-only for compliance/audit |

---

## 10. Multi-Cloud Integration

### 10.1 How the Clouds Connect

| Connection | Protocol | Purpose |
|---|---|---|
| AWS ↔ GCP | HTTPS (GCP Storage API) | Service B in ECS writes/reads assets to/from GCP bucket |
| Azure → AWS | SAML 2.0 (browser redirect) | Entra ID users sign into AWS Console |
| Local ↔ Emulators | HTTP (localhost) | Development: DynamoDB Local + fake-gcs-server |

### 10.2 Cross-Cloud Authentication

- **AWS → GCP:** GCP service account key (injected as environment variable or secret in ECS task definition)
- **Azure → AWS:** SAML federation (no credentials stored; uses signed assertions)

### 10.3 Data Flow

```
User HTTP Request
    ↓
ALB (AWS)
    ↓
ECS Fargate Task (AWS)
    ↓ (Service A)           ↓ (Service B)
DynamoDB (AWS)          GCP Cloud Storage (GCP)
    ↓                       ↓
Response to User        Response to User
```

---

## 11. Security Analysis

### 11.1 Network Security

- ALBs are the only public entry points
- ECS tasks accept traffic only from ALBs (security group chaining)
- No SSH/RDP access to containers (serverless Fargate)
- All internal communication uses AWS VPC networking

### 11.2 Identity & Access

- **IAM roles use least privilege** — each role has only the permissions it needs
- **No long-lived credentials** — ECS tasks use IAM task roles (temporary STS credentials)
- **SAML federation** — no AWS passwords for human users; authentication via Entra ID
- **MFA enforced** — via Entra ID Conditional Access policies

### 11.3 Data Protection

- S3: server-side encryption (AES-256), all public access blocked
- DynamoDB: encryption at rest (AWS-owned key)
- ECR: image scanning on push detects known vulnerabilities
- State file: encrypted at rest in S3

### 11.4 CI/CD Security

- CodeBuild uses IAM roles (no hardcoded credentials)
- Pipeline artifacts encrypted in S3
- Blue/green deploy auto-rollback on health check failure
- GitHub connection via CodeStar (OAuth, not personal tokens)

### 11.5 OWASP Top 10 Considerations

| Risk | Mitigation |
|---|---|
| Broken Access Control | Security group isolation, least-privilege IAM, SAML role mapping |
| Cryptographic Failures | Encryption at rest for S3, DynamoDB, state file |
| Injection | Parameterised DynamoDB queries via boto3 SDK |
| Insecure Design | Defence in depth: ALB → SG → ECS → IAM → service |
| Security Misconfiguration | All public access blocked on S3; Terraform enforces consistent config |

---

## 12. Cost Optimisation

### 12.1 Design Choices for Cost Control

| Choice | Saving |
|---|---|
| Fargate 256 CPU / 512 MiB | Smallest possible size ($0.25/task/day in Sydney) |
| No NAT Gateway | Saves ~$32/month per gateway |
| DynamoDB PAY_PER_REQUEST | $0 when idle |
| CloudWatch Logs 7-day retention | Minimises log storage costs |
| ECR lifecycle (keep 5 images) | Limits container image storage |
| GCP Standard storage | Cheapest tier, sufficient for assessment |

### 12.2 Free Tier Coverage

| Service | Free Tier |
|---|---|
| DynamoDB | 25GB storage, 25 WCU/RCU always free |
| CloudWatch | 10 alarms, 5GB log ingestion/month |
| ECR | 500MB storage/month |
| SNS | 1M publishes, 100K emails/month |
| S3 | 5GB storage, 20K GET, 2K PUT/month |
| GCP Storage | 5GB, 1GB egress/month |

### 12.3 Estimated Running Cost

**If left running 24/7:** ~$1.60/day (~$48/month)

**Assessment strategy:** Deploy → collect evidence (1-2 hours) → destroy. Total cost: **< $0.25**

---

## 13. Challenges & Resolutions

### 13.1 Blue/Green Deployment Without CodeDeploy

**Challenge:** AWS CodeDeploy requires service activation which was unavailable on the account. Blue/green deployment needed an alternative approach that still provides zero-downtime deployments and automatic rollback.

**Resolution:** Implemented a CodeBuild-based blue/green deploy using ALB listener swapping. Each service has two target groups (blue + green) and two ALB listeners (port 80 for production, port 8080 for testing). The deploy script registers a new task definition, launches tasks on the standby TG, waits for health, then atomically swaps the production listener's target group. Rollback is automatic if the ECS service fails to stabilise.

### 13.2 Local Development Without Cloud Access

**Challenge:** Services depend on DynamoDB and GCP Cloud Storage — testing requires cloud accounts and credentials.

**Resolution:** Integrated DynamoDB Local and fake-gcs-server emulators into `docker-compose.yml`. Services detect emulator endpoints via environment variables, allowing identical code to run locally and in the cloud.

### 13.3 Terraform Validation with Forward References

**Challenge:** `outputs.tf` was created early (Phase 2) but references resources from later phases, causing `terraform validate` errors during incremental development.

**Resolution:** Accepted validation errors during development and resolved them as each phase was completed. Final validation passes cleanly.

### 13.4 Multi-Cloud Authentication

**Challenge:** Service B needs to authenticate with GCP from within AWS ECS.

**Resolution:** Created a dedicated GCP service account with bucket-scoped `objectAdmin` permissions. The service account key can be injected into the ECS task definition as an environment variable or via AWS Secrets Manager.

### 13.5 Windows Development Environment

**Challenge:** Bash scripts don't run natively on Windows.

**Resolution:** Created both `.sh` (for Linux/CI environments) and `.ps1` (for Windows PowerShell) versions of all scripts. Terraform can also be run via Docker when not installed locally.

---

## 14. Future Improvements

If this were a production system, these enhancements would be recommended:

| Improvement | Benefit |
|---|---|
| Private subnets + NAT Gateway | Better security — ECS tasks not assignable public IPs |
| AWS Secrets Manager | Secure GCP service account key storage |
| HTTPS (ACM + Route 53) | TLS termination on ALBs with custom domain |
| WAF on ALBs | Protection against common web attacks |
| Multi-region deployment | Disaster recovery and global latency reduction |
| Terraform modules | Reusable infrastructure patterns for team adoption |
| Container image signing | Supply chain security with Notation/Cosign |
| Cost alerts | AWS Budgets with SNS notifications |
| Target tracking autoscaling | Simpler, self-adjusting scaling policies |
| Terraform Cloud | Remote execution, team collaboration, policy as code |
