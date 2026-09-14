#!/usr/bin/env bash

# Coordinate the guarded daily maintenance workflow from the production host.
set -Eeuo pipefail

# Keep all production inputs explicit so the routine cannot accidentally operate on a different checkout.
readonly INFRA_DIR="/opt/radar/infra"
readonly ENV_FILE="$INFRA_DIR/envs/.env.prod"
readonly SQL_FILE="$INFRA_DIR/database/maintenance/metabase_truncate_tables.sql"
readonly PRUNE_SCRIPT="$INFRA_DIR/scripts/docker_prune.sh"
readonly DATA_DIR="$INFRA_DIR/database/data"
readonly LOCK_FILE="/run/lock/radar-maintenance.lock"
readonly CONTAINER_NAME="radar-postgres"
readonly JOURNAL_RETENTION="30d"

CURRENT_PHASE="initialization"

# Report the phase and exit status through stdout/stderr so systemd captures failures in journald.
maintenance_error_handler() {
    local exit_code=$?
    printf '[ERROR] Maintenance failed during %s (exit %s)\n' "${CURRENT_PHASE}" "$exit_code" >&2
    exit "$exit_code"
}

# Convert unexpected command failures into an actionable journald entry without masking the original status.
trap maintenance_error_handler ERR

# Prefix each phase message with an ISO timestamp for readable manual and journal-based diagnosis.
log_phase() {
    printf '[%s] %s\n' "$(date --iso-8601=seconds)" "$*"
}

# Fail explicitly when a required precondition is not satisfied before destructive work begins.
fail_preflight() {
    printf '[ERROR] Preflight failed: %s\n' "$1" >&2
    exit 1
}

# Verify that the host provides the non-destructive locking utility before opening the shared lock file.
if ! command -v flock >/dev/null 2>&1; then
    fail_preflight "flock is not available"
fi

# Open one host-wide lock descriptor so scheduled and manually triggered executions cannot overlap.
exec 9>"$LOCK_FILE"

# Acquire the lock without waiting, preventing a second run from starting another purge or prune sequence.
if ! flock -n 9; then
    printf '[ERROR] Another radar maintenance execution already holds %s\n' "$LOCK_FILE" >&2
    exit 1
fi

# Confirm the production checkout and protected database data directory exist before any cleanup phase.
if [[ ! -d "$INFRA_DIR" ]]; then
    fail_preflight "production directory is missing: $INFRA_DIR"
fi
if [[ ! -d "$DATA_DIR" ]]; then
    fail_preflight "PostgreSQL data directory is missing: $DATA_DIR"
fi

# Change to the production repository before invoking helpers that rely on repository-relative paths.
cd "$INFRA_DIR"

# Confirm that every input and helper required by the ordered workflow is readable.
for required_path in "$ENV_FILE" "$SQL_FILE" "$PRUNE_SCRIPT"; do
    if [[ ! -r "$required_path" ]]; then
        fail_preflight "required file is missing or unreadable: $required_path"
    fi
done

# Confirm that the daemon and host cleanup utilities are installed before database work can begin.
for required_command in docker systemd-tmpfiles journalctl; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        fail_preflight "required command is unavailable: $required_command"
    fi
done

# Query Docker without changing resources to ensure the daemon is available for all later phases.
if ! docker info >/dev/null 2>&1; then
    fail_preflight "Docker daemon is unavailable"
fi

# Require the persistent PostgreSQL container to be running and to report its configured healthcheck as healthy.
if ! CONTAINER_HEALTH="$(docker inspect --format '{{.State.Running}} {{.State.Health.Status}}' "$CONTAINER_NAME")"; then
    fail_preflight "container '$CONTAINER_NAME' cannot be inspected"
fi
if [[ "$CONTAINER_HEALTH" != "true healthy" ]]; then
    fail_preflight "container '$CONTAINER_NAME' is not running and healthy (state: $CONTAINER_HEALTH)"
fi

# Parse only POSTGRES_USER from the production environment file; never source the file or execute its contents.
POSTGRES_USER="$(awk -F= '$1 == "POSTGRES_USER" { value=substr($0, index($0, "=") + 1); sub(/\r$/, "", value); print value; exit }' "$ENV_FILE")"
POSTGRES_USER="${POSTGRES_USER#\"}"
POSTGRES_USER="${POSTGRES_USER%\"}"
if [[ -z "$POSTGRES_USER" ]]; then
    fail_preflight "POSTGRES_USER is missing or empty in $ENV_FILE"
fi

log_phase "Preflight passed; PostgreSQL container '$CONTAINER_NAME' is healthy."

CURRENT_PHASE="Metabase database cleanup"
log_phase "Starting Metabase maintenance SQL."

# Execute the approved SQL inside PostgreSQL with fail-fast error handling and bounded lock/statement waits.
docker exec -i \
    -e "PGOPTIONS=-c statement_timeout=10min -c lock_timeout=5s" \
    "$CONTAINER_NAME" \
    psql -U "$POSTGRES_USER" -v ON_ERROR_STOP=1 -d metabase < "$SQL_FILE"

log_phase "Metabase maintenance SQL completed successfully."

CURRENT_PHASE="Docker resource pruning"
log_phase "Starting non-volume Docker resource pruning."

# Run the hardened helper only after the database phase succeeds; its commands intentionally exclude volumes.
bash "$PRUNE_SCRIPT"

log_phase "Docker resource pruning completed successfully."

CURRENT_PHASE="systemd temporary-file cleanup"
log_phase "Starting system-managed temporary-file cleanup."

# Delegate temporary-file policy to systemd-tmpfiles instead of recursively deleting arbitrary temporary paths.
systemd-tmpfiles --clean

CURRENT_PHASE="journald retention cleanup"
log_phase "Applying the configured journald retention limit of $JOURNAL_RETENTION."

# Retain recent operational history while allowing journald to reclaim entries older than the explicit policy limit.
journalctl --vacuum-time="$JOURNAL_RETENTION"

CURRENT_PHASE="final disk and inode diagnostics"
log_phase "Collecting final protected-data filesystem diagnostics."

# Report final disk capacity without deleting or modifying the PostgreSQL bind-mounted data directory.
df -h "$DATA_DIR"

# Report final inode capacity without modifying the PostgreSQL bind-mounted data directory.
df -i "$DATA_DIR"

log_phase "Daily maintenance completed successfully."
