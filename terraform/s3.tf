# -------------------------------------------------------
# S3 Bucket - CodePipeline artifact storage
# Stores build artifacts (imagedefinitions, appspec) between
# pipeline stages. Encrypted at rest with AES-256.
# Expect: 1 private S3 bucket with versioning disabled and
#         force_destroy = true for easy teardown.
# -------------------------------------------------------

resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "${var.project_name}-${var.environment}-pipeline-artifacts-${var.aws_account_id}"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-${var.environment}-pipeline-artifacts"
  }
}

# Block all public access – pipeline artifacts are internal only.
resource "aws_s3_bucket_public_access_block" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-side encryption with Amazon-managed keys (no extra cost).
resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
