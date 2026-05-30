# -------------------------------------------------------
# Terraform Backend Configuration
# Remote state stored in S3 with DynamoDB locking
# -------------------------------------------------------
#
# IMPORTANT - BOOTSTRAPPING INSTRUCTIONS:
#
# Before enabling this backend, you must first create the S3 bucket
# and DynamoDB table. There are two approaches:
#
# Option A: Create them manually via AWS CLI (recommended for first run):
#
#   aws s3api create-bucket \
#     --bucket multicloud-devops-tfstate \
#     --region ap-southeast-2 \
#     --create-bucket-configuration LocationConstraint=ap-southeast-2
#
#   aws s3api put-bucket-versioning \
#     --bucket multicloud-devops-tfstate \
#     --versioning-configuration Status=Enabled
#
#   aws s3api put-bucket-encryption \
#     --bucket multicloud-devops-tfstate \
#     --server-side-encryption-configuration \
#     '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
#
#   aws s3api put-public-access-block \
#     --bucket multicloud-devops-tfstate \
#     --public-access-block-configuration \
#     BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
#
#   aws dynamodb create-table \
#     --table-name terraform-state-lock \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST \
#     --region ap-southeast-2
#
# Option B: Run terraform apply with local state first (backend commented out),
#           then uncomment and run terraform init -migrate-state.
#
# STEP 1: First run with local state — keep the block below commented out.
# STEP 2: After successful local apply, uncomment the block below.
# STEP 3: Run: terraform init -migrate-state
# STEP 4: Confirm migration when prompted.
# -------------------------------------------------------

# Uncomment the block below after creating the S3 bucket and DynamoDB table:

# terraform {
#   backend "s3" {
#     bucket         = "multicloud-devops-tfstate"
#     key            = "assessment/terraform.tfstate"
#     region         = "ap-southeast-2"
#     dynamodb_table = "terraform-state-lock"
#     encrypt        = true
#   }
# }
