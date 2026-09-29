# Terraform providers for the rj-devsecops-edge-lab.
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }
}

# Backend is intentionally local by default so `terraform validate` works without
# any cloud credentials. Switch to a remote state backend (GCS/Azure) in production.
# backend "gcs" {} / backend "azurerm" {}