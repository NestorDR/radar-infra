:: auto/tf.cmd
:: Purpose: Orchestrate and automate the Terraform lifecycle commands (init, plan, apply, destroy)
:: Usage: auto/tf <command>
:: Example: auto/tf init

@echo off
cls

setlocal enabledelayedexpansion
set "_EXIT_CODE=0"
echo !DATE! !TIME!

:: Require invocation from this repository's root directory.
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
for %%I in ("%CD%") do set "CURRENT_DIR=%%~fI"
if /i not "!CURRENT_DIR!"=="!PROJECT_ROOT!" (
    echo Error: Run this script from the project root: "!PROJECT_ROOT!"
    set "_EXIT_CODE=1"
    goto end
)

:: Navigate to the target terraform directory relative to the script location
cd /d "!PROJECT_ROOT!\terraform"

:: Capture the target action command (init, plan, apply, etc.)
set TF_COMMAND=%1
if "!TF_COMMAND!"=="" (
    echo Error: Action parameter is required.
    echo Usage: %0 ^<command^>
    echo Valid values: init, plan, apply, destroy
    echo Example: %0 init
    cd /d "!PROJECT_ROOT!"
    set "_EXIT_CODE=1"
    goto end
)

:: Validate and execute the specific action
if /i "!TF_COMMAND!"=="init" (
    echo [INFO] Initializing Terraform working directory...
    terraform init
    goto command_result
)

:: Upgrade Terraform plugins and modules to the latest compatible versions
if /i "!TF_COMMAND!"=="upgrade" (
    echo [INFO] Updating Terraform working directory...
    terraform init -upgrade
    goto command_result
)

if /i "!TF_COMMAND!"=="plan" (
    echo [INFO] Generating and showing execution plan...
    terraform plan -out=tfplan
    goto command_result
)

if /i "!TF_COMMAND!"=="apply" (
    echo [INFO] Building or changing infrastructure state...
    :: If tfplan file exists, apply it directly without interactive prompt.
    :: Otherwise, run standard apply which asks for interactive confirmation.
    if exist tfplan (
        terraform apply "tfplan"
    ) else (
        terraform apply
    )
    goto command_result
)

if /i "!TF_COMMAND!"=="destroy" (
    echo [WARNING] Wiping all resources managed by this configuration...
    terraform destroy
    goto command_result
)

:: Invalid command
 echo Error: Invalid command "!TF_COMMAND!". Supported commands are: init, upgrade, plan, apply, destroy.
set "_EXIT_CODE=1"
goto go_project_root

:command_result
:: Preserve the Terraform command's result before other commands change ERRORLEVEL.
set "_EXIT_CODE=!errorlevel!"

if !_EXIT_CODE! neq 0 (
    echo [ERROR] Terraform !TF_COMMAND! failed with exit code !_EXIT_CODE!.
) else (
    echo [SUCCESS] Terraform !TF_COMMAND! completed successfully.
)
echo !DATE! !TIME!

:go_project_root
:: Navigate back to the project root directory
cd /d "!PROJECT_ROOT!"

:end
:: Restore the original environment variables and exit with the resulting exit code
endlocal & exit /b %_EXIT_CODE%