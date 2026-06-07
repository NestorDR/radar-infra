# terraform/variables.tf

# This file contains the definitions of the input variable schemas and types (variable {} blocks).
# Values are injected automatically at execution time from 'terraform.tfvars'.

variable "hcloud_token" {
  type        = string
  description = "Hetzner Cloud API Token used for authentication"
  sensitive   = true
}

variable "domain_name" {
  type        = string
  description = "Base domain name for the infrastructure"
}

variable "webhosting_ip" {
  type        = string
  description = "Public IP address of the shared web hosting provider"
}

variable "webhosting_ipv6" {
  type        = string
  description = "Public IPv6 address of the shared web hosting provider for Dual-Stack routing"
}

variable "vps_ip" {
  type        = string
  description = "Public IP address of the Hetzner VPS instance"
}

variable "vps_ipv6" {
  type        = string
  description = "Public IPv6 address of the Hetzner VPS instance for Dual-Stack routing"
}