# MongoDB Service Account and VM Configuration

# CRITICAL SECURITY RISKS:
# 1. Service Account:
#    - Overly permissive compute.admin role
#    - No key rotation policy
#    - No secrets management
# 2. VM Configuration:
#    - Outdated Ubuntu 16.04 from April 2020
#    - Public IP address exposed
#    - Placement in public subnet
#    - Direct internet accessibility
#    - MongoDB 3.6 (EOL)
# 3. Backup Configuration:
#    - Public access to backup bucket
#    - Unencrypted backups
#    - Predictable backup schedule (2 AM daily)

# SECURITY RECOMMENDATIONS:
# 1. Service Account:
#    - Use custom role with minimal permissions
#    - Implement automated key rotation
#    - Use Secret Manager for credentials
# 2. VM Configuration:
#    - Use latest Ubuntu LTS (22.04)
#    - Use latest MongoDB version (7.0)
#    - Place in private subnet only
#    - Use Compute Engine OS Login
#    - Enable Shielded VM features
# 3. Backup Configuration:
#    - Encrypt backups
#    - Use customer-managed encryption keys
#    - Implement random backup schedule
#    - Use private bucket with VPC Service Controls

# Service Account - Intentionally Overprivileged
resource "google_service_account" "vm" {
  account_id   = "demo-vm"
  display_name = "MongoDB VM Service Account"
  description  = "Service account for MongoDB VM (intentionally overprivileged)"
}

# SECURITY RISK: Excessive IAM Permissions
# Recommended roles for production:
# - roles/compute.viewer
# - roles/compute.instanceAdmin.v1
# - roles/storage.objectViewer
resource "google_project_iam_member" "vm_compute" {
  project = local.project_id
  # RISK: Full compute admin access
  role    = "roles/compute.admin"  
  member  = "serviceAccount:${google_service_account.vm.email}"
}

# Storage Permissions for Backups
# SECURITY RISK: No encryption or access controls
resource "google_project_iam_member" "vm_storage" {
  project = local.project_id
  role    = "roles/storage.objectCreator"
  member  = "serviceAccount:${google_service_account.vm.email}"
}

# MongoDB VM Instance
# SECURITY RISKS:
# 1. No OS hardening
# 2. No disk encryption
# 3. No monitoring
# 4. No backup encryption
# 5. No firewall restrictions
resource "google_compute_instance" "mongo_vm" {
  name         = "mongo-vm"
  machine_type = "e2-medium" 
  zone         = "us-central1-a"
  tags         = ["mongo-vm"]

  # Boot Disk Configuration
  # SECURITY RISKS:
  # 1. Outdated OS (Ubuntu 16.04)
  # 2. No disk encryption
  # 3. Balanced disk (slower recovery)
  boot_disk {
    initialize_params {
      image = "ubuntu-1604-xenial-v20200429"  # RISK: Outdated OS from April 2020
      size  = 20  # RISK: Small disk size may lead to DoS
      type  = "pd-standard"  # RISK: Slower disk type
    }
  }

  # Security Anti-Pattern: Public Network Access
  # In production:
  # 1. Place in private subnet
  # 2. Remove access_config (no public IP)
  # 3. Use VPC peering or VPN for access
  network_interface {
    network       = google_compute_network.vpc.self_link
    subnetwork    = google_compute_subnetwork.public.self_link
    access_config {}  # Enable external IP
  }
  
  #Install mongo version 2.6.10 & create 2 users admin (root role) & tasky_user (readWrite role)
  metadata_startup_script = <<-EOT
  #!/bin/bash
  set -e  # Exit on error

  # Configure SSH for password authentication
  sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
  sed -i 's/PubkeyAuthentication yes/PubkeyAuthentication no/g' /etc/ssh/sshd_config
  echo 'ubuntu:password123' | chpasswd
  systemctl restart sshd


  # Add MongoDB repository
  apt-get update
  apt-get install -y gnupg wget
  wget -qO - https://www.mongodb.org/static/pgp/server-3.2.asc | apt-key add -
  echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-3.2.list

  # Update package list
  apt-get update

  # Install MongoDB
  apt-get install -y --allow-unauthenticated mongodb-org

  # Create MongoDB directories
  mkdir -p /var/lib/mongodb
  mkdir -p /var/log/mongodb
  chown -R mongodb:mongodb /var/lib/mongodb
  chown -R mongodb:mongodb /var/log/mongodb
  chmod 755 /var/lib/mongodb
  chmod 755 /var/log/mongodb

  # Configure MongoDB
  PRIVATE_IP=$(hostname -I | cut -d' ' -f1)
  cat > /etc/mongod.conf <<EOF
  systemLog:
    destination: file
    logAppend: true
    path: /var/log/mongodb/mongod.log
  storage:
    dbPath: /var/lib/mongodb
    journal:
      enabled: true
  net:
    port: 27017
    bindIp: 127.0.0.1,$PRIVATE_IP
  security:
    authorization: enabled
  EOF

  # Create systemd service file
  cat > /lib/systemd/system/mongod.service <<'EOF'
  [Unit]
  Description=High-performance, schema-free document-oriented database
  After=network.target

  [Service]
  User=mongodb
  ExecStart=/usr/bin/mongod --quiet --config /etc/mongod.conf

  [Install]
  WantedBy=multi-user.target
  EOF

  # Reload systemd and start MongoDB
  systemctl daemon-reload
  systemctl start mongod
  systemctl enable mongod

  # Wait for MongoDB to start
  sleep 15

  # Create admin user
  mongo admin --eval "db.createUser({user: 'admin', pwd: 'admin123', roles: [{role: 'root', db: 'admin'}]})"

  # Create tasky_user
  mongo admin -u admin -p admin123 --eval "db.getSiblingDB('taskydb').createUser({user: 'tasky_user', pwd: 'tasky123', roles: [{role: 'readWrite', db: 'taskydb'}]})"

  # Add test data
  cat > /tmp/test_data.js <<'EOF'
  db = db.getSiblingDB('taskydb');
  db.auth('tasky_user', 'tasky123');

  db.tasks.insertMany([
    {
      title: 'Complete project documentation',
      description: 'Write comprehensive documentation for the Tasky project',
      status: 'pending',
      priority: 'high',
      dueDate: new Date('2025-05-15'),
      createdAt: new Date()
    },
    {
      title: 'Implement user authentication',
      description: 'Add user authentication and authorization features',
      status: 'in_progress',
      priority: 'high',
      dueDate: new Date('2025-05-20'),
      createdAt: new Date()
    },
    {
      title: 'Design UI mockups',
      description: 'Create UI mockups for the mobile app',
      status: 'completed',
      priority: 'medium',
      dueDate: new Date('2025-05-10'),
      createdAt: new Date()
    }
  ]);
  EOF

  mongo taskydb -u tasky_user -p tasky123 /tmp/test_data.js
  rm /tmp/test_data.js

  # Verify data
  mongo taskydb -u tasky_user -p tasky123 --eval 'db.tasks.find().pretty()'

  # Install Google Cloud SDK
  export DEBIAN_FRONTEND=noninteractive
  curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-467.0.0-linux-x86_64.tar.gz
  tar -xf google-cloud-cli-467.0.0-linux-x86_64.tar.gz
  mv google-cloud-sdk /root/
  /root/google-cloud-sdk/install.sh --quiet
  ln -s /root/google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil

  # Create backup script
  cat > /usr/local/bin/backup-mongodb.sh <<'EOF'
  #!/bin/bash
  set -e

  BACKUP_DIR=/tmp/mongodb_backup
  BUCKET_NAME="tasky-mongo-backup"
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)

  # Create backup directory
  mkdir -p $BACKUP_DIR

  # Dump the database
  mongodump --host localhost --port 27017 -u admin -p admin123 --authenticationDatabase admin --out $BACKUP_DIR

  # Create tarball
  cd $BACKUP_DIR
  tar czf mongodb-backup-$TIMESTAMP.tar.gz *

  # Upload to GCS with public-read ACL
  gsutil cp mongodb-backup-$TIMESTAMP.tar.gz gs://$BUCKET_NAME/

  # Cleanup
  rm -rf $BACKUP_DIR
  EOF

  # Make backup script executable
  chmod +x /usr/local/bin/backup-mongodb.sh

  # Add cron job to run at 5 AM Pacific time (12 PM UTC)
  echo "0 12 * * * root /usr/local/bin/backup-mongodb.sh" > /etc/cron.d/mongodb-backup

  # Perform initial backup
  /usr/local/bin/backup-mongodb.sh

  echo "MongoDB setup complete!"
  EOT

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.vm.email
    scopes = ["cloud-platform"]
  }

}