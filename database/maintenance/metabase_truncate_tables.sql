-- Connect to the specific database before creating schemas
\connect metabase

-- 1. Check the table sizes:
SELECT relname                                       AS table_name,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
       pg_size_pretty(pg_relation_size(relid))       AS table_size,
       pg_size_pretty(pg_indexes_size(relid))        AS index_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;

-- 2. Wipe the task and execution logs
BEGIN;

-- Truncate the bloated log tables atomically
TRUNCATE TABLE
    task_history,
    task_run,
    query_execution,
    view_log,
    ai_usage_log,
    support_access_grant_log
    CASCADE;

COMMIT;

-- 3. Reclaim physical disk space
-- IMPORTANT: VACUUM cannot run inside a transaction block.
-- It must be executed separately after the COMMIT.
VACUUM FULL;
