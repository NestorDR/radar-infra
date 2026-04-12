#!/bin/bash
# radar-infra/scripts/run-radar-core.sh
# PURPOSE: Lifecycle management of the ephemeral radar-core container.
# REASONING: Ensures clean environment, shared memory allocation, and logging.

set -e # Exit immediately if a command exits with a non-zero status.

CONTAINER_NAME="radar-core-job"
IMAGE="ghcr.io/nestordr/radar-core:latest"
ENV_FILE="/opt/radar/infra/envs/.env.prod"

echo "[$(date)] Starting Radar-Core execution..."

# 1. Clean up potential leftovers from crashed previous runs
# Using || true to ignore errors if the container doesn't exist.
docker rm -f $CONTAINER_NAME 2>/dev/null || true

# 2. Run the processing job
# --rm: Automatically remove the container when it exits (resource cleanup).
# --network: Connect to the existing persistent network created by docker-compose.
# --shm-size: Critical for Polars/Numba multiprocessing performance.
# --log-driver: Delegates log management to Linux Systemd Journal.
docker run --rm \
    --name $CONTAINER_NAME \
    --network radar_prod_network \
    --env-file "$ENV_FILE" \
    --shm-size 2gb \
    --log-driver=journald \
    "$IMAGE"

echo "[$(date)] Radar-Core execution finished successfully."