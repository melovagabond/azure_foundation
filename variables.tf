variable "resource_group_name" {
  type    = string
  default = "daevonlab-resources"
}

variable "location" {
  type    = string
  default = "East US"
}

variable "bck_address_pool" {
  type    = string
  default = "daevonlab-backend-pool"
}

variable "a_nic" {
  type    = string
  default = "daevonlab-nic"
}

variable "container_group" {
  type    = string
  default = "daevonlab-container-group"
}

variable "imagebuild" {
  description = "Repository"
  default     = "daevonlabacr.azurecr.io/my_nginx:latest"
}