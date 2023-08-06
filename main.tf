#Providers
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.68.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Kubernetes Provider Config
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}
resource "azurerm_resource_group" "daevonlab_rg" {
  name     = "daevonlab-resources"
  location = "East US"
  tags = {
    environment = "dev"
  }
}

# Role to allow pull from ACR
resource "azurerm_role_assignment" "aks_acr_pull_role" {
  scope                = azurerm_container_registry.daevonlab-acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

# Build Container Registry
resource "azurerm_container_registry" "daevonlab-acr" {
  name                = "daevonlabacr"
  resource_group_name = azurerm_resource_group.daevonlab_rg.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Kubernetes Cluster

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "daevonlab-aks-cluster"
  location            = var.location
  resource_group_name = azurerm_resource_group.daevonlab_rg.name
  dns_prefix          = "daevonlabaks"
  kubernetes_version  = "1.26"
  node_resource_group = "daevonlab-aks-nodes"
  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
  tags = {
    environment = "dev"
  }
}

# Name Space

resource "kubernetes_namespace" "daevonlab_ns" {
  metadata {
    name = "daevonlab-ns"
  }
}

# Kubernetes Deployments Service

resource "kubernetes_deployment" "daevonlab_website" {
  metadata {
    name      = "daevonlab-website"
    namespace = kubernetes_namespace.daevonlab_ns.metadata[0].name
    labels = {
      app = "daevonlab-website"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "daevonlab-website"
      }
    }

    template {
      metadata {
        labels = {
          app = "daevonlab-website"
        }
      }

      spec {
        container {
          name  = "daevonlab-website"
          image = var.image
          port {
            container_port = var.port
          }
        }
      }
    }
  }
}


resource "kubernetes_service" "daevonlab_website" {
  metadata {
    name      = "daevonlab-website"
    namespace = kubernetes_namespace.daevonlab_ns.metadata[0].name
  }

  spec {
    selector = {
      app = kubernetes_deployment.daevonlab_website.metadata[0].labels.app
    }

    port {
      port        = var.port
      target_port = var.port
    }

    type = "LoadBalancer"
  }
}