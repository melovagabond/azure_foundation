# Container Build
resource "azurerm_container_registry" "daevonlab-acr" {
  name                = "daevonlabacr"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
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

  container {
    name   = "nginx-container"
    image  = "${azurerm_container_registry.daevonlab-acr.login_server}/nginx:latest"
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

