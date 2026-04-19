# Radar Infra — Infrastructure and Deployment

Radar Infra is the infrastructure companion to the [Radar Core](https://github.com/NestorDR/radar-core) project. It provides the necessary tools, databases, environments, and deployment configurations to run the Financial Strategy Analyzer efficiently across development, testing, and production environments.

## Features
- **Database Provisioning**: Automated initialization scripts (`.sql` and `.sh`) for PostgreSQL, including schema creation, views, and Metabase restoration.
- **Environment Management**: Templated environment variables for Development (`dev`), End-to-End testing (`e2e`), and Production (`prod`).
- **Container Orchestration**: Docker Compose configurations tailored for different stages (`docker-compose.dev.yml`, `docker-compose.e2e.yml`).
- **Automation Scripts**: Helper scripts (`auto/dc.cmd`, `auto/dump_mb_db.cmd`) to streamline Docker operations and database backups.
- **Architectural Decision Records (ADRs)**: Documentation of key infrastructure decisions, such as deployment scheduling.

## Repository Structure & Version Control
The repository is structured to separate code and configuration from ephemeral or sensitive data:

**Included in version control:**
- `auto/`: Automation and helper scripts for Windows.
- `database/init/`: Database schemas, initialization scripts, and Metabase patches.
- `envs/`: Environment templates (`*.template`).
- `docs/`: ADRs and infrastructure documentation.
- `docker-compose.*.yml`: Environment-specific container definitions.

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
   auto\dc.cmd
   ```

3. **Database Initialization**:
   The `database/init/` directory contains scripts (e.g., `00_init_dbs.sh`, `01_radar_schema.sql`, `03_metabase_restore.sql`, `04_patch_metabase.sh`) that Docker automatically executes when the PostgreSQL container is first created.

## Architecture & Next Steps
The infrastructure currently relies on Docker to orchestrate databases (PostgreSQL) and analytics tools (Metabase). 

### Upcoming: Production Deployment Scheduling
As documented in [ADR-001.production_deployment_scheduling.md](docs/adr/ADR-001.production_deployment_scheduling.md), the next major milestone is deploying `radar-core` in production on a VM infrastructure on a cloud provider. 

The chosen approach is to use **`systemd timer + service`** to schedule containerized, one-shot executions of `radar-core`. This architecture was selected over alternatives as explained in the ADR (Architecture Decision Record).

As documented in [ADR-002.production_deployment_on_x86_&_debian.md](docs/adr/ADR-002.production_deployment_on_x86_%26_debian.md) the first production version will run on an **x86_64** VM with **Debian 12 (Bookworm)** as the host operating system. 

## Automation Scripts
The `auto/` directory contains Windows Command scripts to simplify common operational tasks:
- **`auto\dc.cmd`**: Helper for Docker Compose. It streamlines commands by injecting the correct environment files and project names.
- **`auto\dump_mb_db.cmd`**: Utility to easily back up or extract the Metabase application database.

## Project Status
In active development. Currently finalizing the production deployment model using `x86_x64 VM`, `Debian 12`, and`systemd` timers for the Hetzner VM infrastructure.

## License
This project is licensed under the MIT License. See the LICENSE file if available; otherwise, you may consider the standard MIT terms applicable by default.
