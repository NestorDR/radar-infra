# Journey

Objective: **run `radar-core` in production on a Hetzner VM (Linux host) while releasing resources between scheduled executions**.

## Discarded alternatives

#### 1) Separate ephemeral VM per execution
Discarded because, although it aligns with the idea of “releasing resources” between runs, it introduces operational complexity for a second VM dedicated to radar-core: provisioning, teardown, infrastructure automation, synchronization with PostgreSQL/Metabase, and higher startup latency.

#### 2) Cron executing the `radar-core` source code directly on the Linux VM (host) as Python code
Discarded because it implies running `radar-core` as native Python on the VM, which requires installing and maintaining Python, `uv`, dependencies, and the project source code on the host, increasing the coupling between infrastructure and application. It also does not align with a CI/CD-built image deployment model.

#### 3) Cron triggering `docker compose up` + `down`
A simpler solution using Docker for `radar-core`. Discarded because it offers **less control and observability**:
- `cron` only triggers commands, but it does not model the job lifecycle well.
- Handling failures, timeouts, dependencies, states, and logs is more manual.
- If one execution overlaps with another or fails, diagnosis is more difficult.

#### 4) Ofelia
Discarded because it requires a **permanent scheduler container** to trigger jobs, adding another component to operate, which is preferable to avoid on a constrained VM.

#### 5) Chadburn
Discarded for the same operational reason as Ofelia: it would require a dedicated container running continuously. Although it adds flexibility by reading configuration from labels or INI files, it still introduces a permanent layer of complexity.

## Preferred option

#### 6) `systemd timer + service`
- Does **not** require a permanently running scheduler container.
- The Linux host schedules executions natively.
- `radar-core` can be triggered as a one-shot job in a container.
- Better control over startup, shutdown, dependencies, logs, and failures.
- Well suited for a small, stable VM such as the Hetzner Ampere CAX21.

## Why `systemd` wins here

`systemd` provides a cleaner architecture:

- `timer` defines **when** to run.
- `service` defines **what** to run.
- The service can start Docker, run the container, wait for completion, and then release resources.
- `radar-core` logs still go to `stdout`, so Docker and `journald` can capture them.

This solution is more robust than cron and lighter than a containerized scheduler.