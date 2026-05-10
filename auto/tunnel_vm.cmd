:: auto/tunnel_vm.cmd
:: Purpose: Connect via SSH to the VM with radar-admin user and tunnel the ports to PostgreSQL/Metabase using
::  the local port 5433/3001 on your PC to avoid conflicts with if you have a local services running on those ports.

:: In PowerShell: $Home replaces %USERPROFILE% and ` replaces ^

:: ssh (secure shell): Tool for securely connecting to a remote server and executing commands
:: -i: identity file
:: -L: local port forwarding
:: 5433/3001: local port
:: 127.0.0.1:5432/3000: remote address and port (PostgreSQL/Metabase running on the VM)
:: -N: do not execute remote commands, just establish the tunnel
:: -v: verbose mode for debugging
:: user@host: remote user and host to be connected
ssh -i %USERPROFILE%\.ssh\radar_ed25519 -L 5433:127.0.0.1:5432 -L 3001:127.0.0.1:3000 -N radar-admin@%RadarIPAddress%