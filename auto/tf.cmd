:: auto/tf.cmd
:: Purpose: Orchestrate and automate the Terraform lifecycle commands (init, plan, apply, destroy)
:: Usage: auto/tf <command>
:: Example: auto/tf init
@ECHO OFF
CLS

SETLOCAL ENABLEDELAYEDEXPANSION
ECHO !DATE! !TIME!

:: Capture the script's origin directory to ensure backward navigation after executing Terraform commands
SET SCRIPT_DIR=%~dp0
:: Navigate to the target terraform directory relative to the script location
CD /D "!SCRIPT_DIR!..!\terraform"

:: Capture the target action command (init, plan, apply, etc.)
SET TF_COMMAND=%1
if "!TF_COMMAND!"=="" (
    ECHO Error: Action parameter is required.
    ECHO Usage: %0 ^<command^>
    ECHO Valid values: init, plan, apply, destroy
    ECHO Example: %0 init
    CD /D "!SCRIPT_DIR!..!"
    EXIT /B 1
)

:: Validate and execute the specific action
if /i "!TF_COMMAND!"=="init" (
    ECHO [INFO] Initializing Terraform working directory...
    terraform init
    GOTO end
)

:: Upgrade Terraform plugins and modules to the latest compatible versions
if /i "!TF_COMMAND!"=="upgrade" (
    ECHO [INFO] Updating Terraform working directory...
    terraform init -upgrade
    GOTO end
)

if /i "!TF_COMMAND!"=="plan" (
    ECHO [INFO] Generating and showing execution plan...
    terraform plan -out=tfplan
    GOTO end
)

if /i "!TF_COMMAND!"=="apply" (
    ECHO [INFO] Building or changing infrastructure state...
    :: If tfplan file exists, apply it directly without interactive prompt.
    :: Otherwise, run standard apply which asks for interactive confirmation.
    if exist tfplan (
        terraform apply "tfplan"
    ) else (
        terraform apply
    )
    GOTO end
)

if /i "!TF_COMMAND!"=="destroy" (
    ECHO [WARNING] Wiping all resources managed by this configuration...
    terraform destroy
    GOTO end
)

ECHO Error: Invalid command "!TF_COMMAND!". Supported commands are: init, plan, apply, destroy.
EXIT /B 1

:end
:: Capture execution status
SET EXIT_CODE=!errorlevel!

:: Navigate back to the project root directory
CD /D "!SCRIPT_DIR!..!"

if !EXIT_CODE! neq 0 (
    ECHO [ERROR] Terraform !TF_COMMAND! failed with exit code !EXIT_CODE!.
    EXIT /B !EXIT_CODE!
)

ECHO [SUCCESS] Terraform !TF_COMMAND! completed successfully.
ECHO !DATE! !TIME!
ENDLOCAL