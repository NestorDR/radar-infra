# terraform/main.tf

# This file contains the declaration of the actual infrastructure resources to be provisioned (resource {} blocks).

# Creates the authoritative logical DNS Zone matching the domain name.
# This serves as the parent container and administrative boundary for all records.
# TTL (3600 seconds) dictates the cache expiration limit for downstream/recursive resolvers.
# 'mode' represents the operational mode of the zone ("dns" for standard public resolution).
resource "hcloud_zone" "domain_zone" {
  name = var.domain_name
  ttl  = 3600
  mode = "primary"
}

# Root record (@) pointing to the shared web hosting provider (for the main www website).
# Resolved implicitly by mapping its 'zone' to the domain name attribute (.name) of 'hcloud_zone.domain_zone'.
# Utilizing the domain name rather than the numeric ID prevents forced resource replacement (destroy and recreate)
#  during state imports.
# The 'records' argument expects a list of structured record objects as mandated by the provider's RRSet schema.
resource "hcloud_zone_rrset" "root" {
  zone = hcloud_zone.domain_zone.name
  type = "A"
  name = "@"
  ttl  = 3600

  records = [
    {
      value   = var.webhosting_ip
      comment = "Shared webhosting server for static website"
    }
  ]
}

# WWW CNAME (Canonical Name, Alias) record pointing to the root domain for canonical routing.
# Inherits the zone reference dynamically from the domain name attribute (.name) of 'hcloud_zone.domain_zone'.
resource "hcloud_zone_rrset" "www" {
  zone = hcloud_zone.domain_zone.name
  type = "CNAME"
  name = "www"
  ttl  = 3600

  records = [
    {
      value   = "${var.domain_name}."
      comment = "Canonical alias pointing back to the root domain"
    }
  ]
}

# Subdomain dedicated to the secure exposure of the Metabase application on the VPS (IPv4).
# Inherits the zone reference dynamically from the domain name attribute (.name) of 'hcloud_zone.domain_zone'.
# Routes traffic directly to the public IPv4 of the Hetzner VPS instance.
resource "hcloud_zone_rrset" "radar" {
  zone = hcloud_zone.domain_zone.name
  type = "A"
  name = "radar"
  ttl  = 3600

  records = [
    {
      value   = var.vps_ip
      comment = "Public IPv4 route of the Hetzner VPS instance running Caddy"
    }
  ]
}

# Subdomain dedicated to the secure exposure of the Metabase application on the VPS (IPv6).
# Inherits the zone reference dynamically from the domain name attribute (.name) of 'hcloud_zone.domain_zone'.
# Routes IPv6 traffic directly to the public IPv6 of the Hetzner VPS instance, enabling Dual-Stack.
resource "hcloud_zone_rrset" "radar_ipv6" {
  zone = hcloud_zone.domain_zone.name
  type = "AAAA"
  name = "radar"
  ttl  = 3600

  records = [
    {
      value   = var.vps_ipv6
      comment = "Public IPv6 route of the Hetzner VPS instance running Caddy for Dual-Stack"
    }
  ]
}
