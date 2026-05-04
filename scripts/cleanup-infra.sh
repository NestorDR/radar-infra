#!/bin/bash

# scripts/cleanup-infra.sh
# WARNING: This script is destructive. It stops all services and WIPES the database data.
# Purpose: Ensure a clean state for deployment validation.

# Configuration
PROJECT_NAME="radar-core"
INFRA_DIR="/opt/radar/infra"
# Use relative paths for Docker Compose once we are inside the INFRA_DIR
COMPOSE_FILE="docker-compose.prod.yml"
ENV_FILE="envs/.env.prod"

echo "--- Starting full environment cleanup [Project: $PROJECT_NAME] ---"

# Change to the project directory (CRITICAL for relative paths and interpolation)
echo "[1/5] Changing working directory to $INFRA_DIR..."
cd "$INFRA_DIR" || { echo "Error: Could not enter $INFRA_DIR"; exit 1; }

# Stop and remove containers, networks, and orphan resources
echo "[2/5] Stopping and removing Docker Compose services..."
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

# Wipe persistent database data (Bind Mount)
echo "[3/5] Wiping persistent data in $DATA_DIR..."
if [ -d "$DATA_DIR" ]; then
    # We use sudo as the files are owned by the PostgreSQL user (UID 999)
    # The :? prevents catastrophic accidental deletion if the variable is empty
    sudo rm -rf "${DATA_DIR:?}"/*
    echo "PostgreSQL data cleared successfully."
else
    echo "Data directory not found. Skipping..."
fi

# Prune residual networks and containers
echo "[4/5] Cleaning up residual Docker networks and stopped containers..."
docker network prune -f
docker container prune -f

# 4. Final status check
echo "[5/5] Verifying current state..."
docker ps -a
# Check if the network was successfully removed
docker network ls | grep "radar-network" || echo "Network radar-network removed."

echo "--- Cleanup completed. Environment is ready for a fresh deployment. ---"
