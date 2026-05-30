# Azure Entra ID — SAML Federation Setup Guide

This document provides step-by-step instructions for configuring Azure Entra ID
(formerly Azure Active Directory) to federate with AWS IAM via SAML 2.0.

Once configured, Entra ID users can sign into the AWS Management Console using
their Azure credentials — no separate AWS IAM users needed.

---

## Prerequisites

| Requirement | Detail |
|---|---|
| Azure subscription | Free tier or any paid plan |
| Entra ID role | Global Administrator or Application Administrator |
| AWS account | The target account where Terraform will be applied |
| AWS CLI configured | Run `aws sts get-caller-identity` to confirm access |
| Terraform installed | v1.5+ with AWS and GCP providers |

### AWS Setup Required Before Entra ID Configuration

The SAML provider and IAM roles are created **by Terraform** — you do NOT create them manually in AWS.
The recommended workflow order is:

1. **Steps 1–2** — Create the Enterprise App and configure basic SAML settings in Entra ID
2. **Step 4** — Download the Federation Metadata XML from Entra ID
3. **Step 5** — Run `terraform apply` to create the SAML provider + IAM roles in AWS
4. **Step 3 (Role Claim)** — Go back to Entra ID and configure the Role claim using the ARNs that Terraform created
5. **Steps 6–7** — Assign users and test SSO

> **Why this order?** The Role claim in Step 3 requires the exact ARNs of the IAM roles and SAML provider,
> which only exist after Terraform creates them. You can set up everything else in Entra ID first, then
> come back to add the Role claim after `terraform apply`.

---

## Step 1 — Create an Enterprise Application in Entra ID

1. Go to [Azure Portal → Entra ID](https://entra.microsoft.com)
2. Navigate to **Identity → Applications → Enterprise applications**
3. Click **+ New application**
4. Search for **"Amazon Web Services (AWS)"** in the gallery
5. Select **AWS Single-Account Access**
6. Name it: `multicloud-devops-aws-sso` (or similar)
7. Click **Create**

---

## Step 2 — Configure SAML Single Sign-On

1. In the new Enterprise App, go to **Single sign-on** in the left menu
2. Select **SAML** as the SSO method
3. Under **Basic SAML Configuration**, click **Edit** and set:

| Field | Value |
|---|---|
| Identifier (Entity ID) | `urn:amazon:webservices` |
| Reply URL (ACS URL) | `https://signin.aws.amazon.com/saml` |
| Sign on URL | *(leave blank — do NOT set this)* |
| Relay State | *(leave blank)* |

> **Important:** Do NOT set the Sign on URL to `https://signin.aws.amazon.com/saml`.
> AWS SAML federation uses **IdP-initiated SSO** (login starts from Entra ID, not from AWS).
> Setting a Sign on URL causes a plain redirect to AWS without a SAML assertion, resulting in
> the error: *"Your request did not include a SAML response."*

4. Click **Save**

---

## Step 3 — Configure Claims (Attributes & Claims)

1. Under **Attributes & Claims**, click **Edit**
2. Ensure these claims exist (add/edit as needed):

| Claim Name | Value |
|---|---|
| `https://aws.amazon.com/SAML/Attributes/RoleSessionName` | `user.mail` |
| `https://aws.amazon.com/SAML/Attributes/Role` | `user.assignedroles` |

> **Why `user.mail` instead of `user.userprincipalname`?** For external/guest users in Entra ID,
> the UPN contains `#EXT#` (e.g., `name_gmail.com#EXT#@tenant.onmicrosoft.com`) which violates
> AWS's RoleSessionName pattern: `[a-zA-Z_0-9+=,.@-]{2,64}`. Using `user.mail` gives the clean
> email address (e.g., `singhameesha28@gmail.com`) which is always valid.

### Role Claim Format

The Role claim maps an Entra ID group/app-role to an AWS IAM role + SAML provider ARN pair.

**Format:**
```
arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME>,arn:aws:iam::<ACCOUNT_ID>:saml-provider/<PROVIDER_NAME>
```

**Example for DevOps Engineer:**
```

arn:aws:iam::587601535321:role/multicloud-devops-dev-devops-engineer,arn:aws:iam::587601535321:saml-provider/multicloud-devops-dev-entra-id
```

**Example for Read-Only Auditor:**
```
arn:aws:iam::587601535321:role/multicloud-devops-dev-readonly-auditor,arn:aws:iam::587601535321:saml-provider/multicloud-devops-dev-entra-id
```

> **How to find these values:**
>
> 1. **AWS Account ID** — Run `aws sts get-caller-identity --query Account --output text` in your terminal,
>    or find it in the AWS Console top-right menu under your username. It is also set as `aws_account_id`
>    in `terraform/terraform.tfvars`.
>
> 2. **Role and Provider names** — These are created by Terraform in `saml-entra-id.tf` using the pattern
>    `{project_name}-{environment}-<suffix>`. With the default values (`project_name = "multicloud-devops"`,
>    `environment = "dev"`), the naming is:
>    - SAML Provider: `multicloud-devops-dev-entra-id`
>    - DevOps Role: `multicloud-devops-dev-devops-engineer`
>    - Auditor Role: `multicloud-devops-dev-readonly-auditor`
>
>    Check your `terraform/terraform.tfvars` for the actual `project_name` and `environment` values.
>
> **Important:** Terraform must be applied **first** (Step 5 below) to create the SAML provider and IAM
> roles on the AWS side. Then come back here and configure the Role claim in Entra ID using the ARNs
> from the Terraform output. The workflow is:
> 1. Download metadata XML (Step 4) → 2. Apply Terraform (Step 5) → 3. Configure Role claim here with the created ARNs.

---

## Step 4 — Download Federation Metadata XML

1. In the SAML configuration page, scroll to **SAML Certificates**
2. Click **Download** next to **Federation Metadata XML**
3. Save the file as `entra-id-metadata.xml`
4. Place it in the `terraform/` directory:
   ```
   assessment-1-multicloud-devops/
     terraform/
       entra-id-metadata.xml    ← place here
       saml-entra-id.tf
       ...
   ```

---

## Step 5 — Apply Terraform

Once the metadata XML is in place:

```bash
cd terraform
terraform plan    # Review — should include SAML provider + 2 federated roles
terraform apply   # Creates all infrastructure including the SAML federation
```

Terraform reads the XML via `file(var.saml_metadata_file)` and registers it
as an AWS IAM SAML provider. The SAML provider and both federated roles
(`devops-engineer` and `readonly-auditor`) are defined in `saml-entra-id.tf`.

---

## Step 6 — Assign Users in Entra ID

1. Go back to the Enterprise Application in Entra ID
2. Navigate to **Users and groups** → **+ Add user/group**
3. Assign users or groups with the appropriate role:

| Entra ID Assignment | AWS Role Assumed |
|---|---|
| DevOpsEngineer app role | `multicloud-devops-dev-devops-engineer` |
| ReadOnlyAuditor app role | `multicloud-devops-dev-readonly-auditor` |

---

## Step 7 — Test SSO Login

1. In the Enterprise App, go to **Single sign-on**
2. Click **Test this application**
3. A user assigned a role should be redirected to the AWS Console
4. Verify the correct IAM role is assumed (check top-right in AWS Console)

---

## Troubleshooting

| Issue | Solution |
|---|---|
| "Not authorized to perform sts:AssumeRoleWithSAML" | Check the Role claim format — ARNs must exactly match the Terraform-created resources |
| "Response signature invalid" | Re-download the metadata XML and re-apply Terraform |
| User can't see the app in MyApps | Ensure the user is assigned to the Enterprise Application |
| Wrong role assumed | Verify the Role claim value maps to the correct IAM role ARN |

---

## Architecture Diagram

```
┌─────────────────┐     SAML 2.0      ┌──────────────┐
│  Azure Entra ID │ ────────────────►  │   AWS IAM    │
│  (IdP)          │   Federation       │   (SP)       │
│                 │   Metadata XML     │              │
│  Users/Groups   │                    │  SAML Provider│
│  App Roles      │                    │  IAM Roles   │
└─────────────────┘                    └──────────────┘
        │                                     │
        │  SSO Login                          │  AssumeRoleWithSAML
        ▼                                     ▼
   ┌──────────┐                        ┌──────────────┐
   │  User    │ ─────────────────────► │  AWS Console │
   │  Browser │   Redirect + SAML      │  (Role-based)│
   └──────────┘   Assertion            └──────────────┘
```

---

## Security Notes

- **No AWS credentials stored in Azure** — federation uses SAML assertions, not keys.
- **Least privilege** — DevOps gets PowerUserAccess; Auditor gets ViewOnlyAccess.
- **Session duration** — AWS default is 1 hour; configurable via `DurationSeconds` in the role trust policy.
- **MFA** — Can be enforced via Entra ID Conditional Access policies (recommended for production).
