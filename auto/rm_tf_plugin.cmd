:: auto/rm_tf_plugin.cmd
:: Purpose:
:: Usage:

set "_EXIT_CODE=0"

:: Require invocation from this repository's root directory.
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
for %%I in ("%CD%") do set "CURRENT_DIR=%%~fI"
if /i not "!CURRENT_DIR!"=="!PROJECT_ROOT!" (
    echo Error: Run this script from the project root: "!PROJECT_ROOT!"
    set "_EXIT_CODE=1"
    goto end
)

:: Remove the Terraform add-ons and cached status files to be able to reset a clean state
rmdir /s /q .terraform
del .terraform.lock.hcl
del terraform.tfstate
del terraform.tfstate.backup

:end
exit /b %_EXIT_CODE%