# ---- Inputs ----
variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment (dev/staging/prod)."
}

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "GCP region (GKE)."
}

variable "project_id" {
  type        = string
  default     = "rj-edge-lab"
  description = "GCP project ID."
}

variable "location" {
  type        = string
  default     = "southeastasia"
  description = "Azure region (AKS)."
}

variable "image_tag" {
  type        = string
  default     = "latest"
  description = "Container image tag to deploy."
}

variable "kubeconfig" {
  type        = string
  default     = ""
  description = "Path to a kubeconfig for the kubernetes provider (ops/CI only; empty default validates locally)."
}