#!/bin/bash

# LibreSpeed Setup Script for Ubuntu (Docker-Based)
# 
# Usage:
# 1. Make the script executable:
#    chmod +x install_librespeed.sh
#
# 2. Run the script:
#    sudo ./install_librespeed.sh
#
# 3. Access LibreSpeed at:
#    http://your-server-ip:8080
#

# Exit if any command fails
set -e

# Define variables
LIBRESPEED_DIR="$HOME/librespeed"
DOCKER_COMPOSE_FILE="$LIBRESPEED_DIR/docker-compose.yml"
LOG_FILE="$LIBRESPEED_DIR/install.log"

echo "Starting LibreSpeed setup..." | tee "$LOG_FILE"

# Update and install dependencies
echo "Updating system..." | tee -a "$LOG_FILE"
sudo apt update -y >> "$LOG_FILE" 2>&1

# Check if Docker is installed
if ! command -v docker &>/dev/null; then
    echo "Installing Docker..." | tee -a "$LOG_FILE"
    sudo apt install -y docker.io >> "$LOG_FILE" 2>&1
    sudo systemctl enable --now docker
else
    echo "Docker is already installed." | tee -a "$LOG_FILE"
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &>/dev/null; then
    echo "Installing Docker Compose..." | tee -a "$LOG_FILE"
    sudo apt install -y docker-compose >> "$LOG_FILE" 2>&1
else
    echo "Docker Compose is already installed." | tee -a "$LOG_FILE"
fi

# Add user to docker group (avoids needing sudo for docker)
if ! groups | grep -q "\bdocker\b"; then
    echo "Adding user to docker group..." | tee -a "$LOG_FILE"
    sudo usermod -aG docker "$USER"
    echo "You may need to log out and log back in for changes to take effect." | tee -a "$LOG_FILE"
fi

# Create LibreSpeed directory
mkdir -p "$LIBRESPEED_DIR"

# Create docker-compose.yml
cat <<EOF > "$DOCKER_COMPOSE_FILE"
version: "3.8"

services:
  librespeed:
    image: lscr.io/linuxserver/librespeed:latest
    container_name: librespeed
    restart: unless-stopped
    ports:
      - "8080:80"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
      - PASSWORD=changeme # Optional: Set a password for admin access
      - TELEMETRY=true     # Enable telemetry logging (optional)
      - DB_TYPE=sqlite     # Use SQLite for telemetry logging
    volumes:
      - ./config:/config
EOF

echo "Starting LibreSpeed with Docker Compose..." | tee -a "$LOG_FILE"
cd "$LIBRESPEED_DIR"
docker-compose up -d >> "$LOG_FILE" 2>&1

echo "LibreSpeed is now running!" | tee -a "$LOG_FILE"
echo "Access it at: http://$(hostname -I | awk '{print $1}'):8080" | tee -a "$LOG_FILE"
