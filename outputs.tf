# Display the ip the webpage is hosted on
output "public_ip_address" {
  value = azurerm_public_ip.daevonlab_public_ip.ip_address
}