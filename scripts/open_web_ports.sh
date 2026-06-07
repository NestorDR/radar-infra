#!/bin/bash

# scripts/open_web_ports.sh
# Purpose: Open HTTP and HTTPS ports on the server firewall (UFW) to allow web traffic to reach the Caddy reverse proxy.
# Usage: ./open_web_ports.sh

# Purpose: Open HTTP port on the server firewall (UFW)
sudo ufw allow 80/tcp

# Purpose: Open HTTPS port on the server firewall (UFW)
sudo ufw allow 443/tcp
