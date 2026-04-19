#!/bin/bash
# database/init/04_patch_metabase.sh

# Exit immediately if a command exits with a non-zero status
set -e

echo "[PROCESS] Updating Metabase database connections with E2E credentials..."

# Execute SQL patch using internal PostgreSQL variables (-v) to safely inject configuration
# This approach avoids string manipulation risks like envsubst corrupting SQL internal syntax
# Use Heredoc block `<< 'EOF'`, with EOF in quotation marks to prevent that `Bash` tries to expand variables,
#  delegating 100% of the safe interpolation to psql.
# - Heredoc: Here Document
# - EOF: End Of File (or End Of Input) is a marker used to indicate the end of a block of text in a script. It can be any string, but EOF is commonly used by convention.
# Syntax 'variable' tells psql to safely quote and escape the variable as a string literal.
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d metabase \
    -v target_host="$MB_DB_HOST" \
    -v target_password="$MB_DB_PASS" << 'EOF'
    UPDATE metabase_database
    SET details = jsonb_set(
                    jsonb_set(details::jsonb, '{host}', to_jsonb(:'target_host'::text)),
                    '{password}', to_jsonb(:'target_password'::text)
                  )
    WHERE engine = 'postgres';
EOF

echo "[SUCCESS] Metabase connections patched successfully."