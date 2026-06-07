#!/bin/bash

# scripts/dump_postgres_db.sh
# Purpose: Generate a granular logical backup (SQL dump) of a specific target database.
# Usage: ./dump_postgres_db.sh <database_name> <destination_filename.sql>

# region Configuration & Validation

# Set the path to the production environment file containing database credentials
ENV_FILE="/opt/radar/infra/envs/.env.prod"
CONTAINER_NAME="radar-postgres"

# Verify that both required arguments (database name and output file) are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <database_name> <destination_filename.sql>"
    exit 1
fi

TARGET_DB="$1"
DESTINATION_FILE="$2"

# Check if the production environment file exists before attempting to read variables
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Production environment file not found at $ENV_FILE"
    exit 1
fi

# Check if the PostgreSQL container is currently active and running
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" == "" ]; then
    echo "Error: Target container '$CONTAINER_NAME' is not active or running."
    exit 1
fi

# endregion Configuration & Validation

# region Execution

echo "--- Starting granular logical backup sequence for database: $TARGET_DB ---"

# Extract the database superuser username directly from the environment file
echo "[1/3] Parsing connection credentials from environment configuration..."
DB_USER=$(grep -E "^POSTGRES_USER=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '\r')

# Execute pg_dump targeting only the specified database name
echo "[2/3] Extracting schema and records for '$TARGET_DB' from container..."
docker exec -t "$CONTAINER_NAME" pg_dump -U "$DB_USER" "$TARGET_DB" > "$DESTINATION_FILE"

# Validate that the backup file was successfully created and is not empty
if [ -s "$DESTINATION_FILE" ]; then
    echo "[3/3] Sychronizing write buffers..."
    echo "--- Backup complete. Granular file saved to: $DESTINATION_FILE ---"
else
    echo "Error: Granular backup failed for database '$TARGET_DB'. File is empty or corrupted."
    rm -f "$DESTINATION_FILE"
    exit 1
fi

# endregion Execution