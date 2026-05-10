:: auto/infra_02_of_05_deploy.cmd

:: In PowerShell: $Home replaces %USERPROFILE%

@if "%RadarIPAddress%"=="" echo [ERROR]: RadarIPAddress undefined & exit /b.

:: Copy local files to the VPS (VM) in Hetzner
:: scp (secure copy): Tool for securely copying files between hosts on a network
:: -i (identity file): Specifies the path to the SSH private key for authenticating to the remote server
:: database/init/*: Local files to copy
:: radar-admin@%RadarIPAddress%: The destination (who and where).
:: :/opt/radar/infra: Absolute path on the server where the files will be copied
scp -i %USERPROFILE%\.ssh\radar_ed25519 docker-compose.prod.yml radar-admin@%RadarIPAddress%:/opt/radar/infra
scp -i %USERPROFILE%\.ssh\radar_ed25519 ../radar-core/src/radar_core/settings.dev.yml radar-admin@%RadarIPAddress%:/opt/radar/infra/config/settings.yml
scp -i %USERPROFILE%\.ssh\radar_ed25519 database/init/* radar-admin@%RadarIPAddress%:/opt/radar/infra/database/init
scp -i %USERPROFILE%\.ssh\radar_ed25519 envs/.env.prod radar-admin@%RadarIPAddress%:/opt/radar/infra/envs
scp -i %USERPROFILE%\.ssh\radar_ed25519 scripts/* radar-admin@%RadarIPAddress%:/opt/radar/infra/scripts
scp -i %USERPROFILE%\.ssh\radar_ed25519 systemd/* radar-admin@%RadarIPAddress%:/opt/radar/infra/systemd

:: Verify results via SSH
:: ssh (secure shell): Tool for securely connecting to a remote server and executing commands
:: -i (identity file): Specifies the path to the SSH private key for authenticating to the remote server.
:: radar-admin@%RadarIPAddress%: Username and public IP address of the VPS in Hetzner.
:: ls: Displays the contents of a directory
:: -l (long listing): Displays details such as permissions, owner, size, and modification date
:: a (all): Includes hidden files (those that begin with a dot)
:: R (recursive): Displays the contents of subdirectories as well
:: --ignore='data': excludes the 'data' directory from the listing to avoid cluttering the output with potentially large files
ssh -i %USERPROFILE%\.ssh\radar_ed25519 radar-admin@%RadarIPAddress% "ls -laR --ignore='data' /opt/radar/infra/"

:: Then, in the VPS's BASH console
:: sudo chmod +x /opt/radar/infra/scripts/apply-infra-config.sh
:: /opt/radar/infra/scripts/apply-infra-config.sh