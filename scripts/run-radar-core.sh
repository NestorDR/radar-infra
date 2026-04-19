#!/bin/bash

# scripts/run-radar-core.sh
# Lifecycle management of the ephemeral radar-core container.
# Ensures clean environment, shared memory allocation, and logging.

set -e # Exit immediately if a command exits with a non-zero status.

CONTAINER_NAME="radar-core-job"
NETWORK="radar-network"  # Must match the network name in docker-compose.prod.yml
IMAGE="ghcr.io/nestordr/radar-core:latest"
ENV_FILE="/opt/radar/infra/envs/.env.prod"

echo "[$(date)] Starting Radar-Core execution..."

# 1. Clean up potential leftovers/residues from crashed previous runs
# rm ....: Remove the container if it exists.
# -f ....: Force removal of the container (via SIGKILL), suppressing messages by redirecting stderr (file descriptor 2) to /dev/null.
# || true: To ignore errors if the container doesn't exist.
docker rm -f $CONTAINER_NAME 2>/dev/null || true

# 2. Run the processing job
# --rm .......: Automatically remove the container when it exits (resource cleanup).
# --network ..: Connect to the existing persistent network created by docker-compose.
# --shm-size .: Critical for Polars/Numba multiprocessing performance.
# --log-driver: Delegates log management to Linux Systemd Journal.
# -v .........: Binds mount the settings.yml file as read-only (:ro) to provide configuration to the container.
docker run --rm \
    --name $CONTAINER_NAME \
    --network $NETWORK \
    --env-file "$ENV_FILE" \
    --shm-size 2gb \
    --log-driver=journald \
    -v /opt/radar/infra/config/settings.yml:/home/default/app/settings.yml:ro \
    "$IMAGE"

echo "[$(date)] Radar-Core execution finished successfully."