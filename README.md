# Radar Infra — Infrastructure and Deployment

Radar Infra is the infrastructure companion to the [Radar Core](https://github.com/NestorDR/radar-core) project. It provides the necessary tools, databases, environments, and deployment configurations to run the Financial Strategy Analyzer efficiently across development, testing, and production environments.

## Features
- **Database Provisioning**: Automated initialization scripts (`.sql` and `.sh`) for PostgreSQL, including schema creation, views, and Metabase restoration.
- **Environment Management**: Templated environment variables for Development (`dev`), End-to-End testing (`e2e`), and Production (`prod`).
- **Container Orchestration**: Docker Compose configurations tailored for different stages (`docker-compose.dev.yml`, `docker-compose.e2e.yml`, `docker-compose.prod.yml`).
- **Automation Scripts**: Helper scripts (`auto/dc.cmd`, `auto/dump_mb_db.cmd`) to streamline Docker operations and database backups, along with Bash scripts for automated provisioning and deployment on Linux servers.
- **Architectural Decision Records (ADRs)**: Documentation of key infrastructure decisions, such as deployment scheduling.

## Repository Structure & Version Control
The repository is structured to separate code and configuration from ephemeral or sensitive data:

**Included in version control:**
- `auto/`: Automation and helper scripts for Windows.
- `database/init/`: Database schemas, initialization scripts, and Metabase patches.
- `envs/`: Environment templates (`*.template`).
- `docs/`: ADRs and infrastructure documentation.
- `docker-compose.*.yml`: Environment-specific container definitions.
- `scripts/`: Bash scripts (`.sh`) for automation on Linux servers (cleanup, configuration, execution, and validation).
- `systemd/`: Service units and timers (`radar-core.service`, `radar-core.timer`) for orchestrating recurring executions.

## Prerequisites
- Docker Engine & Docker Compose.
- Windows Command Prompt (for `auto/*.cmd` scripts) or a compatible shell.
- The `radar-core` repository (for full end-to-end integration).

## Quick Start
1. **Set up Environments**:
   Copy the templates in the `envs/` directory to create your local active environment files.
   ```shell
   copy envs\.env.dev.template envs\.env.dev
   ```
   *Edit `.env.dev` to include your specific local credentials.*

2. **Start the Infrastructure (Development)**:
   Use the provided automation script to spin up the infrastructure.
   ```shell
   auto\dc.cmd dev
   ```

3. **Database Initialization**:
   The `database/init/` directory contains scripts (e.g., `00_init_dbs.sh`, `01_radar_schema.sql`, `03_metabase_restore.sql`, `04_patch_metabase.sh`) that Docker automatically executes when the PostgreSQL container is first created.

## Architecture & Next Steps
The infrastructure currently relies on Docker to orchestrate databases (PostgreSQL) and analytics tools (Metabase). 

### Production Deployment Scheduling
As documented in the Architecture Decision Records [ADR-001.production_deployment_scheduling.md](docs/adr/ADR-001.production_deployment_scheduling.md) and [ADR-002.production_deployment_on_x86_&_debian.md](docs/adr/ADR-002.production_deployment_on_x86_%26_debian.md), `radar-core` is deployed in production on an **x86_64** VM with **Debian 13 (Trixie)** hosted on Hetzner Cloud.

The chosen approach uses **`systemd timer + service`** to schedule containerized, one-shot executions of `radar-core`. This architecture was selected over alternatives as explained in the ADRs.

For a detailed step-by-step guide on deploying to Hetzner Cloud, see [Deployment_01_isolation_validation.md](docs/Deployment_01_isolation_validation.md).

### Observability & Logs
In production, application logs are not collected via Docker's internal mechanisms. Instead, they are routed directly to the host's journaling system. To consult the ephemeral engine logs, use the following command:
```shell
sudo journalctl -u radar-core.service
```

## Automation Scripts
The repository contains scripts for both Windows and Linux to simplify common operational tasks and automate deployments:

**Windows Command Scripts (`auto/`):**
- **`auto\dc.cmd <target>`**: Helper for Docker Compose.
  - Usage: `auto\dc.cmd e2e`.
  - It handles environment file injection and project naming.
  
- **`auto\dump_mb_db.cmd`**: Utility to easily back up or extract the Metabase application database.
  - Usage: `auto\dump_mb_db.cmd [db_password]`.
  - It generates a dump of the Metabase database and sanitizes sensitive data.
  
- **`auto\infra_02_of_05_deploy.cmd`**: Uses `scp` to transfer deployment files to the remote server.

**Linux Automation Scripts (`scripts/`):**
A suite of scripts automates the 5 phases of production deployment:
- **`scripts/infra_01_of_05_cleanup.sh`**: Environment cleanup and reset.
- **`scripts/infra_03_of_05_config.sh`**: Assigns permissions, applies security hardening, and configures `systemd`.
- **`scripts/infra_04_of_05_dc.sh`**: Brings up persistent services (PostgreSQL and Metabase).
- **`scripts/infra_05_of_05_validate.sh`**: Executes and validates the initial run of the `radar-core` engine.

**Execution Wrapper:**
- **`scripts/run_radar_core.sh`**: Critical wrapper around `docker run` for the ephemeral engine (managed by `systemd`). It injects necessary shared memory (`--shm-size 2gb`) for data processing tools like Numba/Polars and securely routes container logs directly to JournalD.

## Project Status
The production deployment model using `x86_64` VMs, `Debian 13`, and `systemd` timers on Hetzner Cloud infrastructure has been successfully established and documented. The infrastructure is fully operational for development, end-to-end testing, and production.

## License
This project is licensed under the MIT License. See the LICENSE file if available; otherwise, you may consider the standard MIT terms applicable by default.
