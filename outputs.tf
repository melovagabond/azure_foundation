# Display the ip the webpage is hosted 
output "load_balancer_ip" {
  value = kubernetes_service.daevonlab_website.status[0].load_balancer[0].ingress[0].ip
}
