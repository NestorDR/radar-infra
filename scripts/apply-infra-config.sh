#!/bin/bash

# scripts/apply-infra-config.sh
# Purpose: Apply necessary permissions and configurations for the radar-core infrastructure.
# RUN previously: sudo chmod +x /opt/radar/infra/scripts/apply-infra-config.sh

echo "--- Starting the Infrastructure Configuration ---"

echo "[1/6] Adjusting file ownership (omitting data)..."
# Assign ownership and access permissions to folders created for the radar-admin user.
# find: traverses /opt/radar and all its subdirectories, and then applying chown to each file and directory found
# -path /opt/radar/infra/database/data: excludes the /opt/radar/infra/database/data directory from the search to avoid changing ownership on the Postgres volume folder
# -prune: prevents find from descending into the specified directory (in this case, the Postgres data directory)
# -o (or): allows the find command to execute the chown command on all other files and directories that are not pruned
# -exec: executes the specified command (chown) on each file or directory found by find that matches the criteria
# chown: changes the ownership of a file or directory
# -R (recursive): applies to all directories and files within the directory
# radar-admin:radar-admin: assigns ownership to the user and group radar-admin
# /opt/radar: path to the directory to modify
sudo find /opt/radar -path /opt/radar/infra/database/data -prune -o -exec chown radar-admin:radar-admin {} +
# OLD: sudo chown -R radar-admin:radar-admin /opt/radar

echo "[2/6] Adjusting standard permissions (omitting data)..."
# Assign standard read/write permissions to folders within /opt/radar.
# find: traverses /opt/radar and all its subdirectories (-type d) and then applying chmod ...
# -path /opt/radar/infra/database/data: excludes the /opt/radar/infra/database/data directory from the search to avoid changing permissions on the Postgres volume folder
# -prune: prevents find from descending into the specified directory (in this case, the Postgres data directory)
# -o (or): allows the find command to execute the chmod command on all other directories that are not pruned
# -exec: executes the specified command (chmod) on each directory found by find that matches the criteria
# chmod: applies standard read/write/traverse permissions
# 755 (rwxr-xr-x): owner (1*4.read + 1*2.write + 1*1.traverse) = 7, group (1*4.read + 0*2.write + 1*1.traverse) = 5, others (1*4.read + 0*2.write + 1*1.traverse) = 5
sudo find /opt/radar -path /opt/radar/infra/database/data -prune -o -type d -exec chmod 755 {} +
# OLD: find /opt/radar -type d -exec chmod 755 {} +

# Assign standard read/write permissions to files within /opt/radar.
# find: searches for regular files (-type f) in /opt/radar and then applying chmod...
# -path /opt/radar/infra/database/data: excludes the /opt/radar/infra/database/data directory from the search to avoid changing permissions on the Postgres volume folder
# -prune: prevents find from descending into the specified directory (in this case, the Postgres data directory)
# -o (or): allows the find command to execute the chmod command on all other files that are not pruned
# chmod: Applies standard read/write permissions
# 644 (rw-r--r--): owner (1*4.read + 1*2.write + 0*1.execute) = 6, group (1*4.read + 0*2.write + 0*1.execute) = 4, others (1*4.read + 0*2.write + 0*1.execute) = 4
sudo find /opt/radar -path /opt/radar/infra/database/data -prune -o -type f -exec chmod 644 {} +
# OLD: find /opt/radar -type f -exec chmod 644 {} +

echo "[3/6] Hardening secrets..."
# For sensitive files, such as environment variables, apply stricter permissions to prevent unauthorized access.
find /opt/radar -name ".env*" -exec chmod 600 {} +

echo "[4/5] Activating scripts..."
# Grant execution permissions (critical for system operation)
# Container orchestration scripts
sudo chmod +x /opt/radar/infra/scripts/*.sh
# Database initialization scripts
sudo chmod +x /opt/radar/infra/database/init/*.sh

echo "[5/6] Deploying systemd units..."
# Copy the radar-core.service and radar-core.timer files to the systemd folder
# cp: copies files from one location to another
sudo cp /opt/radar/infra/systemd/radar-core.{service,timer} /etc/systemd/system/
# Set owner to root (security standard for system services)
sudo chown root:root /etc/systemd/system/radar-core.{service,timer}
# Adjust permissions (read for everyone, write only root)
# chmod: applies standard read/write permissions
# 644 (rw-r--r--): owner (1*4.read + 1*2.write + 0*1.execute) = 6, group (1*4.read + 0*2.write + 0*1.execute) = 4, others (1*4.read + 0*2.write + 0*1.execute) = 4
sudo chmod 644 /etc/systemd/system/radar-core.*

echo "[6/6] Reloading the systemd demon and enabling timer..."
# Notify systemd of new files or changes
sudo systemctl daemon-reload
# Ensure that the timer is active and survives restarts
sudo systemctl enable radar-core.timer
# Start the timer immediately to schedule the radar-core service according to the defined schedule
sudo systemctl start radar-core.timer

echo "--- Infrastructure Configuration Completed ---"
# Verify permissions and ownership
# ls: displays the contents of a directory
# -l (long listing): displays details such as permissions, owner, size, and modification date
# a (all): includes hidden files (those that begin with a dot)
# R (recursive): displays the contents of subdirectories as well
# --ignore='data': excludes the 'data' directory from the listing to avoid cluttering the output with potentially large files
ls -laR --ignore='data' /opt/radar/infra/
ls -l /etc/systemd/system/radar-core.{service,timer}
echo ""

# Check the status of the timer to ensure it's active and scheduled correctly
# systemctl: controls the systemd system and service manager
# list-timers: lists all active timers and their next trigger times
# --all: includes inactive timers in the output, providing a comprehensive view of all timers regardless of their current state
# | grep radar: to filter the output to show only lines containing "radar" (if wanted to focus on the radar-core.timer)
systemctl list-timers --all

