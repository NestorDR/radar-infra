# Deployment Roadmap: Radar Production Environment

## Overview
This document outlines the incremental deployment strategy for the Radar project on a single Hetzner Cloud VM. The deployment is divided into two distinct stages to isolate infrastructure complexities and ensure stability.

---

## Stage 1: Isolation and Validation (Core & Backend)
**Objective:** Verify that the database persists data correctly, `radar-core` executes as scheduled by `systemd`, and Metabase successfully reads and visualizes the data without public exposure.

**Technical Actions:**
1. **Provisioning:** Create a VM on Hetzner Cloud (CX33 instance, Debian 13).
2. **Hardening:** Configure the firewall (UFW) to allow **ONLY port 22 (TCP/SSH)**.
3. **Docker:** Install it and prepare the directory structure.
4. **Deployment:** Upload files (`docker-compose.prod.yml` and relates) and deploy.
5. **Scheduling:** Set up the `systemd` (`.service` and `.timer` files) enable the timer, and validate execution logs via `journalctl`.
6**Secure Access:** Access the PostgreSQL and Metabase by establishing an **SSH Tunnel** from the local machine.
7**Monitoring:** Set up the correct PostgreSQL connection in Metabase.

---

## Stage 2: Secure Exposure (Network/Frontend Layer)
**Objective:** Introduce a Reverse Proxy (Caddy) and TLS encryption, enabling secure public web access without affecting the internal database state or existing dashboards, managing the DNS layer with Terraform to have a declarative and reproducible process.

**Technical Actions:**
1. Buy domain
2. **DNS Configuration with Terraform (IaC):**
   * Create a `terraform/` directory in the project root to host the configuration.
   * Configure the `providers.tf`, `variables.tf`, and `main.tf` files using the official [hetznercloud/hcloud](https://registry.terraform.io/providers/hetznercloud/hcloud/latest) provider to configure the DNS zone for `ndromero.com`.
   * Declare the **A Record** for the `radar.ndromero.com` subdomain, pointing dynamically to the Hetzner VM's public IPv4 address.
   * Declare the **AAAA Record** for the `radar.ndromero.com` subdomain, pointing dynamically to the Hetzner VM's public IPv6 address.
   * Initialize and apply the resources: execute `terraform init`, `terraform plan` and `terraform apply` from the local workstation.
3. **Compose Update:** SSH into the server and modify the `docker-compose.prod.yml` to:
   * Remove the `ports` mapping from the `metabase` service.
   * Add the `gateway` (Caddy) service block.
4. *Proxy Setup:** Create the `Caddyfile` on the server with the reverse proxy directives mapping the domain to `metabase:3000`.
5. **Firewall Update:** Open standard web ports on the OS firewall: `sudo ufw allow 80/tcp` and `sudo ufw allow 443/tcp`.
6. **Seamless Redeployment:** Execute `docker compose up -d`. Docker will gracefully restart Metabase and boot up Caddy, transitioning the architecture from private to public with automatic HTTPS via Let's Encrypt.