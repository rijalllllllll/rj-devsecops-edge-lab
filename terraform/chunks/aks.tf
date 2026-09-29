# Azure (AKS) variant of the edge-lab cluster + kubernetes workload.
# Comment out the GKE block in main.tf (or keep both as separate workspaces)
# and enable azurerm here for the Azure production path.
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "edge" {
  name     = "rj-edge-lab"
  location = var.location
}

resource "azurerm_kubernetes_cluster" "edge" {
  name                = "rj-edge"
  location            = azurerm_resource_group.edge.location
  resource_group_name = azurerm_resource_group.edge.name
  dns_prefix          = "rjedge"

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }
}

output "aks_kubeconfig_host" {
  value = azurerm_kubernetes_cluster.edge.kube_admin_config.0.host
}