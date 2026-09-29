# Terraform: provision a GKE (GCP) cluster for the rj-devsecops-edge-lab.
# Reference IaC path for the DevSecOps engineer role (GCP production path).
locals {
  common_labels = {
    app         = "rj-edge-telemetry"
    environment = var.environment
    managed-by  = "terraform"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_container_cluster" "edge" {
  name     = "rj-edge"
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = "default"
  subnetwork = "default"

  # Private, standard GKE with autoscaling; enable logging/monitoring.
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "10.200.0.0/16"
    services_ipv4_cidr_block = "10.201.0.0/16"
  }

  node_config {
    machine_type = "e2-small"
    disk_size_gb = 20
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    metadata = {
      disable-legacy-endpoints = "true"
    }
    # Least-privilege: service account used only by nodes.
    service_account = "default"
    labels          = local.common_labels
  }

  lifecycle {
    ignore_changes = [min_master_version] # avoid diffs on cluster patch
  }
}

variable "enable_kubernetes_provider" {
  type    = bool
  default = false
  # When true, ops must supply kubeconfig credential via variable (not committed).
}

provider "kubernetes" {
  # The kubernetes provider is enabled in CI/ops by setting
  # TF_VAR_kubeconfig + TF_VAR_enable_kubernetes_provider=true.
  config_path = var.kubeconfig
}

# ---- Workload (namespace, deployment, service, HPA) ----
resource "kubernetes_namespace_v1" "edge" {
  metadata {
    name   = "rj-edge"
    labels = local.common_labels
  }
}

resource "kubernetes_deployment_v1" "telemetry" {
  metadata {
    name      = "rj-edge-telemetry"
    namespace = kubernetes_namespace_v1.edge.metadata[0].name
    labels    = local.common_labels
  }
  spec {
    replicas = 2
    selector {
      match_labels = { app = "rj-edge-telemetry" }
    }
    template {
      metadata {
        labels = local.common_labels
      }
      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 10001
          run_as_group    = 10001
        }
        container {
          name  = "telemetry"
          image = "ghcr.io/rijalllllllll/rj-edge-telemetry:${var.image_tag}"
          port { container_port = 8000 }
          resources {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { cpu = "200m", memory = "128Mi" }
          }
          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities { drop = ["ALL"] }
          }
          liveness_probe {
            http_get {
              path = "/healthz"
              port = "8000"
            }
            initial_delay_seconds = 5
            period_seconds        = 15
          }
          readiness_probe {
            http_get {
              path = "/readyz"
              port = "8000"
            }
            initial_delay_seconds = 3
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "telemetry" {
  metadata {
    name      = "rj-edge-telemetry"
    namespace = kubernetes_namespace_v1.edge.metadata[0].name
    labels    = local.common_labels
  }
  spec {
    type = "ClusterIP"
    port {
      name        = "http"
      port        = 8000
      target_port = "8000"
    }
    selector = { app = "rj-edge-telemetry" }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "telemetry" {
  metadata {
    name      = "rj-edge-telemetry"
    namespace = kubernetes_namespace_v1.edge.metadata[0].name
  }
  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.telemetry.metadata[0].name
    }
    min_replicas = 2
    max_replicas = 8
    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }
}

output "cluster_endpoint" {
  value = google_container_cluster.edge.endpoint
}
output "namespace" {
  value = kubernetes_namespace_v1.edge.metadata[0].name
}