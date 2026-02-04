# Subnet Configuration
# This setup demonstrates a hybrid network architecture with both public and private subnets

# Public Subnet Configuration
# Security Anti-Pattern: Public subnet allows direct internet access
# In production:
# 1. Consider removing public subnet entirely
# 2. Use Cloud NAT for all outbound traffic
# 3. Implement proper network segmentation
resource "google_compute_subnetwork" "public" {
  name                     = "public"
  ip_cidr_range            = "10.0.0.0/19"      # 8,192 IP addresses
  region                   = local.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true               # Allow private access to Google APIs
  stack_type               = "IPV4_ONLY"        # IPv6 disabled for simplicity

  # Flow logs enabled for network monitoring and security analysis
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Private Subnet Configuration
# This subnet hosts the GKE cluster and its workloads
# Security Note: Good practice to use private subnet for sensitive workloads
resource "google_compute_subnetwork" "private" {
  name                     = "private"
  ip_cidr_range            = "10.0.32.0/19"     # 8,192 IP addresses
  region                   = local.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true               # Allow private access to Google APIs
  stack_type               = "IPV4_ONLY"        # IPv6 disabled for simplicity

  # GKE Pod IP Range
  # Large CIDR for pod IPs (262,144 addresses)
  secondary_ip_range {
    range_name    = "k8s-pods"
    ip_cidr_range = "172.16.0.0/14"    # Allows for future cluster growth
  }

  # GKE Service IP Range
  # Smaller CIDR for service IPs (16,384 addresses)
  secondary_ip_range {
    range_name    = "k8s-services"
    ip_cidr_range = "172.20.0.0/18"    # Sufficient for most use cases
  }

  # Flow logs enabled for network monitoring and security analysis
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}
