#!/bin/bash
# radar-infra/database/init/00-init-dbs.sh

# Stop script on error
set -e

# Usage: This script runs automatically when the PostgreSQL container starts with an empty volume.
# It creates additional databases defined in the POSTGRES_MULTIPLE_DATABASES environment variable.
# Format: POSTGRES_MULTIPLE_DATABASES=db1,db2,db3

# Function to create a database and grant privileges to the default user
create_user_and_database() {
	local database=$1

	# Check if the database already exists using a lightweight SQL query
	echo "  CHECK: Verifying status of database '$database'..."
	# -t: Tuple only (without headers)
	# -A: Unaligned output, for easier parsing (removes padding blanks that psql normally adds for tables to appear aligned in console)
	# -c: Run command/query between quotes and exit
  # | (Pipe): Redirects the standard output (stdout) of psql to the standard input (stdin) of grep.
	# grep: Search for a text pattern (grep: acronym of "Global Regular Expression Print")
	# -q (Quiet/Silent): Modo silencioso. No imprime nada en la pantalla. Su única función es devolver un Exit Status (Estado de Salida).
	# 1: Is the pattern being searched, the result of SELECT 1.
	if psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -tAc "SELECT 1 FROM pg_database WHERE datname='$database'" | grep -q 1; then
		echo "  INFO: Database '$database' already exists. Skipping creation."

	else
		echo "  ACTION: Creating database '$database'..."
	# <<: StartS redirection by sending the following text block (`CREATE...`) to the stdin of the command preceding it (in this case, psql).
  # -: Allows code to be indented with tabs for greater visual clarity.
  # EOSQL: Is the discretional delimiter or tag that marks the beginning and end of the block.
  # The intermediate block: This is the content that is sent to the command preceding the instruction (in this case, psql).
		psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
		    CREATE DATABASE $database;
		    GRANT ALL PRIVILEGES ON DATABASE $database TO $POSTGRES_USER;
EOSQL
		echo "  SUCCESS: Database '$database' created successfully."
	fi
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
	echo "INIT: Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"
  #	Convert comma-separated string to space-separated list
  # tr: (acronym for "translate") performs character substitution in a text stream.
	for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
		create_user_and_database $db
	done
	echo "INIT: Database processing completed."
fi