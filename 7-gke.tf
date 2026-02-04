# GKE Cluster Configuration
# SECURITY RISKS:
# 1. Deletion protection disabled
# 2. Private endpoint access disabled
# 3. Missing master authorized networks
# 4. Missing pod security policies
# 5. Missing network policies
# 6. Missing binary authorization
# 7. Missing node integrity monitoring

resource "google_container_cluster" "gke" {
  name                     = "demo"
  location                 = "us-central1-a"
  remove_default_node_pool = true
  initial_node_count       = 1
  network                  = google_compute_network.vpc.self_link
  subnetwork               = google_compute_subnetwork.private.self_link
  networking_mode          = "VPC_NATIVE"

  # SECURITY RISK: Deletion protection disabled
  # RECOMMENDATION: Enable in production
  deletion_protection = false

  # RECOMMENDATION: Enable multi-zone for high availability
  # node_locations = ["us-central1-b"]

  # SECURITY RISK: HTTP load balancing enabled without TLS
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    # MISSING SECURITY FEATURES:
    # - Network policy (recommended)
    # - Pod security policy (recommended)
    # - Binary authorization (recommended)
  }

  # RECOMMENDATION: Use STABLE channel for production
  release_channel {
    channel = "REGULAR"
  }

  # Workload Identity Configuration
  # SECURITY NOTE: Good practice, but ensure proper IAM bindings
  workload_identity_config {
    workload_pool = "${local.project_id}.svc.id.goog"
  }

  # Audit Logging Configuration
  # SECURITY NOTE: Comprehensive logging enabled (good practice)
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "APISERVER", "CONTROLLER_MANAGER", "SCHEDULER", "WORKLOADS"]
  }

  # Pod IP Allocation Configuration
  # SECURITY NOTE: Using dedicated CIDR ranges (good practice)
  ip_allocation_policy {
    cluster_secondary_range_name  = "k8s-pods"
    services_secondary_range_name = "k8s-services"
  }

  # Private Cluster Configuration
  # SECURITY RISKS:
  # 1. Public endpoint enabled (enable_private_endpoint = false)
  # 2. No master authorized networks configured
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false  # RISK: Allows public access to master
    master_ipv4_cidr_block  = "192.168.0.0/28"
  }

  # Jenkins use case
  # master_authorized_networks_config {
  #   cidr_blocks {
  #     cidr_block   = "10.0.0.0/18"
  #     display_name = "private-subnet"
  #   }
  # }
}
