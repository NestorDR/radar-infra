:: auto/vm.cmd
:: Purpose: Connect to the VM via SSH with radar-admin user

:: $Home replaces %USERPROFILE% in PowerShell

:: ssh (secure shell): Tool for securely connecting to a remote server and executing commands
:: -i: identity file
ssh -i %USERPROFILE%\.ssh\radar_ed25519 radar-admin@%RadarIPAddress%