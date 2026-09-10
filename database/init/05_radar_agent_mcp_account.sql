-- database/init/05_radar_agent_mcp_account.sql

-- 1. Create a dedicated agent user
CREATE ROLE agent_mcp WITH LOGIN PASSWORD 'set_a_very_strong_password';

-- 2. Grant connection and schema usage
GRANT CONNECT ON DATABASE radar TO agent_mcp;
GRANT USAGE ON SCHEMA public TO agent_mcp;

-- 3. Grant read-only permissions on current and future tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO agent_mcp;  -- current
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO agent_mcp;  -- futures

-- 4. Defense-in-depth restrictions: revoke mutation rights
REVOKE CREATE ON SCHEMA public FROM agent_mcp;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM agent_mcp;

-- 5. Session and transaction guardrails
-- Enforce read-only transactions at the role level
ALTER ROLE agent_mcp SET default_transaction_read_only = on;
-- Kill any query running longer than 5 seconds (prevents accidental full-table scans)
ALTER ROLE agent_mcp SET statement_timeout = '5000';
-- Terminate lock-waiting after 2 seconds to avoid blocking your development workflow
ALTER ROLE agent_mcp SET lock_timeout = '2000';
-- Kill abandoned/hanging transactions after 5 seconds
