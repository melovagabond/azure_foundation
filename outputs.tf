# Display the ip the webpage is hosted on
output "website_ip" {
  value = data.external.get_load_balancer_ip.result
}