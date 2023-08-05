# Display the ip the webpage is hosted on
output "public_ip_address" {
  value = azurerm_public_ip.daevonlab-public-ip.ip_address
}

output "admin_password" {
  value       = azurerm_container_registry.daevonlab-acr.admin_password
  description = "The Ojbect ID of the user"
  sensitive   = true
}

output "admin_username" {
  value       = azurerm_container_registry.daevonlab-acr.admin_username
  description = "The Ojbect ID of the user"
  sensitive   = true
}