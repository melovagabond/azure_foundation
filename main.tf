#Providers
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "daevonlab-rg" {
  name     = "daevonlab-resources"
  location = "East US"
  tags = {
    environment = "dev"
  }
}

# User Identity Assignment

data "azurerm_user_assigned_identity" "daevonlab_acr_pull" {
  provider = azurerm.acr_sub
  name = "USER_ACR_PULL"
  resource_group_name = var.resource_group_name
  
}

# Container Build
resource "azurerm_container_registry" "daevonlab-acr" {
  name                = "daevonlabacr"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
}

resource "null_resource" "daevonlab-build" {
  depends_on = [azurerm_container_registry.daevonlab-acr]

  provisioner "local-exec" {
    command     = "sudo az acr build --registry ${azurerm_container_registry.daevonlab-acr.login_server} --file Dockerfile ."
    working_dir = "./docker"
    interpreter = ["/bin/bash", "-c"]
    environment = {
      "DOCKER_BUILDKIT" = "1"
    }
  }
}

# Nginx Container Details
resource "azurerm_container_group" "daevonlab-container-group" {
  name                = "daevonlab-container-group"
  location            = var.location
  resource_group_name = var.resource_group_name

  image_registry_credential {
    username = "$(terraform output -raw admin_username)"
    password = "$(terraform output -raw admin_password)"
    server   = "daevonlabacr.azurecr.io"

  }

  container {
    name   = "nginx-container"
    image  = var.imagebuild
    cpu    = "0.5"
    memory = "1.5"
    ports {
      port     = 443
      protocol = "TCP"
    }
  }

  os_type = "Linux"

  tags = {
    environment = "dev"
  }
}

