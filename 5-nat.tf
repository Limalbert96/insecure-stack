# NAT Gateway Configuration
# This setup enables private instances to access the internet
# while maintaining security by preventing direct inbound access

# Static IP for NAT Gateway
# Security Note: Using a static IP makes it easier to configure
# outbound firewall rules at the destination
resource "google_compute_address" "nat" {
  name         = "nat"
  address_type = "EXTERNAL"          # Required for internet access
  network_tier = "PREMIUM"          # Better performance, higher cost

  depends_on = [google_project_service.api]
}

# Cloud Router Configuration
# Required for Cloud NAT - handles dynamic routing updates
# and enables NAT gateway functionality
resource "google_compute_router" "router" {
  name    = "router"
  region  = local.region
  network = google_compute_network.vpc.id

}

# Cloud NAT Configuration
# Enables private instances to access the internet while
# maintaining security by preventing inbound access
resource "google_compute_router_nat" "nat" {
  name   = "nat"
  region = local.region
  router = google_compute_router.router.name

  # Security Note: Using manual IP allocation for better control
  # and easier audit logging of outbound traffic
  nat_ip_allocate_option             = "MANUAL_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"  # More restrictive than ALL_SUBNETWORKS
  nat_ips                            = [google_compute_address.nat.self_link]

  # Configure NAT for private subnet only
  subnetwork {
    name                    = google_compute_subnetwork.private.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]  # Could be more restrictive in production
  }

  # Enable comprehensive NAT logging for security monitoring
  log_config {
    enable = true
    filter = "ALL"  # Log both errors and translations
  }

  # Production Enhancements:
  # 1. Add minimum_ports_per_vm for better performance
  # 2. Configure tcp_established_idle_timeout
  # 3. Add backup NAT IPs for high availability
}
