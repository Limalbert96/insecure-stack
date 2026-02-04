# Setup k8s secret for ghcr image
resource "kubernetes_secret" "ghcr_secret" {
  metadata {
    name = "ghcr-secret"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "ghcr.io" = {
          auth = base64encode("${local.github_config.username}:${local.github_config.pat}")
        }
      }
    })
  }
}

# Create ConfigMap for MongoDB connection to retrieve host name
resource "kubernetes_config_map" "mongo_config" {
  metadata {
    name = "mongo-config"
  }

  data = {
    MONGODB_HOST = google_compute_instance.mongo_vm.network_interface[0].network_ip
  }
}

# Create Secret for MongoDB credentials
resource "kubernetes_secret" "mongo_creds" {
  metadata {
    name = "mongo-creds"
  }

  data = {
    MONGODB_USER = "tasky_user"
    MONGODB_PASSWORD = "tasky123"
    MONGODB_DATABASE = "taskydb"
  }
}

# Deploy k8s-deployment.yaml
resource "null_resource" "deploy_tasky" {
  depends_on = [
    google_container_cluster.gke,
    kubernetes_config_map.mongo_config,
    kubernetes_secret.mongo_creds
  ]

  triggers = {
    config_map_version = kubernetes_config_map.mongo_config.metadata[0].resource_version
    secret_version = kubernetes_secret.mongo_creds.metadata[0].resource_version
  }

  # SSH to the cluster and run deployment file
  provisioner "local-exec" {
    command = <<-EOT
      gcloud container clusters get-credentials demo --zone us-central1-a
      kubectl apply -f tasky/k8s-deployment.yaml
    EOT
    working_dir = path.module
  }
}
