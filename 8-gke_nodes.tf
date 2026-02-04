# GKE Node Service Account Configuration
# Security Anti-Pattern: Minimal service account configuration
# In production:
# 1. Add workload identity configuration
# 2. Implement proper RBAC
# 3. Use minimal IAM roles
resource "google_service_account" "gke" {
  account_id   = "demo-gke"
  display_name = "GKE Node Service Account"
  description  = "Service account for GKE nodes (intentionally basic config)"
}

# Basic monitoring permissions
# These are actually reasonable minimal permissions
resource "google_project_iam_member" "gke_logging" {
  project = local.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke.email}"
}

resource "google_project_iam_member" "gke_metrics" {
  project = local.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke.email}"
}

# GKE Node Pool Configuration
# Security Anti-Patterns:
# 1. Full cloud-platform OAuth scope
# 2. No security policies
# 3. No node pool taints
# 4. Default container-optimized OS
resource "google_container_node_pool" "general" {
  name       = "general"
  cluster    = google_container_cluster.gke.id
  location   = "us-central1-a"  # Single-zone for demo

  # Basic autoscaling configuration
  autoscaling {
    total_min_node_count = 1
    total_max_node_count = 5
  }

  # Node management configuration
  # These are good practices:
  management {
    auto_repair  = true     # Automatically repair unhealthy nodes
    auto_upgrade = true     # Keep nodes up to date
  }

  # Node configuration
  # Security Anti-Patterns:
  # 1. Missing security policies
  # 2. Missing node taints (allows a node to refuse a pod to be scheduled unless that pod has a matching toleration
  # 3. Overly permissive OAuth scopes
  node_config {
    preemptible  = false
    machine_type = "e2-standard-2"  # upgrade for production

    labels = {
      role = "general"
    }

    # Security Enhancement: Add node taints
    # Uncomment for production:
    # taint {
    #   key    = "security-level"
    #   value  = "high"
    #   effect = "NO_SCHEDULE"
    # }

    service_account = google_service_account.gke.email
    
    # Security Anti-Pattern: Overly permissive OAuth scope
    # In production, use specific scopes like:
    # - storage-ro
    # - logging-write
    # - monitoring
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"  # Full access to all GCP services
    ]
  }
}

