#!/bin/bash

# scripts/deploy-infra.sh
# Purpose: Orchestrate the deployment of persistent services (PostgreSQL & Metabase)

# Configuration
PROJECT_NAME="radar-core"
INFRA_DIR="/opt/radar/infra"
# Use relative paths for Docker Compose once we are inside the INFRA_DIR
COMPOSE_FILE="docker-compose.prod.yml"
ENV_FILE="envs/.env.prod"

echo "--- Starting infrastructure deployment [Project: $PROJECT_NAME] ---"

# Change to the project directory (CRITICAL for relative paths and interpolation)
echo "[1/4] Changing working directory to $INFRA_DIR..."
cd "$INFRA_DIR" || { echo "Error: Could not enter $INFRA_DIR"; exit 1; }

# Pre-deployment checks
echo "[2/4] Validating configuration files..."
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Error: Compose file not found at $COMPOSE_FILE"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file not found at $ENV_FILE"
    exit 1
fi
echo "All files validated."

# Launching containers
echo "[3/4] Executing Docker Compose up..."
# --env-file: Loads the specific production secrets
# -f: Specifies the compose file to use
# -p: Sets the project name
# up: Builds, (re)creates, starts, and attaches to containers for a service.
# -d: Runs in detached mode (background)
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d

# Final status report
echo "[4/4] Checking service status..."
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps

echo "--- Deployment process finished ---"
echo "Tip: You can monitor database initialization with: docker logs -f radar-postgres"