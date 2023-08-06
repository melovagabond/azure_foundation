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

# Linux Vm

resource "azurerm_linux_virtual_machine" "daevonlab-vm" {
  name                  = "daevonlab-vm"
  resource_group_name   = azurerm_resource_group.daevonlab_rg.name
  location              = var.location
  size                  = "Standard_B1s"
  computer_name         = "daevonlab-vm"
  admin_username        = "dae"
  network_interface_ids = [azurerm_network_interface.daevonlab_nic.id]

  custom_data = filebase64("bootstrap.tpl")

  admin_ssh_key {
    username   = "dae"
    public_key = file("~/.ssh/daevonlabazurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

}