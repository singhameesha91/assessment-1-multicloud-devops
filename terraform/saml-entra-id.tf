# -------------------------------------------------------
# Azure Entra ID (formerly Azure AD) — SAML Federation
# Configures AWS IAM to trust Azure Entra ID as an identity
# provider via SAML 2.0. This allows Entra ID users to
# assume AWS IAM roles through single sign-on (SSO).
# Satisfies the multi-cloud identity requirement (LO1/LO3)
# by federating Azure → AWS for role-based access.
#
# Prerequisites (manual steps in Azure — see docs/entra-id-setup.md):
#   1. Create an Enterprise Application in Entra ID
#   2. Configure SAML SSO with AWS sign-in URL
#   3. Download the Federation Metadata XML
#   4. Place the XML file at terraform/entra-id-metadata.xml
#      (or update var.saml_metadata_file path)
#
# Expect: 1 SAML provider, 2 federated IAM roles
#   - DevOpsEngineer: broad access for deployment operations
#   - ReadOnlyAuditor: read-only access for compliance reviews
# -------------------------------------------------------

# ==================== SAML Identity Provider ====================
# Registers Azure Entra ID as a trusted SAML provider in AWS.
# The metadata XML contains Entra's certificate and SSO endpoints.

resource "aws_iam_saml_provider" "entra_id" {
  name                   = "${var.project_name}-${var.environment}-entra-id"
  saml_metadata_document = file(var.saml_metadata_file)

  tags = {
    Name = "${var.project_name}-${var.environment}-entra-id"
  }
}

# ==================== DevOps Engineer Role ====================
# Full access role for engineers who deploy and manage the platform.
# Entra ID users assigned the "DevOpsEngineer" app role in Azure
# will assume this IAM role when they SSO into AWS.

data "aws_iam_policy_document" "entra_devops_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithSAML"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_saml_provider.entra_id.arn]
    }

    # Condition: only allow web-console SSO (not programmatic)
    condition {
      test     = "StringEquals"
      variable = "SAML:aud"
      values   = ["https://signin.aws.amazon.com/saml"]
    }
  }
}

resource "aws_iam_role" "entra_devops_engineer" {
  name               = "${var.project_name}-${var.environment}-devops-engineer"
  assume_role_policy = data.aws_iam_policy_document.entra_devops_assume.json

  tags = {
    Name = "${var.project_name}-${var.environment}-devops-engineer"
  }
}

# DevOps Engineer permissions — PowerUserAccess allows full
# service access except IAM user/group management (secure).
resource "aws_iam_role_policy_attachment" "devops_power_user" {
  role       = aws_iam_role.entra_devops_engineer.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# ==================== Read-Only Auditor Role ====================
# Restricted role for compliance reviews and auditing.
# Entra ID users assigned "ReadOnlyAuditor" app role in Azure
# will assume this role — they can view resources but not modify.

data "aws_iam_policy_document" "entra_auditor_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithSAML"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_saml_provider.entra_id.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "SAML:aud"
      values   = ["https://signin.aws.amazon.com/saml"]
    }
  }
}

resource "aws_iam_role" "entra_readonly_auditor" {
  name               = "${var.project_name}-${var.environment}-readonly-auditor"
  assume_role_policy = data.aws_iam_policy_document.entra_auditor_assume.json

  tags = {
    Name = "${var.project_name}-${var.environment}-readonly-auditor"
  }
}

# ReadOnly permissions — ViewOnlyAccess for audit/compliance.
resource "aws_iam_role_policy_attachment" "auditor_view_only" {
  role       = aws_iam_role.entra_readonly_auditor.name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}
