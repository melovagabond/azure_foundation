resource "azurerm_public_ip" "daevonlab-public-ip" {
  name                = "daevonlab-public-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
}


resource "azurerm_virtual_network" "daevonlab_vnet" {
  name                = "daevonlab-vnet"
  address_space       = ["10.123.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "daevonlab_public_subnet" {
  name                 = "daevonlab-public-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.daevonlab_vnet.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_route_table" "daevonlab_public_rt" {
  name                = "daevonlab-public-rt"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_route" "default_route" {
  name                = "default-route"
  resource_group_name = var.resource_group_name
  route_table_name    = azurerm_route_table.daevonlab_public_rt.name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "Internet"
}

resource "azurerm_subnet_route_table_association" "daevolab_public_assoc" {
  subnet_id      = azurerm_subnet.daevonlab_public_subnet.id
  route_table_id = azurerm_route_table.daevonlab_public_rt.id
}

resource "azurerm_network_security_group" "daevonlab_nsg" {
  name                = "daevonlab-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Azure Networking
resource "azurerm_network_interface" "daevonlab-nic" {
  name                = "daevonlab-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.daevonlab_public_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}


# Azure Load Balancer

resource "azurerm_lb" "daevonlab-lb" {
  name                = "daevonlab-lb"
  location            = var.location
  resource_group_name = var.resource_group_name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.daevonlab-public-ip.id
  }
}

resource "azurerm_lb_backend_address_pool" "daevonlab-backend-pool" {
  name            = "daevonlab-backend-pool"
  loadbalancer_id = azurerm_lb.daevonlab-lb.id
}

resource "azurerm_lb_probe" "daevonlab-lb-probe" {
  name                = "daevonlab-lb-probe"
  protocol            = "Tcp"
  port                = 443
  interval_in_seconds = 5
  number_of_probes    = 2
  loadbalancer_id     = azurerm_lb.daevonlab-lb.id
}

resource "azurerm_lb_rule" "daevonlab-lb-rule" {
  name                           = "daevonlab-lb-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 443
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.daevonlab-backend-pool.id]
  probe_id                       = azurerm_lb_probe.daevonlab-lb-probe.id
  loadbalancer_id                = azurerm_lb.daevonlab-lb.id
}
