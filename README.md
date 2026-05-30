# Multi-Cloud DevOps Pipeline

**DCE04.2 Assessment 1 — AWS Containerised DevOps Pipeline: Microservices Deployment**

A multi-cloud infrastructure project that deploys two microservices on AWS ECS Fargate with a full CI/CD pipeline, GCP Cloud Storage integration, and Azure Entra ID identity federation — all provisioned via Terraform.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud (ap-southeast-2)                 │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    VPC 10.0.0.0/16                            │  │
│  │  ┌─────────────────────┐  ┌─────────────────────┐            │  │
│  │  │  Public Subnet AZ1  │  │  Public Subnet AZ2  │            │  │
│  │  │    10.0.1.0/24      │  │    10.0.2.0/24      │            │  │
│  │  └─────────────────────┘  └─────────────────────┘            │  │
│  │           │                         │                         │  │
│  │  ┌────────┴─────────────────────────┴────────┐               │  │
│  │  │  ALB Service A (port 80 → 8000)           │               │  │
│  │  │  ALB Service B (port 80 → 3000)           │               │  │
│  │  └───────────────────────────────────────────┘               │  │
│  │           │                         │                         │  │
│  │  ┌────────┴────────┐  ┌─────────────┴──────────┐            │  │
│  │  │ ECS Fargate     │  │ ECS Fargate            │            │  │
│  │  │ Service A       │  │ Service B              │            │  │
│  │  │ (Python/FastAPI) │  │ (Bun/TypeScript)      │            │  │
│  │  │  → DynamoDB     │  │  → GCP Cloud Storage   │            │  │
│  │  └─────────────────┘  └────────────────────────┘            │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  CI/CD: CodePipeline → CodeBuild (×2) → CodeDeploy (×2)    │   │
│  │         Blue/Green ECS Deployment                            │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  CloudWatch Logs & Alarms │ Autoscaling │ SNS │ ECR │ DynamoDB     │
└─────────────────────────────────────────────────────────────────────┘
         ▲                                              │
         │ SAML 2.0 Federation                          │
┌────────┴──────────┐                      ┌────────────┴────────────┐
│  Azure Entra ID   │                      │  GCP Cloud Storage      │
│  (Identity)       │                      │  (Application Assets)   │
└───────────────────┘                      └─────────────────────────┘
```

---

## Cloud Providers Used

| Provider | Purpose | Region |
|---|---|---|
| **AWS** | Primary compute, networking, CI/CD, monitoring, data | ap-southeast-2 (Sydney) |
| **GCP** | Application asset storage (Cloud Storage bucket) | australia-southeast1 (Sydney) |
| **Azure** | Identity federation (Entra ID SAML SSO → AWS Console) | N/A (global service) |

---

## Microservices

| Service | Stack | Port | Purpose |
|---|---|---|---|
| **Service A** | Python 3.12 / FastAPI / boto3 | 8000 | Transaction CRUD → DynamoDB |
| **Service B** | Bun 1.1 / TypeScript / @google-cloud/storage | 3000 | Asset management → GCP Cloud Storage |

---

## Project Structure

```
assessment-1-multicloud-devops/
├── README.md                    ← This file
├── OPERATIONAL_MANUAL.md        ← Step-by-step deployment & teardown guide
├── IMPLEMENTATION.md            ← Technical implementation document
├── docker-compose.yml           ← Local development with emulators
├── buildspec-service-a.yml      ← CodeBuild spec for Service A
├── buildspec-service-b.yml      ← CodeBuild spec for Service B
├── appspec-service-a.json       ← CodeDeploy ECS appspec for Service A
├── appspec-service-b.json       ← CodeDeploy ECS appspec for Service B
│
├── services/
│   ├── service-a/               ← Python FastAPI microservice
│   │   ├── Dockerfile
│   │   ├── main.py
│   │   └── requirements.txt
│   └── service-b/               ← Bun TypeScript microservice
│       ├── Dockerfile
│       ├── package.json
│       ├── tsconfig.json
│       └── src/index.ts
│
├── terraform/                   ← All IaC configuration
│   ├── providers.tf             ← AWS + GCP providers (pinned versions)
│   ├── variables.tf             ← All configurable parameters
│   ├── outputs.tf               ← Key resource identifiers & endpoints
│   ├── backend.tf               ← S3 + DynamoDB remote state
│   ├── terraform.tfvars.example ← Template for variable values
│   ├── vpc.tf                   ← VPC, subnets, IGW, routes
│   ├── security-groups.tf       ← ALB + ECS security groups
│   ├── ecr.tf                   ← 2 ECR repositories
│   ├── ecs-cluster.tf           ← Fargate cluster
│   ├── dynamodb.tf              ← Transactions table
│   ├── iam.tf                   ← All IAM roles & policies
│   ├── alb-service-a.tf         ← ALB + target groups (blue/green)
│   ├── alb-service-b.tf         ← ALB + target groups (blue/green)
│   ├── ecs-service-a.tf         ← Task def + ECS service
│   ├── ecs-service-b.tf         ← Task def + ECS service
│   ├── cloudwatch.tf            ← 4 CPU alarms
│   ├── autoscaling.tf           ← Scaling targets + policies
│   ├── sns.tf                   ← Notification topic
│   ├── s3.tf                    ← Pipeline artifacts bucket
│   ├── codebuild.tf             ← 2 CodeBuild projects
│   ├── codedeploy.tf            ← 2 CodeDeploy apps (blue/green)
│   ├── codepipeline.tf          ← CI/CD pipeline
│   ├── gcp-storage.tf           ← GCP Cloud Storage bucket + SA
│   └── saml-entra-id.tf         ← Azure Entra ID SAML federation
│
├── scripts/                     ← Automation scripts
│   ├── deploy.sh / deploy.ps1
│   ├── destroy.sh / destroy.ps1
│   ├── push-images.sh / push-images.ps1
│   └── validate.sh / validate.ps1
│
└── docs/
    ├── entra-id-setup.md        ← Azure Entra portal setup guide
    └── screenshots/             ← Evidence screenshots
```

---

## Quick Start — Local Development

```bash
# Clone and start services with emulators (DynamoDB Local + fake-gcs-server)
docker compose up --build -d

# Test Service A (DynamoDB CRUD)
curl http://localhost:8000/health
curl -X POST http://localhost:8000/transactions \
  -H "Content-Type: application/json" \
  -d '{"amount": 99.99, "description": "Test"}'

# Test Service B (GCS Asset management)
curl http://localhost:3000/health

# Stop
docker compose down
```

---

## Deployment — AWS + GCP

See [OPERATIONAL_MANUAL.md](OPERATIONAL_MANUAL.md) for detailed step-by-step instructions.

**Quick summary:**

```bash
# 1. Configure variables
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 2. Deploy infrastructure
terraform init
terraform plan
terraform apply

# 3. Push Docker images to ECR
.\scripts\push-images.ps1        # Windows
./scripts/push-images.sh          # Linux/Mac

# 4. Pipeline triggers automatically on git push to main
```

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| **Fargate 256 CPU / 512 MiB** | Smallest available size, minimises cost for assessment |
| **Public subnets only** | Simplifies architecture; NAT Gateway costs ~$32/month avoided |
| **GCP bucket instead of 2nd S3** | Satisfies multi-cloud requirement (LO1) with real cross-cloud data flow |
| **Blue/green deployment** | Zero-downtime releases via CodeDeploy with automatic rollback |
| **PAY_PER_REQUEST DynamoDB** | No provisioned capacity cost when idle |
| **Step scaling policies** | Simpler than target tracking; demonstrates explicit scale-out/in logic |
| **Entra ID SAML (manual)** | Azure portal steps documented rather than automated — Entra Terraform provider requires admin consent |

---

## Terraform Resource Count

| Category | Resources |
|---|---|
| Networking | VPC, 2 subnets, IGW, route table, 2 ALBs, 4 target groups |
| Compute | ECS cluster, 2 task definitions, 2 services |
| Storage | 2 ECR repos, 1 DynamoDB table, 1 S3 bucket, 1 GCP bucket |
| CI/CD | 2 CodeBuild, 2 CodeDeploy, 1 CodePipeline |
| Monitoring | 4 CloudWatch alarms, 2 autoscaling targets, 4 scaling policies, 1 SNS topic |
| Security | 2 security groups, 6+ IAM roles, 1 SAML provider |
| Identity | 2 SAML-federated IAM roles (DevOpsEngineer, ReadOnlyAuditor) |

---

## Cost Awareness

> **Important:** This infrastructure will incur AWS charges. Destroy resources promptly after collecting evidence.

| Resource | Estimated Cost |
|---|---|
| ECS Fargate (2 tasks, minimal) | ~$0.50/day |
| ALB (2 load balancers) | ~$1.10/day |
| DynamoDB (on-demand) | ~$0/day (free tier) |
| CloudWatch | ~$0/day (free tier) |
| ECR | ~$0/day (free tier up to 500MB) |
| GCP Cloud Storage | ~$0/day (free tier) |
| **Total estimate** | **~$1.60/day** |

**Teardown:** Run `.\scripts\destroy.ps1` or `terraform destroy` immediately after evidence collection.

---

## References

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform GCP Provider Documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [AWS ECS Developer Guide](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/)
- [AWS CodePipeline User Guide](https://docs.aws.amazon.com/codepipeline/latest/userguide/)
- [Azure Entra ID SAML SSO for AWS](https://learn.microsoft.com/en-us/entra/identity/saas-apps/amazon-web-service-tutorial)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Bun Documentation](https://bun.sh/docs/)
