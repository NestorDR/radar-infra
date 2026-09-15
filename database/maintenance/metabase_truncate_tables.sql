-- Connect to the specific database before creating schemas
\connect metabase

-- 1. Check the table sizes:
SELECT relname                                       AS table_name,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
       pg_size_pretty(pg_relation_size(relid))       AS table_size,
       pg_size_pretty(pg_indexes_size(relid))        AS index_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 30;



-- 2. Wipe the task and execution logs
-- =============================================================================
-- MAINTENANCE SCRIPT: PURGE METABASE LOGS, HISTORY, AND CACHE
-- Safe to execute in production. Does not delete questions, dashboards, or users.
-- =============================================================================

BEGIN;

-- Bound lock acquisition so active Metabase work causes a safe failure instead of an indefinite wait.
SET LOCAL lock_timeout = '5s';

TRUNCATE TABLE
    -- 2.1. Queries, Cache, and Field Telemetry
    field_usage, -- Field-level query usage tracking (depends on query_execution)
    query_execution, -- Individual query execution history
    query_cache, -- Cached results for heavy queries
    query, -- Query execution time averages

    -- 2.2. Background Tasks and Synchronizations
    task_history, -- Detailed background task execution steps
    task_run, -- High-level background task scheduler runs

    -- 2.3. Audit, Login History, and Telemetry
    view_log, -- Card and dashboard view audit records
    login_history, -- Login attempts, timestamps, and IP addresses
    audit_log, -- General activity audit logs
    ai_usage_log, -- AI assistant (Metabot) usage and token telemetry
    semantic_search_token_tracking, -- Token tracking metrics for semantic search
    support_access_grant_log
    -- Temporary support access grant logs

    -- =========================================================================
    -- OPTIONAL (Uncomment by removing '--' if a deeper cleanup is desired)
    -- =========================================================================
    -- , recent_views                 -- Clears users' "Recently viewed" lists
    -- , metabot_conversation         -- Clears AI chat conversation history
    -- , metabot_message              -- Individual messages from AI chat threads
    -- , core_session                 -- Terminates all currently active user sessions
;

COMMIT;

-- 3. Reclaim physical disk space
-- IMPORTANT: VACUUM cannot run inside a transaction block.
-- It must be executed separately after the COMMIT.
-- TRUNCATE returns disk pages directly to the OS; ANALYZE updates query planner stats.

-- VACUUM (ANALYZE);
--   • Action: Reuses dead tuple space internally and updates planner statistics.
--   • Impact: NON-BLOCKING (reads and writes continue). 100% safe for live production.
--   • Limitation: Does NOT shrink files on disk or return storage to the host OS.
--   • Best for: Routine maintenance and immediately following a TRUNCATE.
VACUUM (ANALYZE);

-- VACUUM FULL;
--   • Action: Physically rewrites tables and indexes to return disk space to the OS.
--   • Impact: EXCLUSIVE LOCK (blocks ALL reads and writes; application will freeze).
--   • Requirement: Requires temporary free disk space equal to the table size.
--   • Best for: Scheduled maintenance windows after massive DELETE operations.
--              (Never needed after TRUNCATE, as TRUNCATE already freed disk space).
-- =============================================================================
-- The blocking VACUUM FULL command is intentionally disabled for the routine maintenance path.
-- VACUUM FULL;