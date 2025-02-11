#!/bin/bash

# Usage:
# chmod +x configure_network.sh
# sudo ./configure_network.sh

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try: sudo $0"
   exit 1
fi

NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"

echo "Creating Netplan configuration..."

# Write the Netplan configuration
cat <<EOF > $NETPLAN_FILE
network:
  version: 2
  ethernets:
    enp2s0:
      dhcp4: no
      addresses:
        - 10.0.3.1/24
      gateway4: 10.0.3.1
      routes:
        - to: 10.0.1.2/32
          via: 0.0.0.0
        - to: 10.0.3.0/24
          via: 0.0.0.0
        - to: 10.0.5.0/24
          via: 10.0.3.4
        - to: 10.0.5.0/24
          via: 10.0.1.2
EOF

echo "Applying Netplan configuration..."
sudo netplan apply

# Enable IP forwarding if needed
SYSCTL_CONF="/etc/sysctl.conf"
echo "Enabling IP forwarding..."

if ! grep -q "net.ipv4.ip_forward=1" "$SYSCTL_CONF"; then
    echo "net.ipv4.ip_forward=1" >> "$SYSCTL_CONF"
fi

sysctl -p

echo "Network configuration has been updated successfully."
