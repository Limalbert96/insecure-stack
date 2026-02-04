# VPC Network Configuration
# This VPC is designed with a hybrid approach:
# - Private subnet for GKE
# - Public subnet for future public-facing resources
# 
# Security Note: For production, consider removing public subnets
# and implementing more stringent network isolation.
resource "google_compute_network" "vpc" {
  name                            = "main"
  routing_mode                    = "REGIONAL"      # Regional routing for better availability
  auto_create_subnetworks         = false           # Manual subnet creation for better control
  delete_default_routes_on_create = true            # Remove default routes for security

  depends_on = [google_project_service.api]
}

# Internet Access Configuration
# Security Anti-Pattern: Default route to internet gateway
# In a production environment, consider:
# 1. Removing this route entirely
# 2. Using Cloud NAT exclusively for private instances
# 3. Implementing more granular routing policies
resource "google_compute_route" "default_route" {
  name             = "default-route"
  dest_range       = "0.0.0.0/0"
  network          = google_compute_network.vpc.name
  next_hop_gateway = "default-internet-gateway"
  
  # Priority can be adjusted to favor other routes
  priority         = 1000
}
