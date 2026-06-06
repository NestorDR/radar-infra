# terraform/providers.tf

# This file contains the Terraform requirements declaration, the cloud providers (required_providers),
#  and the provider configuration (the provider "hcloud" {} blocks).

# Declares the required provider binaries and version boundaries for the execution environment.
terraform {
  required_providers {
    hcloud = {
      # Resolves to the official Hetzner Cloud provider on the default registry.
      # The constraint is set to '~> 1.64.0' to guarantee the presence of fully-stabilized
      # DNS zone and record management resources in our development and production hosts.
      source  = "registry.terraform.io/hetznercloud/hcloud"
      version = "~> 1.64.0"
    }
  }
}

# Configures the active instance of the Hetzner Cloud provider plugin.
# The 'token' attribute authenticates API requests and reads from 'var.hcloud_token',
# which is resolved at runtime from values inside the local unversioned 'terraform.tfvars' file.
provider "hcloud" {
  token = var.hcloud_token
}