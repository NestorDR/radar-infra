# Deployment Roadmap: Radar Production Environment

## Overview
This document outlines the incremental deployment strategy for the Radar project on a single Hetzner Cloud VM. The deployment is divided into two distinct stages to isolate infrastructure complexities and ensure stability.

## Stage 1: Isolation and Validation (Core & Backend)
**Objective:** Verify that the database persists data correctly, `radar-core` executes as scheduled by `systemd`, and Metabase successfully reads and visualizes the data without public exposure.

**Technical Actions:**
1. **Provisioning:** Rent a VM on Hetzner Cloud (CX33 instance, Debian 13).
2. **Hardening:** Configure the firewall (UFW) to allow **ONLY port 22 (TCP/SSH)**.
3. **Initial Deployment:** Deploy the current `docker-compose.prod.yml` (which exposes Metabase strictly on `127.0.0.1:3000:3000`).
4. **Scheduling:** Install the `systemd` `.service` and `.timer` files, enable the timer, and validate execution logs via `journalctl`.
5. **Secure Access:** Access the Metabase UI by establishing an **SSH Tunnel** from the local machine (`ssh -L 3000:localhost:3000 radar-admin@HETZNER_IP`).
6. **Monitoring:** Configure dashboards and let the system run to establish a baseline for container stability and RAM usage patterns.

## Stage 2: Secure Exposure (Network/Frontend Layer)
**Objective:** Introduce a Reverse Proxy (Caddy) and TLS encryption, enabling secure public web access without affecting the internal database state or existing dashboards.

**Technical Actions:**
1. **DNS Configuration:** Purchase a domain and configure the **A Record** to point to the Hetzner VM's public IPv4 address. Wait for global DNS propagation.
2. **Compose Update:** SSH into the server and modify the `docker-compose.prod.yml` to:
   * Remove the `ports` mapping from the `metabase` service.
   * Add the `gateway` (Caddy) service block.
3. **Proxy Setup:** Create the `Caddyfile` on the server with the reverse proxy directives mapping the domain to `metabase:3000`.
4. **Firewall Update:** Open standard web ports on the OS firewall: `sudo ufw allow 80/tcp` and `sudo ufw allow 443/tcp`.
5. **Seamless Redeployment:** Execute `docker compose up -d`. Docker will gracefully restart Metabase and boot up Caddy, transitioning the architecture from private to public with automatic HTTPS via Let's Encrypt.