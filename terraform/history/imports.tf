# terraform/imports.tf

# Defines the declarative import blocks to map pre-existing cloud infrastructure resources into the Terraform state file.
# This synchronization prevents creation conflicts during the apply phase
#  and brings console-managed resources under strict IaC lifecycle control.

# NOTE: This migration/import file acts as a one-shot operation to sync pre-existing cloud state.
# Post-apply, it should be removed or disabled (e.g., by changing its extension or archiving it)
# to prevent configuration clutter, reduce cognitive overhead, and avoid accidental state drift.

# Imports the existing authoritative primary DNS Zone managed under the Hetzner Cloud account.
# The 'to' argument targets the local logical resource (*.tf files), and the 'id'
# corresponds to the actual domain name of the pre-existing zone now located in the active Hetzner Project.
#
# CRITICAL: This import block requires a matching 'resource "hcloud_zone" "domain_zone"'
# block to be declared in the configuration files (e.g., main.tf) to act as the target destination.
import {
  to = hcloud_zone.domain_zone
  id = var.domain_name
}

# Fetches the pre-existing root (@) A-record from the Hetzner DNS zone and binds it through the 'to' argument
# to the local Terraform state file (terraform.tfstate file).
#
# CRITICAL: This import block requires a matching 'resource "hcloud_zone_rrset" "root"'
# block to be declared in the configuration files (e.g., main.tf) to act as the target destination.
#
# The identifier format maps to "zone_name/record_name/record_type" as mandated by the provider's specification/plugin.
import {
  to = hcloud_zone_rrset.root
  id = "${var.domain_name}/@/A"
}
