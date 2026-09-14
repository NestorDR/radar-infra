# Daily VPS Maintenance

## Purpose

The daily maintenance workflow reclaims disposable host and Metabase history space on the Debian production VPS without interrupting the persistent PostgreSQL, Metabase, and Caddy stack. It is implemented as one ordered coordinator, `scripts/radar_maintenance.sh`, invoked by the dedicated `systemd` service and timer.

The workflow is intentionally conservative: it never deletes Radar price data, PostgreSQL bind-mounted data, Caddy state volumes, credentials, or Metabase application metadata.

## Schedule and units

`radar-maintenance.timer` runs `radar-maintenance.service` once per day at **00:30 `America/New_York`**, before the existing `radar-core.timer` daily run at 01:30. `systemd` applies the New York time zone, including daylight-saving changes. The timer sets `Persistent=false`; if the VPS is unavailable at 00:30, maintenance waits for the next scheduled window rather than running at an arbitrary reboot time.

The service is a root-owned, non-restarting `oneshot` with a one-hour start timeout. It requires Docker, runs from `/opt/radar/infra`, and sends standard output and error to journald. A host `flock` on `/run/lock/radar-maintenance.lock` prevents concurrent scheduled and manual executions.

## Maintenance scope

The coordinator stops before destructive work unless all of these preconditions pass:

- `/opt/radar/infra`, `/opt/radar/infra/envs/.env.prod`, and `database/maintenance/metabase_truncate_tables.sql` are readable.
- Docker and the host cleanup utilities are available, and `docker info` succeeds.
- `radar-postgres` is running and its configured Docker healthcheck reports `healthy`.
- The protected PostgreSQL data directory `/opt/radar/infra/database/data` exists.

After preflight, the phases run in this order:

1. **Metabase database purge.** The SQL is piped into `psql` inside `radar-postgres`, using `POSTGRES_USER` parsed from `envs/.env.prod` without sourcing that file. The invocation uses `-v ON_ERROR_STOP=1`, a ten-minute statement timeout, and a five-second lock timeout. The transaction truncates only the existing maintenance list: `field_usage`, `query_execution`, `query_cache`, `query`, `task_history`, `task_run`, `view_log`, `login_history`, `audit_log`, `ai_usage_log`, `semantic_search_token_tracking`, and `support_access_grant_log`. It then runs `VACUUM (ANALYZE)` outside the transaction. A lock or SQL error fails the service and prevents later phases from running.
2. **Docker resource pruning.** `../../scripts/docker_prune.sh` reports disk, inode, and Docker usage, then prunes stopped containers, unused images, unused networks, and unused build cache. These commands deliberately do not use `--volumes`; unused image pruning can remove rollback images, so retain any image needed for an emergency rollback before running a manual execution.
3. **Host cleanup.** `systemd-tmpfiles --clean` applies the operating system's configured temporary-file policy. `journalctl --vacuum-time=30d` retains the most recent 30 days of journal entries and removes only older entries.
4. **Diagnostics.** The coordinator reports final disk and inode capacity for the PostgreSQL data path; this is read-only and does not clean that path.

The routine does not run `VACUUM FULL`, because it takes an exclusive table lock and is unnecessary after `TRUNCATE`. It does not create automatic backups.

## Protected data and explicit exclusions

The following remain outside all scheduled deletion commands:

- `/opt/radar/infra/database/data`, the PostgreSQL bind-mounted data directory.
- `/opt/radar/infra/cache`, the Radar price cache.
- `envs/.env.prod` and all other environment or credential files.
- Metabase dashboards, questions, users, permissions, and other application metadata not in the explicit maintenance list.
- Caddy's named volumes `radar-caddy-data` and `radar-caddy-config`, including certificates and active configuration state.
- All Docker volumes: the scheduled prune path never passes `--volumes`.

No broad recursive deletion is used for `/tmp`, `/var/tmp`, `/opt/radar`, or Docker volumes.

## Manual operation

Use the service unit for a manual run so the same lock, preflight, ordering, timeout, and journald reporting apply. Do not execute the coordinator concurrently from another shell.

```bash
# Start one guarded run without enabling, disabling, or changing the maintenance timer.
sudo systemctl start radar-maintenance.service
# Inspect the oneshot result and failure state without following or modifying the service.
sudo systemctl status radar-maintenance.service --no-pager
# Confirm the next New York-time trigger and that the timer is active.
systemctl list-timers radar-maintenance.timer
# Review the complete maintenance run, including the phase that failed if applicable.
sudo journalctl -u radar-maintenance.service --no-pager
# Follow new maintenance messages during an explicitly requested manual run.
sudo journalctl -u radar-maintenance.service -f
```

The service returns a non-zero result when preflight, SQL, Docker pruning, temporary-file cleanup, journal retention, or diagnostics fail. A concurrent invocation also exits non-zero without starting a second purge. The journal entry identifies the current phase; fix that phase's cause and retry the service rather than bypassing the coordinator.

## Failure recovery

1. Inspect the failed phase and status:

   ```bash
   # Identify the failed systemd result and its exit status.
   sudo systemctl status radar-maintenance.service --no-pager
   # Read the latest maintenance failure and preflight diagnostics.
   sudo journalctl -u radar-maintenance.service -n 200 --no-pager
   ```

2. If preflight failed, restore the expected file paths and permissions, confirm Docker is available, and verify the health of `radar-postgres` and `radar-metabase` before retrying. If the SQL phase timed out, allow active Metabase work to finish; do not remove locks or force a blocking database operation.
3. If Docker pruning or host cleanup failed, preserve the journal output, correct the host-level issue, and rerun the service. The ordered coordinator will not silently continue after a failed phase.
4. After a successful retry, confirm PostgreSQL and Metabase remain available. If application data must be restored, use the existing targeted backup procedure in [`scripts/dump_postgres_db.sh`](../../scripts/dump_postgres_db.sh); this maintenance workflow does not generate or delete backups.

## Deployment verification

After `scripts/infra_03_of_05_config.sh` has been run by the VPS owner, perform these non-destructive checks:

```bash
# Confirm the timer is registered, active, and scheduled for the next 00:30 New York-time trigger.
systemctl list-timers radar-maintenance.timer
# Confirm the installed service definition is loaded with its bounded oneshot configuration.
systemctl cat radar-maintenance.service
# Confirm the installed timer definition retains the non-catch-up policy.
systemctl cat radar-maintenance.timer
# Confirm the persistent stack remains running after deployment.
docker ps --filter name=radar-postgres --filter name=radar-metabase --filter name=radar-caddy
# Confirm the PostgreSQL healthcheck reports healthy without changing the container.
docker inspect --format '{{.State.Running}} {{.State.Health.Status}}' radar-postgres
# Confirm the protected PostgreSQL bind mount still points at the production data directory.
docker inspect --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}' radar-postgres
# Confirm Caddy's persistent named volumes remain attached to the Caddy container.
docker inspect --format '{{range .Mounts}}{{println .Name "->" .Destination}}{{end}}' radar-caddy
# Confirm disk and inode usage without deleting files.
df -h /opt/radar/infra/database/data
df -i /opt/radar/infra/database/data
# Review the latest service result and any phase-level errors.
journalctl -u radar-maintenance.service -n 200 --no-pager
# Confirm Metabase remains responsive through the existing public endpoint or its approved health check.
curl --fail --silent --show-error --head https://radar.ndromero.com/
```

The expected checks are: the timer is active with the next 00:30 trigger; `Persistent=false` is present in the installed timer; all three persistent containers are running; `radar-postgres` reports `true healthy`; the PostgreSQL source is `/opt/radar/infra/database/data`; Caddy retains `radar-caddy-data` and `radar-caddy-config`; and Metabase responds through the normal Caddy endpoint. These checks do not trigger the maintenance service or alter production resources.

## Related files

- [`scripts/radar_maintenance.sh`](../../scripts/radar_maintenance.sh): ordered coordinator, lock, preflight, and cleanup phases.
- [`database/maintenance/metabase_truncate_tables.sql`](../../database/maintenance/metabase_truncate_tables.sql): explicit Metabase maintenance table scope.
- [`../../scripts/docker_prune.sh`](../../scripts/docker_prune.sh): non-volume Docker diagnostics and pruning.
- [`systemd/radar-maintenance.service`](../../systemd/radar-maintenance.service) and [`systemd/radar-maintenance.timer`](../../systemd/radar-maintenance.timer): installed service and schedule.
- [`scripts/infra_03_of_05_config.sh`](../../scripts/infra_03_of_05_config.sh): deployment integration for the units.
