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

# Networking

resource "azurerm_virtual_network" "daevonlab_vnet" {
  name                = "daevonlab-vnet"
  address_space       = ["10.123.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.daevonlab_rg.name

  tags = {
    environment = "dev"
  }
}

resource "azurerm_subnet" "daevonlab_public_subnet" {
  name                 = "daevonlab-public-subnet"
  resource_group_name  = azurerm_resource_group.daevonlab_rg.name
  virtual_network_name = azurerm_virtual_network.daevonlab_vnet.name
  address_prefixes     = ["10.123.1.0/24"]
}

# Security Group
resource "azurerm_network_security_group" "daevonlab_nsg" {
  name                = "daevonlab-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.daevonlab_rg.name

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_rule" "daevonlab_dev_rule" {
  name                        = "daevonlab-dev-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.daevonlab_rg.name
  network_security_group_name = azurerm_network_security_group.daevonlab_nsg.name
}
resource "azurerm_subnet_network_security_group_association" "daevonlab_sga" {
  subnet_id                 = azurerm_subnet.daevonlab_public_subnet.id
  network_security_group_id = azurerm_network_security_group.daevonlab_nsg.id

}

resource "azurerm_public_ip" "daevonlab_public_ip" {
  name                = "daevonlab_ip"
  resource_group_name = azurerm_resource_group.daevonlab_rg.name
  location            = var.location
  allocation_method   = "Dynamic"
  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "daevonlab_nic" {
  name                = "daevonlab_nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.daevonlab_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.daevonlab_public_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.daevonlab_public_ip.id
  }

  tags = {
    environment = "dev"
  }
}

# Build Container Registry
resource "azurerm_container_registry" "daevonlab-acr" {
  name                = "daevonlabacr"
  resource_group_name = azurerm_resource_group.daevonlab_rg.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Build Docker image
resource "null_resource" "daevonlab-build" {

  depends_on = [azurerm_container_registry.daevonlab-acr]
  provisioner "local-exec" {
    command     = "az acr build --registry ${azurerm_container_registry.daevonlab-acr.login_server} --image mywebsite:latest --file ./Dockerfile ."
    interpreter = ["/bin/bash", "-c"]
    environment = {
      "DOCKER_BUILDKIT" = "1"
    }
    working_dir = "./docker"
  }
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
    node_count = 3
    vm_size    = "standard_D2_v2"
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
          image = "daevonlabacr.azurecr.io/mywebsite:latest"
          port {
            container_port = 80
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
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

# Data block to get LoadBalancer IP address
data "external" "get_load_balancer_ip" {
  depends_on = [kubernetes_service.daevonlab_website]
  program    = ["sh", "-c", "kubectl get services daevonlab-website -n daevonlab-ns -o json | jq -r '.status.loadBalancer.ingress[0].ip'"]
}
