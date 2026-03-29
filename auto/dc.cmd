:: auto/dc.cmd
:: Script to start the Docker Compose environment for a specific deployment environment: dev, e2e
:: Usage: auto/dc <target_deploy>
@ECHO OFF

:: Enable `delayed expansion` to handle environment variables correctly within blocks
SETLOCAL ENABLEDELAYEDEXPANSION
ECHO !DATE! !TIME!

:: Get the directory where the script is located
SET SCRIPT_DIR=%~dp0
:: Ensure we are executing from the project root (one level up from /auto)
CD /D "!SCRIPT_DIR!..!"

:: Capture 1st argument as target deployment environment
SET TARGET_DEPLOY=%1
if "!TARGET_DEPLOY!"=="" (
    ECHO Parameter is required. Usage: %0 ^<target_deploy^>
    ECHO Valid values for target_deploy: dev, e2e
    ECHO Example: %0 dev
    exit /b
)

:: Make sure to use lowercase letters, as docker-compose is case-sensitive
:: /i : Case insensitive
if /i "!TARGET_DEPLOY!"=="dev" (
    SET TARGET_DEPLOY=
    SET TARGET_DEPLOY=dev
)
if /i "!TARGET_DEPLOY!"=="e2e" (
    SET TARGET_DEPLOY=
    SET TARGET_DEPLOY=e2e
)
ECHO Do you want to delete the subfolder database\docker_volume and all its contents?
CHOICE /C YN /M "Press Y for YES or N for NO"
IF !errorlevel! equ 1 (
    ECHO Deleting database\docker_volume and its contents...
    docker volume rm radar_pg_data
    RMDIR /S /Q database\docker_volume
)

:compose
:: DOCKER-COMPOSE
:: Visit: https://docs.docker.com/reference/cli/docker/compose/up/

:: FLAGS EXPLANATION:
:: Only Build
:: build ..........: builds images before starting containers
:: --no-cache .....: to force rebuild
:: ^  : newline
:: && : starts next command if the previous one ended successfully
:: ```cmd
:: docker compose -f docker/docker-compose.!TARGET_DEPLOY!.yml build --no-cache ^
:: && docker compose ... up
:: ```

:: Build and launch all services as detached
:: -f .............: to specify a particular compose file .yml
:: -p .............: to add an isolated specific project name
:: up .............: to raise the services defined in the .yml file
:: --env-file .....: to inject the environment variables from a specific file
:: -d .............: to run in background (detached mode), visible in Docker Desktop
:: --build ........: reconstructs images if it detects changes in the build context or the Dockerfile
:: --force-recreate: ensures that containers are created again (stops and removes existing containers and creates new ones)
:: %* .............: for extra arguments

docker compose --env-file envs/.env.!TARGET_DEPLOY! -f docker-compose.!TARGET_DEPLOY!.yml -p radar-!TARGET_DEPLOY! up -d --build

:: Check if the command was successful
IF !errorlevel! neq 0 (
    ECHO [ERROR] Docker Compose for !TARGET_DEPLOY! Environment failed to start.
    EXIT /b !errorlevel!
)

ECHO [SUCCESS] !TARGET_DEPLOY! Environment is up.
ECHO Access Metabase at http://localhost:3000
ECHO !DATE! !TIME!

ENDLOCAL
