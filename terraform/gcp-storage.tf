# -------------------------------------------------------
# GCP Cloud Storage - Application assets bucket
# Creates a GCP Cloud Storage bucket for Service B to store
# and retrieve application assets (files, images, etc.).
# This satisfies the multi-cloud requirement (LO1) by using
# GCP alongside AWS for a real cross-cloud data flow.
# Expect: 1 bucket (Standard class), 1 service account with
#         objectAdmin permissions scoped to this bucket only.
# -------------------------------------------------------

# ==================== Cloud Storage Bucket ====================
# Standard storage class in australia-southeast1 (Sydney).
# force_destroy = true allows terraform destroy to delete even
# if the bucket contains objects.

resource "google_storage_bucket" "app_assets" {
  name          = "${var.project_name}-${var.environment}-assets-${var.gcp_project_id}"
  location      = var.gcp_region
  storage_class = "STANDARD"
  force_destroy = true

  uniform_bucket_level_access = true

  versioning {
    enabled = false
  }

  labels = {
    project     = var.project_name
    environment = var.environment
    managed-by  = "terraform"
  }
}

# ==================== Service Account ====================
# Dedicated service account for Service B to access GCS.
# This key would be injected into the ECS task as a secret
# or mounted via environment variable in production.

resource "google_service_account" "service_b" {
  account_id   = "${var.project_name}-${var.environment}-svc-b"
  display_name = "Service B - GCS Access (${var.environment})"
  project      = var.gcp_project_id
}

# ==================== IAM Binding ====================
# Grants objectAdmin on the bucket only (not project-wide).
# objectAdmin = create, read, update, delete objects.

resource "google_storage_bucket_iam_member" "service_b_admin" {
  bucket = google_storage_bucket.app_assets.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.service_b.email}"
}
