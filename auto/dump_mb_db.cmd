:: auto/dump_mb_db.cmd
:: Generates a dump of the Metabase database and sanitizes sensitive data.
:: Usage: auto/dump_mb_db [db_password]
@echo off

:: Enable delayed expansion to handle environment variables correctly within blocks
setlocal enabledelayedexpansion
set "_EXIT_CODE=0"

:: Require invocation from this repository's root directory.
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
for %%I in ("%CD%") do set "CURRENT_DIR=%%~fI"
if /i not "!CURRENT_DIR!"=="!PROJECT_ROOT!" (
    echo Error: Run this script from the project root: "!PROJECT_ROOT!"
    set "_EXIT_CODE=1"
    goto end
)

:: --- Configuration Section ---
:: Set pg_dump executable
set PG_DUMP_PATH="%PROGRAMFILES%\PostgreSQL\18\bin\pg_dump.exe"
:: DB parameters - Align these with your .env.dev if possible
set DB_HOST=localhost
set DB_PORT=5432
set DB_USER=postgres
set DB_NAME=metabase
:: Target dir for the docker-entrypoint-initdb.d scripts
set OUTPUT_DIR=database\init
set OUTPUT_FILE=03_metabase_restore.sql
:: Sensitive data sanitization parameters
set METABASE_SOURCE_DB_HOST=host.docker.internal
set METABASE_TARGET_DB_HOST=db
set METABASE_SOURCE_DB_PWD=%~1

:ask_password
:: If not provided via argument and still empty, ask the user
if "!METABASE_SOURCE_DB_PWD!"=="" (
    set /p METABASE_SOURCE_DB_PWD="Enter password for PostgreSQL user '!DB_USER!': "
    :: Check again; if user just pressed Enter, go back to the label
    if "!METABASE_SOURCE_DB_PWD!"=="" (
        echo [ERROR] Password cannot be empty.
        goto ask_password
    )
)
set METABASE_TARGET_DUMMY_PWD=dummy_password

:: --- Execution Section ---
:: Create output directory if it doesn't exist
if not exist "!OUTPUT_DIR!" (
    echo [ACTION] Creating missing directory: !OUTPUT_DIR!
    mkdir "!OUTPUT_DIR!"
    if errorlevel 1 (
        set "_EXIT_CODE=!errorlevel!"
        echo [ERROR] Failed to create output directory: !OUTPUT_DIR!
        goto end
    )
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
    set "_EXIT_CODE=!errorlevel!"
    echo [ERROR] pg_dump failed. Check if PostgreSQL is running and credentials are correct.
    goto end
)

:: Append a \connect command at the beginning of the file.
:: Since 00-init-dbs.sh creates the DB, 03 must ensure it switches to it.
echo \connect !DB_NAME! > "!OUTPUT_DIR!\temp_dump.sql"
if errorlevel 1 (
    set "_EXIT_CODE=!errorlevel!"
    echo [ERROR] Failed to write the temporary dump header.
    goto end
)
type "!OUTPUT_DIR!\!OUTPUT_FILE!" >> "!OUTPUT_DIR!\temp_dump.sql"
if errorlevel 1 (
    set "_EXIT_CODE=!errorlevel!"
    echo [ERROR] Failed to append the database dump to the temporary file.
    goto end
)
move /y "!OUTPUT_DIR!\temp_dump.sql" "!OUTPUT_DIR!\!OUTPUT_FILE!" > nul
if errorlevel 1 (
    set "_EXIT_CODE=!errorlevel!"
    echo [ERROR] Failed to replace the dump with the temporary file.
    goto end
)

echo [PROCESS] Sanitizing sensitive credentials...
:: Replace the plain text development password and host with the predefined target values
powershell -command "$ErrorActionPreference = 'Stop'; (get-content '!OUTPUT_DIR!\!OUTPUT_FILE!' -ErrorAction Stop) -replace '!METABASE_SOURCE_DB_PWD!', '!METABASE_TARGET_DUMMY_PWD!' | set-content '!OUTPUT_DIR!\!OUTPUT_FILE!' -ErrorAction Stop"
if errorlevel 1 (
    set "_EXIT_CODE=!errorlevel!"
    echo [ERROR] Failed to sanitize the database password in the dump.
    goto end
)
powershell -command "$ErrorActionPreference = 'Stop'; (get-content '!OUTPUT_DIR!\!OUTPUT_FILE!' -ErrorAction Stop) -replace '!METABASE_SOURCE_DB_HOST!', '!METABASE_TARGET_DB_HOST!' | set-content '!OUTPUT_DIR!\!OUTPUT_FILE!' -ErrorAction Stop"
if errorlevel 1 (
    set "_EXIT_CODE=!errorlevel!"
    echo [ERROR] Failed to sanitize the database host in the dump.
    goto end
)

echo.
echo [SUCCESS] Script '!OUTPUT_FILE!' generated and sanitized in '!OUTPUT_DIR!'.

:end
:: Restore the original environment variables and exit with the resulting exit code
endlocal & exit /b %_EXIT_CODE%