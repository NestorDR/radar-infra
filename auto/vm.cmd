:: auto/vm.cmd
:: Purpose: Connect to the VM via SSH with radar-admin user
:: Usage: auto\vm.cmd

cls
@echo off

:: In PowerShell: $Home replaces %USERPROFILE% and ` replaces ^

if not defined RadarIPAddress (
    echo Error: RadarIPAddress is not set.
    exit /b 1
)

if not exist "%USERPROFILE%\.ssh\radar_ed25519" (
    echo Error: SSH identity file was not found: "%USERPROFILE%\.ssh\radar_ed25519"
    exit /b 1
)

echo on

:: ssh (secure shell): Tool for securely connecting to a remote server and executing commands
:: -i: identity file
ssh -i %USERPROFILE%\.ssh\radar_ed25519 radar-admin@%RadarIPAddress%
@exit /b %ERRORLEVEL%