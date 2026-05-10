#!/bin/bash

# scripts/infra_01_of_05_cleanup.sh
# WARNING: This script is destructive. It stops all services and WIPES the database data.
# Purpose: Ensure a clean state for deployment validation.

# Configuration
PROJECT_NAME="radar-core"
INFRA_DIR="/opt/radar/infra"
DATA_DIR="$INFRA_DIR/database"
# Use relative paths for Docker Compose once we are inside the INFRA_DIR
COMPOSE_FILE="docker-compose.prod.yml"
ENV_FILE="envs/.env.prod"

echo "--- Starting full environment cleanup [Project: $PROJECT_NAME] ---"

# Change to the project directory (CRITICAL for relative paths and interpolation)
echo "[1/6] Changing working directory to $INFRA_DIR..."
cd "$INFRA_DIR" || { echo "Error: Could not enter $INFRA_DIR"; exit 1; }

# Stop and disable systemd services
echo "[2/6] Stopping and disabling systemd services..."
# Stop the clock from firing any more executions
sudo systemctl stop radar-core.timer
# Stop the service if it’s running right now
sudo systemctl stop radar-core.service
# Disable ambos so that they do not start when restarting the VM
sudo systemctl disable radar-core.service
sudo systemctl disable radar-core.timer
# Remove physical files from the /etc system folder
sudo rm /etc/systemd/system/radar-core.*
# Remove physical files from the /logs folder
sudo rm $INFRA_DIR/logs/radar-core.*
# Reload the systemd daemon to apply changes
sudo systemctl daemon-reload
# Optional: Clear the "failed" state if it appeared in red
sudo systemctl reset-failed

# Stop and remove containers, networks, and orphan resources
echo "[2/6] Stopping and removing Docker Compose services..."
if [ -f "$COMPOSE_FILE" ]; then
    # --env-file: Loads the specific production secrets
    # -f: Specifies the compose file to use
    # -p: sets the project name explicitly to avoid folder-based naming conflicts
    # down: Stops containers and removes containers, networks, volumes, and images created by up.
    # --remove-orphans: Removes containers for services not defined in the compose file (useful if services were removed from the configuration)
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down --remove-orphans
else
    echo "Error: $COMPOSE_FILE not found."
fi

# Remove/delete persistent database data (Bind Mount)
echo "[3/6] Wiping persistent data in $DATA_DIR..."
if [ -d "$DATA_DIR" ]; then
    # rm: removes files or directories
    # -r (recursive): allows rm to remove directories and their contents recursively
    # -f (force): forces the removal without prompting for confirmation, even if the files are write-protected
    # :? : prevents catastrophic accidental deletion if the variable is empty
    # OBS: Use `sudo` if the files are already owned by the PostgreSQL user (UID 999)
    rm -rf "${DATA_DIR:?}"/*
    echo "PostgreSQL data cleared successfully."
else
    echo "Data directory not found. Skipping..."
fi

# Prune residual networks and containers
echo "[4/6] Cleaning up residual Docker networks and stopped containers..."
docker network prune -f
docker container prune -f

# 4. Final status check
echo "[5/6] Verifying current state..."
docker ps -a
# Check if the network was successfully removed
docker network ls | grep "radar-network" || echo "Network radar-network removed."
# Check if the radar-core systemd services are stopped and disabled
systemctl list-timers --all | grep radar-core || echo "radar-core.timer is not active."

echo "--- Cleanup completed. Environment is ready for a fresh deployment. ---"
