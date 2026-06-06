# Deployment on Hetzner Cloud: Step-by-Step Guide

## Stage 1: Isolation and Validation (Core & Backend)

**Objective:** Verify that the database persists, that `radar-core` is correctly executed via `systemd` scheduling, and that Metabase can read the data.

### Technical Actions

**1. Provisioning: Create a VM on Hetzner Cloud (CX33 instance, Debian 13)**

**1.1.** Create an SSH security key on the local workstation (Windows/Mac/Linux) to allow passwordless access to the Hetzner VM. This is fundamental for the security and convenience of server administration.

   - Standard command to generate SSH key pairs: `ssh-keygen`. In this case, it is recommended to use the Ed25519 algorithm for its security and performance.
   ```powershell
   # -t (type): Mathematical algorithm type to be used to generate the key.
   # -f (file): Destination file
   # -C (comment): Comment to identify the key, useful for future administration
   ssh-keygen -t ed25519 -f "$home\.ssh\radar_ed25519" -C "<SSH_KEY_COMMENT>"
   ```
   - View and copy with Notepad, or copy with the command:
   ```powershell
   Get-Content "$home\.ssh\radar_ed25519.pub" | Set-Clipboard
   ```

**1.2.** Create an account on [Hetzner Cloud](https://accounts.hetzner.com/signUp).

   - user: <HETZNER_USERNAME>

**1.3.** Provision a VM on Hetzner Cloud.

   - Type CX33: VCPUs: 4 Intel/AMD, RAM: 8 GB, SSD: 80 GB, Transfer: 20 TB
   - Location: Helsinki, Finland.
   - Image: Debian 13.
   - Networking: IPv4 & IPv6. Final result <SERVER_IP> and <SERVER_IPV6>.
   - SSH Keys: paste the SSH security key created in step 1.
   - Firewall: To be configured.
   - Backup: Ignored, snapshots will be used.
   - Labels: env:prod
   - Name: radar-prod

**1.4.** Initial connection as `root` on the VM.

   - Connect with the command:
   ```powershell
   # i (identity file): specifies the path of the private SSH key to authenticate on the remote server.
   # root@<SERVER_IP>: root user and public IP address of the Hetzner VM.
   ssh -i "C:/Users/<LOCAL_USER>/.ssh/radar_ed25519" root@<SERVER_IP> 
   ```

   - It will prompt and request:
   ```console
   The authenticity of host '<SERVER_IP> (<SERVER_IP>)' can't be established.
   ED25519 key fingerprint is SHA256:<KEY_FINGERPRINT>.
   This key is not known by any other names.
   Are you sure you want to continue connecting (yes/no/[fingerprint])? 
   ```
   Type `yes` to accept the connection and add the server's key to the Windows `known_hosts` file.
   If a password (*passphrase*) was used to create the key, it will be requested here.

**1.5.** Create a `radar-admin` user to manage the server securely without using `root` directly. This is a good security practice to minimize risks in case of compromise.
   ```bash
   adduser radar-admin
   ```
   It will ask for a password for this user and a few questions like Name, Phone, etc. Press `Enter` on all of them to leave them blank and finally press `Y` to confirm.

**1.6.** Grant administrator permissions (sudo), the full command includes:
   ```bash
   # usermod (user modify): modifies an existing user
   # -a (append): add the user to the supplementary group(s) without removing them from other groups
   # G sudo (Groups): add to the `sudo` group (administrators group)
   usermod -aG sudo radar-admin
   ```

**1.7.** Transfer the SSH key to the new user, log in directly using the same Windows key:
   ```bash
   # Create the SSH keys directory for the new user
   # -p (parents): creates the directory and any necessary parent directories
   # /home/radar-admin/.ssh: path of the SSH keys directory for the new user
   mkdir -p /home/radar-admin/.ssh
   
   # Copy the server's security key to the new user
   cp /root/.ssh/authorized_keys /home/radar-admin/.ssh/
   
   # chown: changes the ownership of a file or directory
   # -R (recursive): to apply to all files within the directory
   # radar-admin:radar-admin (user:group): Debian creates User X and automatically the User Private Group (UPG) X with that single user as a member. 
   # /home/radar-admin/.ssh: directory path to modify
   chown -R radar-admin:radar-admin /home/radar-admin/.ssh
   
   # chmod: changes access permissions
   # 700 (rwx------): owner (1*4.read + 1*2.write + 1*1.execute) = 7, group (0*4.read + 0*2.write + 0*1.execute) = 0, others (0*4.read + 0*2.write + 0*1.execute) = 0
   chmod 700 /home/radar-admin/.ssh
   # 600 (rw-------): owner (1*4.read + 1*2.write + 0*1.execute) = 6, group (0*4.read + 0*2.write + 0*1.execute) = 0, others (0*4.read + 0*2.write + 0*1.execute) = 0 = 
   chmod 600 /home/radar-admin/.ssh/authorized_keys
   ```

**1.8.** Log out: `Ctrl + D`

**1.9.** Connect as `radar-admin` on the VM.
   ```powershell
   ssh -i "C:\Users\<LOCAL_USER>\.ssh\radar_ed25519" radar-admin@<SERVER_IP> 
   ```

**2. Hardening: Configure the firewall (UFW) to allow ONLY port 22 (TCP/SSH)**.

**2.1.** Verify the contents of the `/etc/ssh/sshd_config` file (main configuration of the SSH service) looking for `PermitRootLogin` and `PasswordAuthentication` directives that control direct access to the root user and the ability to authenticate using passwords, which is a security risk if left enabled.
   ```bash
   # grep (Global Regular Expression Print): search for lines that match a pattern within files or command outputs
   # -i (case-insensitive): ignores uppercase/lowercase
   # -E (extended regular expression): allows the use of extended regular expressions for more complex patterns
   # PermitRootLogin|PasswordAuthentication: looks for lines containing either of these two directives
   grep -iE "PermitRootLogin|PasswordAuthentication" /etc/ssh/sshd_config
   ```
   
**2.2.** Harden. Disable root access via SSH and disable password authentication.
   ```bash
   # sed (Stream EDitor): edit text in a file from the command line
   # -i (In-place): modifies the file directly
   # 's/^SEARCHED.*/REPLACEMENT/'
   # 		s: substitute
   # 		/: initial delimiter of the pattern
   # 		^: beginning of a line in the file to edit
   # 		[# ]: Searches for the character # or a blank space.
   # 		*: zero or more times
   # 		SEARCHED: exact text you want to find within the line
   # 		.: any subsequent character
   # 		*: to the end regardless of length (zero or more times)
   # 		REPLACEMENT: new replacement text
   # 		/: final delimiter of the pattern
   
   
   # sudo: executes the command with administrator privileges
   # 's/^#PermitRootLogin.*/PermitRootLogin no/': replaces the commented PermitRootLogin line with "PermitRootLogin no"
   sudo sed -i 's/^[# ]*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
   
   # 's/^#PasswordAuthentication.*/PasswordAuthentication no/': replaces the commented PasswordAuthentication line with "PasswordAuthentication no"
   sudo sed -i 's/^[# ]*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
   
   # systemctl: manages system services
   # restart: restarts the service
   # sshd: OpenSSH service in Debian
   sudo systemctl restart ssh
   ```

**2.3.** Configure Firewall to allow only port 22 (SSH)
   ```bash
   # apt (Advanced Packaging Tool): package management tool and derivatives
   # update: updates the list of available packages
   sudo apt update
   
   # install: installs packages
   # ufw (Uncomplicated Firewall): target package to update
   # -y: automatically answers yes to confirmation
   sudo apt install ufw -y
   
   # ufw: configures policy in firewall
   # default: default policy to be applied to whatever does not have a specific rule
   # deny incoming: blocks any incoming traffic
   sudo ufw default deny incoming
   
   # default allow outgoing: allows any outgoing traffic by default
   sudo ufw default allow outgoing
   
   # allow ssh: allows SSH connections by service name
   sudo ufw allow ssh
   
   # Alternative: sudo ufw allow 22/tcp: allows TCP connections to port 22 (SSH)
   
   # ufw enable: activates the firewall
   sudo ufw enable
   
   # ufw status: shows the current firewall status and configured rules
   sudo ufw status
   ```
   `ufw enable` might prompt: `Command may disrupt existing ssh connections. Proceed with y/n?`. Type `y` and press `Enter`. After executing `allow ssh` you are safe.

**3. Install Docker and prepare directory structure**

**3.1.** Install Docker and grant user permissions.
   ```bash
   # Install necessary dependencies
   # sudo: executes the command with administrator privileges
   # apt update: updates the list of available packages
   # &&: executes the next command only if the previous one was successful
   # apt install: installs packages
   # -y: automatically answers yes to confirmation
   # ca-certificates: root certificates to validate HTTPS connections
   # curl: tool to download content from a URL
   # gnupg: utilities to manage and verify GPG (GNU Privacy Guard) signatures generated with private keys. 
   sudo apt update && sudo apt install -y ca-certificates curl gnupg
   
   # Add Docker's official GPG key
   # install: creates directories or installs files
   # -m (mode): assigns permissions to the created directory
   # 755 (rwxr-xr-x): owner (1*4.read + 1*2.write + 1*1.execute) = 7, group (1*4.read + 0*2.write + 1*1.execute) = 5, others (1*4.read + 0*2.write + 1*1.execute) = 5
   # -d: indicates that a directory will be created
   # /etc/apt/keyrings: folder where repository keys are stored
   sudo install -m 755 -d /etc/apt/keyrings
   
   # curl: downloads content from a URL
   # -f (fail): fails if the download returns an HTTP error
   # -sS (silent, show errors): silent mode, but showing errors if they occur
   # -L (location): follows redirects
   # -o (output): saves the output to a file
   # /etc/apt/keyrings/docker.asc: file where the key is stored
   sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
   
   # chmod: changes permissions of a file
   # a+r (all users read): adds read permission for all users
   # /etc/apt/keyrings/docker.asc: downloaded GPG key
   sudo chmod a+r /etc/apt/keyrings/docker.asc
   
   # Configure the repository
   # echo: prints the repository line
   # deb: entry format for an APT repository
   # [arch=$(dpkg --print-architecture)]: uses the system architecture
   # signed-by=/etc/apt/keyrings/docker.asc: uses that key to validate the repository
   # https://download.docker.com/linux/debian: Docker repository URL for Debian
   # $(. /etc/os-release && echo "$VERSION_CODENAME"): inserts the codename of the Debian version
   # stable: stable branch of the repository
   # tee: writes the output to a file
   # /etc/apt/sources.list.d/docker.list: file where the repository is saved
   # > /dev/null: discards the output shown by tee on screen
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   
   # Update the package list
   sudo apt-get update
   
   # Install Docker and the Compose plugin
   # apt-get install: installs packages
   # docker-ce: Docker Community Edition engine
   # docker-ce-cli: Docker command line client
   # containerd.io: container runtime
   # docker-buildx-plugin: support for advanced builds
   # docker-compose-plugin: support for integrated Compose
   # -y: automatically answers yes to confirmation
   sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
   
   # Add user to the docker group to avoid using sudo with Docker
   # usermod: modifies an existing user
   # -a: append without removing other groups
   # G docker: adds to the docker group
   # radar-admin: user to be modified
   sudo usermod -aG docker radar-admin
   ```
   For the Docker permission to apply, exit the server (`Ctrl + D`) and log back in via SSH.


**3.2.** Create the folder structure to support Docker containers.
   ```bash
   # Create folder structure.  
   # mkdir: creates a directory
   # -p (parents): creates the directory and any necessary parent directories
   # /opt/radar/infra/*: path of the directory to create
   sudo mkdir -p /opt/radar/infra/config
   sudo mkdir -p /opt/radar/infra/database/init
   sudo mkdir -p /opt/radar/infra/database/data
   sudo mkdir -p /opt/radar/infra/envs
   sudo mkdir -p /opt/radar/infra/logs
   sudo mkdir -p /opt/radar/infra/scripts
   ```
   If the folder structure already exists and the Docker services have been started before, it is possible that the `data` folder already has files created by PostgreSQL, which would have claimed ownership of the `data` folder. 
   You can choose to delete everything created previously (if there is no important data to preserve). This step can be run with the bash automation script [infra_01_of_05_cleanup.sh](../scripts/infra_01_of_05_cleanup.sh). If the deletion of the `data` folder is denied due to lack of permissions, and you still want to delete it, you can use `sudo chown` to force ownership and then delete.

**4. **Deployment: Upload files (`docker-compose.prod.yml` and relates) and deploy.**

**4.1.** From the **local machine** copy the files to the **VPS** using `scp`:
   ```powershell
   # $home replaces %USERPROFILE% in PowerShell
   
   # scp (secure copy): tool to securely copy files between hosts on a network
   # -i (identity file): specifies the path of the private SSH key to authenticate on the remote server
   # docker-compose.prod.yml envs/.env.prod ...: local files to copy
   # radar-admin@<SERVER_IP>: The destination (who and where).
   # :/opt/radar/infra: absolute path on the server where files will be copied
   scp -i $home\.ssh\radar_ed25519 docker-compose.prod.yml radar-admin@<SERVER_IP>:/opt/radar/infra
   scp -i $home\.ssh\radar_ed25519 ../radar-core/src/radar_core/settings.dev.yml radar-admin@<SERVER_IP>:/opt/radar/infra/config/settings.yml
   scp -i $home\.ssh\radar_ed25519 database/init/* radar-admin@<SERVER_IP>:/opt/radar/infra/database/init
   scp -i $home\.ssh\radar_ed25519 envs/.env.prod radar-admin@<SERVER_IP>:/opt/radar/infra/envs
   scp -i $home\.ssh\radar_ed25519 scripts/* radar-admin@<SERVER_IP>:/opt/radar/infra/scripts
   scp -i $home\.ssh\radar_ed25519 systemd/* radar-admin@<SERVER_IP>:/opt/radar/infra
   
   # Verify result via ssh
   # -i (identity file): specifies the path of the private SSH key to authenticate on the remote server.
   # radar-admin@<SERVER_IP>: user and public IP address of the Hetzner VM.
   # ls: shows the contents of a directory
   # -l (long listing): shows details such as permissions, owner, size and modification date
   # a (all): includes hidden files (those starting with a dot)
   # R (recursive): shows the contents of subdirectories as well
   # --ignore='data': skips showing the 'data' folder to avoid displaying the extensive list of database files (if already created)
   ssh -i $home\.ssh\radar_ed25519 radar-admin@<SERVER_IP> "ls -laR --ignore='data' /opt/radar/infra/"
   ```
   This step can be run with the cmd automation script [infra_02_of_05_deploy.cmd](../auto/infra_02_of_05_deploy.cmd).

**4.2.** On the VM assign ownership and permissions to the copied files so the system functions correctly.
   ```bash
   # Assign ownership of the created folders to the radar-admin user.
   # chown: changes the ownership of a file or directory
   # -R (recursive): to apply to all directories and files within the directory
   # radar-admin:radar-admin: assigns ownership to the radar-admin user and group
   # /opt/radar: directory path to modify
   sudo chown -R radar-admin:radar-admin /opt/radar
   # NEW: sudo find /opt/radar -path /opt/radar/infra/database/data -prune -o -exec chown radar-admin:radar-admin {} +   
   
   # Assign standard read/write/access permissions to folders and files within /opt/radar.
   # find: traverses /opt/radar and all its subdirectories (-type d) and then chmod ...
   # chmod: applies standard read/write permissions
   # 755 (rwxr-xr-x): owner (1*4.read + 1*2.write + 1*1.execute) = 7, group (1*4.read + 0*2.write + 1*1.execute) = 5,others (1*4.read + 0*2.write + 1*1.execute) = 5 
   find /opt/radar -type d -exec chmod 755 {} +
   # NEW: sudo find /opt/radar -path /opt/radar/infra/database/data -prune -o -type d -exec chmod 755 {} +
   
   # find: searches for regular files (-type f) in /opt/radar and then chmod ...
   # chmod: applies standard read/write permissions
   # 644 (rw-r--r--): owner (1*4.read + 1*2.write + 0*1.execute) = 6, group (1*4.read + 0*2.write + 0*1.execute) = 4, others (1*4.read + 0*2.write + 0*1.execute) = 4
   find /opt/radar -type f -exec chmod 644 {} +
   # NEW: sudo find /opt/radar -path /opt/radar/infra/database/data -prune -o -type f -exec chmod 644 {} +
      
   # Protect the secrets file
   # Secrets hardening (Prioritize Security)
   # find: searches for files starting with .env and then chmod ...
   # chmod: applies read/write permissions only for the owner
   # 600 (rw-------): owner (1*4.read + 1*2.write + 0*1.execute) = 6, group (0*4.read + 0*2.write + 0*1.execute) = 0, others (0*4.read + 0*2.write + 0*1.execute) = 0
   find /opt/radar -name ".env*" -exec chmod 600 {} +

   # When executing 'docker compose up', Docker will give the necessary access to Postgres to the '/opt/radar/infra/database/data' folder.
   # The only thing Postgres requires is that the 'data' folder is EMPTY the first time or that it has write permissions for the container.
   
   # Grant execution (critical for the system to work)
   # Container orchestration scripts
   sudo chmod +x /opt/radar/infra/scripts/*.sh
   # DB initialization scripts
   sudo chmod +x /opt/radar/infra/database/init/*.sh
   
   # Copy the radar-core.service and radar-core.timer files to the systemd folder
   # mv: moves files or directories from one location to another
   sudo cp /opt/radar/infra/systemd/radar-core.{service,timer} /etc/systemd/system/
   # Set owner to root (security standard for system services)
   sudo chown root:root /etc/systemd/system/radar-core.{service,timer}
   # Adjust permissions (read for all, write only root)
   # chmod: applies standard read/write permissions
   # 644 (rw-r--r--): owner (1*4.read + 1*2.write + 0*1.execute) = 6, group (1*4.read + 0*2.write + 0*1.execute) = 4, others (1*4.read + 0*2.write + 0*1.execute) = 4
   sudo chmod 644 /etc/systemd/system/radar-core.*
   
   # ls: shows the contents of a directory
   # -l (long listing): shows details such as permissions, owner, size and modification date
   # -a (all): includes hidden files (those starting with a dot)
   # -R (recursive): shows the contents of subdirectories as well
   # --ignore='data': skips showing the 'data' folder to avoid displaying the extensive list of database files (if already created)
   ls -laR --ignore='data' /opt/radar/infra/
   ```
   This step can be run with the bash automation script [infra_03_of_05_config.sh](../scripts/infra_03_of_05_config.sh).
 
**4.3.** Start the services and monitor their initialization
   ```bash
   cd /opt/radar/infra

   # docker compose: Start containers (with persistent services: PostgreSQL and Metabase)
   # --env-file: injects environment variables from a specific file
   # -f: specifies a particular .yml composition file
   # -p: adds a specific isolated project name
   # up: starts the services defined in the .yml file
   # -d (detached mode): runs in the background
   docker compose --env-file envs/.env.prod -f docker-compose.prod.yml -p radar-core up -d
   
   # Validate the status of the containers
   docker compose -f docker-compose.prod.yml ps
   ```
   This step can be run with the bash automation script [infra_04_of_05_dc.sh](../scripts/infra_04_of_05_dc.sh)
   
   During the execution of `docker compose ... up -d`, monitor the initialization in another open terminal:
   ```bash
   # Monitor the creation of the radar and metabase databases
   # -f (follow): to keep showing new logs in real time
   docker logs -f radar-postgres
   ```
   ```bash
   # Monitor metabase
   docker logs -f radar-metabase
   ```

**4.4.** Verify the creation of the `radar` and `metabase` databases within the PostgreSQL container.
   ```bash
   # Execute a command inside the PostgreSQL container to list the databases
   # docker exec: executes a command inside a running container
   # -it (interactive and tty) : to interact with the container's terminal
   # radar-postgres: name of the PostgreSQL container
   # psql: command line client for PostgreSQL
   # -U postgres: connects as postgres user (administrator)
   # -c (command): allows executing an SQL command directly from the command line without entering the interactive psql shell
   # \l: psql command to list all available databases
   docker exec -it radar-postgres psql -U postgres -c "\l"
   
   # Verify the schema of the `radar` database
   # d (database): specifies the database psql will connect to
   # \dt: psql command to list tables in the current database
   docker exec -it radar-postgres psql -U postgres -d radar -c "\dt"
   ```
   
**5. Schedule the engine by enabling systemd `.service` and `.timer` files and validate execution logs via `journalctl`.**

**5.1.** Enable the timer to execute `radar-core` according to the schedule defined in `radar-core.timer`.
   ```bash
   # Notify systemd that service files have been added or modified
   sudo systemctl daemon-reload
   # Ensure that the radar-core timer starts automatically on system boot
   sudo systemctl enable radar-core.timer
   # Start the timer immediately to schedule the execution of the radar-core service according to the defined schedule
   sudo systemctl start radar-core.timer
   # Verify the status of the timer to confirm it is active and scheduled correctly
   systemctl list-timers --all | grep radar-core
   
   # Add user to the systemd-journal group to read system logs (journalctl) without using sudo
   # usermod: modifies an existing user
   # -a: append without removing other groups
   # G systemd-journal: adds to the systemd-journal group
   # radar-admin: user to be modified
   sudo usermod -aG systemd-journal radar-admin
   ```
   For the `systemd-journal` permission to apply, exit the server (`Ctrl + D`) and log back in via SSH.
   
   If in step 4.2 you executed [infra_03_of_05_config.sh](../scripts/infra_03_of_05_config.sh), the service and timer should already be enabled and started.
 
**5.2.** To validate that everything (Docker, Network, Database, Permissions, Settings) works, trigger the engine:
   ```bash
   # Launch the calculation process
   # systemctl: manages system services
   # start: starts the service
   sudo systemctl start radar-core.service
   ```
   To monitor the execution and review the logs of the `radar-core` service:
   ```bash
   # journalctl: tool to view system logs managed by systemd
   # -u (unit): filters the logs by the service unit name
   # radar-core.service: name of the service to monitor
   # -f (follow): to keep showing new logs in real time
   journalctl -u radar-core.service -f
   ```
   This step can be run with the bash automation script [infra_05_of_05_validate.sh](../scripts/infra_05_of_05_validate.sh).

**6. Access services (PostgreSQL and Metabase) by creating an SSH Tunnel from the local machine** 
   ```PowerShell
   ssh -i $home\.ssh\radar_ed25519 -L 5433:127.0.0.1:5432 -L 3001:127.0.0.1:3000 -N radar-admin@<SERVER_IP>
   ```

### Automation Summary
- [infra_01_of_05_cleanup.sh](../scripts/infra_01_of_05_cleanup.sh)
- [infra_02_of_05_deploy.cmd](../auto/infra_02_of_05_deploy.cmd)
- [infra_03_of_05_config.sh](../scripts/infra_03_of_05_config.sh)
- [infra_04_of_05_dc.sh](../scripts/infra_04_of_05_dc.sh)
- [infra_05_of_05_validate.sh](../scripts/infra_05_of_05_validate.sh)
