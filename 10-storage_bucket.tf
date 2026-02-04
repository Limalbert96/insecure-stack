# MongoDB Backup Storage Configuration

# CRITICAL SECURITY RISKS:
# 1. Data Protection:
#    - No encryption at rest
#    - No object versioning
#    - No retention policy
#    - Force destroy enabled
#    - Multi-regional location (data sovereignty)
# 2. Access Control:
#    - Public read access (allUsers)
#    - No VPC Service Controls
#    - No Object Lifecycle Management
# 3. Backup Security:
#    - Predictable backup schedule
#    - No backup validation
#    - No access logging

# SECURITY RECOMMENDATIONS:
# 1. Data Protection:
#    - Enable Customer-Managed Encryption Keys (CMEK)
#    - Enable object versioning
#    - Set retention policy (min 30 days)
#    - Use regional location
#    - Disable force destroy
# 2. Access Control:
#    - Remove public access
#    - Implement VPC Service Controls
#    - Use signed URLs for temporary access
#    - Enable Object Lifecycle Management
# 3. Backup Security:
#    - Implement random backup schedule
#    - Enable backup validation
#    - Enable access logging

resource "google_storage_bucket" "backup_bucket" {
  name          = "tasky-mongo-backup"
  # SECURITY RISK: Multi-regional location
  # Recommendation: Use specific region for data sovereignty
  location      = "US"  

  # SECURITY RISK: Force destroy enabled
  # Recommendation: Disable in production to prevent accidental deletion
  force_destroy = true

  # GOOD PRACTICE: Uniform bucket-level access
  uniform_bucket_level_access = true

  # MISSING SECURITY FEATURES:
  # 1. Object Versioning
  # versioning {
  #   enabled = true
  # }
  #
  # 2. Customer-Managed Encryption Keys
  # encryption {
  #   default_kms_key_name = "projects/PROJECT_ID/locations/global/keyRings/RING_NAME/cryptoKeys/KEY_NAME"
  # }
  #
  # 3. Retention Policy
  # retention_policy {
  #   retention_period = 2592000 # 30 days minimum
  # }
  #
  # 4. Object Lifecycle Management
  # lifecycle_rule {
  #   condition {
  #     age = 90
  #   }
  #   action {
  #     type = "Delete"
  #   }
  # }

  labels = {
    environment = "demo"
    purpose     = "mongodb-backup"
    security    = "demo-vulnerable"
  }
}

# CRITICAL SECURITY RISK: Public Read Access
# This configuration allows anyone on the internet to:
# 1. List all backup files
# 2. Download any backup file
# 3. Potentially access sensitive data
#
# SECURITY RECOMMENDATIONS:
# 1. Remove public access
# 2. Use signed URLs with short expiration
# 3. Implement proper IAM roles
# 4. Use VPC Service Controls
# 5. Enable audit logging
resource "google_storage_bucket_iam_binding" "public_read" {
  bucket = google_storage_bucket.backup_bucket.name
  # RISK: Public read access to all objects
  role   = "roles/storage.objectViewer"
  # RISK: Allows anonymous access
  members = ["allUsers"]
}
