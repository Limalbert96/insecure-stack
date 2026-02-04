# Firewall Configuration

# CRITICAL SECURITY RISKS:
# 1. SSH Access:
#    - Public SSH access (0.0.0.0/0)
#    - No IP allowlisting
#    - No bastion host
#    - No SSH key requirement
# 2. MongoDB Access:
#    - Default port exposed (27017)
#    - No encryption in transit
#    - No authentication requirement
# 3. General:
#    - Overly permissive rules
#    - Missing egress rules
#    - Missing deny rules

# SECURITY RECOMMENDATIONS:
# 1. SSH Access:
#    - Use IAP exclusively
#    - Implement bastion host
#    - Require SSH keys
#    - Enable OS Login
# 2. MongoDB Access:
#    - Use non-default port
#    - Require TLS
#    - Implement authentication
# 3. General:
#    - Implement deny-all default
#    - Add egress rules
#    - Use service accounts

# IAP SSH Access Rule
# SECURITY NOTE: This is the recommended approach
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "allow-iap-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # GOOD PRACTICE: Restricted to IAP source range
  source_ranges = ["35.235.240.0/20"]

  # GOOD PRACTICE: Comprehensive logging
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Direct Internet SSH Access
# CRITICAL SECURITY RISK: Public SSH access
resource "google_compute_firewall" "vmssh" {
  name    = "vm-ssh-from-internet"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # CRITICAL RISK: Allows SSH from anywhere
  source_ranges = ["0.0.0.0/0"]
  # RISK: Only tag-based restriction
  target_tags   = ["mongo-vm"]

  # GOOD PRACTICE: But insufficient given the risks
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# MongoDB Access Rule
# SECURITY RISKS:
# 1. Default port exposed
# 2. No encryption requirement
# 3. No authentication enforcement
resource "google_compute_firewall" "gke_to_mongo" {
  name        = "allow-gke-to-mongo"
  network     = google_compute_network.vpc.name
  description = "Allow GKE pods to access MongoDB"

  allow {
    protocol = "tcp"
    # RISK: Using default MongoDB port
    ports    = ["27017"]
  }

  source_ranges = [google_container_cluster.gke.cluster_ipv4_cidr]
  target_tags   = ["mongo-vm"]

  # Enable logging for MongoDB access
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}


# Allow ICMP (ping) traffic to mongo-vm (intentionally insecure for demo)
resource "google_compute_firewall" "allow_mongo_icmp" {
  name    = "allow-mongo-icmp"
  network = google_compute_network.vpc.name

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"] # Public internet (insecure)
  target_tags   = ["mongo-vm"]

  # Enable logging for ICMP access
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}
