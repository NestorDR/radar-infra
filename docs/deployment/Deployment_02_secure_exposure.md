# Deployment on Hetzner Cloud: Step-by-Step Guide

## Stage 2: Secure Exposure (Network/Frontend Layer)

**Objective:** Introduce a Reverse Proxy (Caddy) and TLS encryption, enabling secure public web access without affecting the internal database state or existing dashboards, managing the DNS layer with Terraform to have a declarative and reproducible process.

### 1. DNS Configuration with Terraform (IaC)

#### 1.1. Architectural Alignment
The work was focused on the secure and decoupled isolation of workloads and authoritative DNS routing:
- **Root Domain & WWW Subdomain:** Dedicated exclusively to the static, shared web hosting server (representing the primary static web assets) to completely decouple static content delivery from active application systems.
- **Application Subdomain:** Configured as the secure gateway to resolve directly to the public Dual-Stack (IPv4/IPv6) interfaces of our virtual private server (VPS).
- **Reverse Proxy Strategy:** Addressed the requirements to introduce an edge gateway (Caddy) on the VPS, removing internal service ports from host loopback exposure and ensuring the proxy terminates SSL/TLS on standard web ports (`80/443`) before routing internal traffic over the secure Docker bridge network.

#### 1.2. Declarative DNS with Terraform (IaC)
To guarantee idempotency and follow Infrastructure as Code (IaC) best practices, was designed a modular, parameter-driven Terraform configuration organized into three decoupled files in the `terraform/` folder:
- **`providers.tf`:** Isolates the active instance of the cloud provider plugin [hetznercloud/hcloud](https://registry.terraform.io/providers/hetznercloud/hcloud/latest). and establishes the minimum version constraints (targeting version `~> 1.64.0` or higher to leverage unified compute and DNS API management).
- **`variables.tf`:** Explicitly defines the input variable schemas and types. All sensitive values (API tokens, domain names, and public IPs) are resolved at runtime via an unversioned, git-ignored `terraform.tfvars` file, preventing credential exposure in public repositories.
- **`main.tf`:** Contains the logical declarations for the primary DNS zone and its respective record sets (`hcloud_zone_rrset`). 
- **Strict Syntax & State Alignment:** 
  - Aligned our zone creation with the provider's API constraints by defining `mode = "primary"`.
  - Configured all record set resources to map their `zone` attribute dynamically to the zone's `.name` property rather than its numeric `.id`. This ensures perfect alignment with the declarative import identifier format, preventing forced resource replacement and avoiding downtime for pre-existing services.
  - Standardized the `www` record as a clean CNAME alias pointing back to the root domain to simplify downstream record management.

#### 1.3. Automation and Local Workspace Hardening
- **Local Cache Exclusions:** Optimized and verified the `.gitignore` file to securely block Terraform's local binary directories (`.terraform/`), variables (`*.tfvars`), and sensitive state metadata (`*.tfstate` and `*.tfstate.backup`) from entering version control.
- **Dependency Lock File:** Committed the `.terraform.lock.hcl` file to the repository as recommended by HashiCorp to guarantee that any future initialization on development hosts or production servers downloads identical, verified provider binaries.
- **Template Provisioning:** Formulated a clean, versioned `terraform.tfvars.template` to serve as a secure bootstrap reference for future environment builds.
- **Command Orchestration Script (`auto/tf.cmd`):** Created a unified Windows batch wrapper to automate the Terraform lifecycle. This script handles automatic directory navigation, enforces delayed environment expansion, and introduces pre-calculated execution plans (`terraform plan -out=tfplan` and `terraform apply tfplan`) to prevent state drift during deployment sequences.

#### 1.4. State Synchronization & Import Phase
To bring the pre-existing, console-managed DNS infrastructure under declarative IaC control without service disruption, was executed a non-destructive state synchronization:
- **Declarative Import Block Execution:** was used a temporary `imports.tf` file to map the existing authoritative root zone and the active root (`@`) A/AAAA-records directly into the local `terraform.tfstate` database.
- **Graceful Transition of Subdomains:** The legacy A/AAAA records for the `www` subdomain were removed from the web console and replaced seamlessly with a declarative CNAME record, while the new Dual-Stack records (A/AAAA) for the application subdomain were safely provisioned.
- **Historical Traceability:** Once the initial import and deployment successfully completed with zero downtime, the temporary `imports.tf` file was moved to a designated `history/` subdirectory to maintain a clean root workspace while preserving a historical audit trail of our technical actions.

### 2. Reverse Proxy & Gateway Configuration with Caddy

To transition the containerized stack from loopback host access to a secure, public HTTPS gateway, was integrated Caddy as the edge reverse proxy. The deployment conforms to the following engineering decisions.

#### 2.1. Service Hardening & Network Isolation
The host port mapping (`127.0.0.1:3000`) was removed (commented) from the `metabase` service definition. The application is now fully isolated within the internal `radar-network` bridge, accessible exclusively through the proxy, minimizing the host's direct attack surface.

#### 2.2. Docker Container Configuration
- **Deterministic Docker Image Selection:** Was pinned the image tag to **`caddy:2-alpine`** to ensure reproducible builds across deployments. The Alpine-based distribution reduces the image footprint and decreases the container OS attack surface compared to standard Debian-based alternatives.
- **Hybrid Volume Persistence Strategy:** To resolve container write-permission collisions and safeguard critical cryptographic state, was implemented a hybrid volume strategy:
  - **Docker Bind Mount (`./Caddyfile`):** Mounted as Read-Only (`:ro`) to feed the static, declarative configuration from the host directly into the container.
  - **Docker Named Volumes (`radar-caddy-data` and `radar-caddy-config`):** Configured to manage `/data` and `/config` state. Persisting the `/data` directory is operationally critical as it stores SSL/TLS certificates and ACME private keys, preventing excessive duplicate certificate request queries that would trigger Let's Encrypt / ZeroSSL rate-limiting caps.
 
#### 2.3. Dynamic Configuration & Sanitized IaC
To avoid exposing sensitive metrics (such as the administrator's email or the active subdomain) in public repositories, was leveraged Caddy’s native environment variable interpolation. The `Caddyfile` utilizes `{$ADMIN_EMAIL}` and `{$WEB_SITE_ADDRESS}` dynamically resolved at container initialization from the local, unversioned `envs/.env.prod` file.

#### 2.4. Granular Database Backups
To support operational disaster recovery, we replaced generic database cluster backups with a multi-database script (`dump_postgres_db.sh`). Using `pg_dump` against explicit targets, this utility allows independent, granular backups of the `radar` and `metabase` databases, preventing empty schema outputs while preserving the independent lifecycles of the calculation and visualization layers.
