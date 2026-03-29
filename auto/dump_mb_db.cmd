:: auto/dump_mb_db.cmd
:: Generates a dump of the Metabase database and sanitizes sensitive data.
:: Usage: auto/dump_mb_db [db_password]
@ECHO OFF

:: Enable delayed expansion to handle environment variables correctly within blocks
SETLOCAL ENABLEDELAYEDEXPANSION

:: Get the directory where the script is located
SET SCRIPT_DIR=%~dp0
:: Ensure we are executing from the project root (one level up from /auto)
CD /D "!SCRIPT_DIR!..!"

:: --- Configuration Section ---
:: Set pg_dump executable
SET PG_DUMP_PATH="%PROGRAMFILES%\PostgreSQL\17\bin\pg_dump.exe"
:: DB parameters - Align these with your .env.dev if possible
SET DB_HOST=localhost
SET DB_PORT=5432
SET DB_USER=postgres
SET DB_NAME=metabase
:: Target dir for the docker-entrypoint-initdb.d scripts
SET OUTPUT_DIR=database\init
SET OUTPUT_FILE=03_metabase_restore.sql
:: Sensitive data sanitization parameters
SET METABASE_SOURCE_DB_HOST=host.docker.internal
SET METABASE_TARGET_DB_HOST=db
SET METABASE_SOURCE_DB_PWD=%~1
:ASK_PASSWORD
:: If not provided via argument and still empty, ask the user
IF "!METABASE_SOURCE_DB_PWD!"=="" (
    SET /P METABASE_SOURCE_DB_PWD="Enter password for PostgreSQL user '!DB_USER!': "
    :: Check again; if user just pressed Enter, go back to the label
    IF "!METABASE_SOURCE_DB_PWD!"=="" (
        echo [ERROR] Password cannot be empty.
        GOTO ASK_PASSWORD
    )
)
SET METABASE_TARGET_DUMMY_PWD=dummy_password

:: --- Execution Section ---
:: Create output directory if it doesn't exist
IF NOT EXIST "!OUTPUT_DIR!" (
    echo [ACTION] Creating missing directory: !OUTPUT_DIR!
    mkdir "!OUTPUT_DIR!"
)

echo [PROCESS] Generating Metabase metadata dump...
:: FLAGS EXPLANATION:
:: -h, -p, -U ...: Connection parameters
:: -d ...........: Source database
:: -O ...........: No Owner. Prevents errors when the user in Docker has a different name
:: -x ...........: No Privileges. Avoids trying to set permissions that might not exist in the container
:: --clean ......: Includes DROP commands to overwrite existing data if the script is re-run
:: --if-exists ..: Complements --clean to avoid errors if objects don't exist
:: -f ...........: Target file
:: --exclude-table-data : Excludes transactional and logging tables to avoid metadata coupling
!PG_DUMP_PATH! -h !DB_HOST! -p !DB_PORT! -U !DB_USER! -d !DB_NAME! -O -x -f "!OUTPUT_DIR!\!OUTPUT_FILE!"

if !errorlevel! neq 0 (
    echo [ERROR] pg_dump failed. Check if PostgreSQL is running and credentials are correct.
    exit /b !errorlevel!
)

:: Append a \connect command at the beginning of the file.
:: Since 00-init-dbs.sh creates the DB, 03 must ensure it switches to it.
echo \connect !DB_NAME! > "!OUTPUT_DIR!\temp_dump.sql"
type "!OUTPUT_DIR!\!OUTPUT_FILE!" >> "!OUTPUT_DIR!\temp_dump.sql"
move /y "!OUTPUT_DIR!\temp_dump.sql" "!OUTPUT_DIR!\!OUTPUT_FILE!" > nul

echo [PROCESS] Sanitizing sensitive credentials...
:: Replace the plain text development password and host with the predefined target values
powershell -Command "(Get-Content '!OUTPUT_DIR!\!OUTPUT_FILE!') -replace '!METABASE_SOURCE_DB_PWD!', '!METABASE_TARGET_DUMMY_PWD!' | Set-Content '!OUTPUT_DIR!\!OUTPUT_FILE!'"
powershell -Command "(Get-Content '!OUTPUT_DIR!\!OUTPUT_FILE!') -replace '!METABASE_SOURCE_DB_HOST!', '!METABASE_TARGET_DB_HOST!' | Set-Content '!OUTPUT_DIR!\!OUTPUT_FILE!'"

echo.
echo [SUCCESS] Script '!OUTPUT_FILE!' generated and sanitized in '!OUTPUT_DIR!'.

ENDLOCAL