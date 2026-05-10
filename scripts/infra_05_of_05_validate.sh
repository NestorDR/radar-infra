#!/bin/bash

# scripts/infra_05_of_05_validate.sh
# Purpose: Validate the successful deployment of the infrastructure by checking database creation, radar-core execution and a clean log generation.

# List databases in the PostgreSQL container to verify that they has been created successfully
docker exec -it radar-postgres psql -U postgres -c "\l"

# List the tables in the radar database to verify that they have been created correctly
docker exec -it radar-postgres psql -U postgres -d radar -c "\dt"

# Check if the radar-core systemd services are enabled and active
systemctl list-timers --all | grep radar-core || echo "radar-core.timer is not active."

# Force rotation of current log files (close them and create new ones)
sudo journalctl --rotate

# Delete all old logs leaving only the last second
sudo journalctl --vacuum-time=1s

echo "Tip: You can monitor the logs in real-time in another terminal with: 'sudo journalctl -u radar-core.service -f'"

# Start the radar-core service to generate new logs
sudo systemctl start radar-core.service

# Export the logs of the radar-core service to a specific file within the infrastructure log folder
sudo journalctl -u radar-core.service --no-pager > /opt/radar/infra/logs/radar-core.log