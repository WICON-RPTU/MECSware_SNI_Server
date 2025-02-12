#!/bin/bash

# Usage:
# 1. Save this script as setup_routes.sh
# 2. Make it executable: chmod +x setup_routes.sh
# 3. Run it with sudo: sudo ./setup_routes.sh
#
# This script sets up static routes and a static IP on a Raspberry Pi.
# If eth0 is not available, the script will prompt for an alternative interface.
# The user can also specify an IP address within the 10.0.3.xxx range.

# Function to prompt for an interface if eth0 is not found
get_interface() {
    local interface
    interface=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n 1)
    
    if [[ "$interface" == "" ]]; then
        echo "No network interfaces found! Exiting."
        exit 1
    fi

    echo "Available interfaces:"
    ip -o link show | awk -F': ' '{print $2}' | grep -v lo
    read -p "Enter the interface to use (default: $interface): " input_iface
    
    [[ -z "$input_iface" ]] && input_iface="$interface"
    echo "$input_iface"
}

# Check if eth0 exists, otherwise ask for interface
if ip link show eth0 > /dev/null 2>&1; then
    INTERFACE="eth0"
else
    INTERFACE=$(get_interface)
fi

echo "Using interface: $INTERFACE"

# Prompt for an IP in the 10.0.3.xxx range
read -p "Enter a static IP in the 10.0.3.xxx range (default: 10.0.3.100): " STATIC_IP
[[ -z "$STATIC_IP" ]] && STATIC_IP="10.0.3.100"

echo "Setting static IP: $STATIC_IP on $INTERFACE"

# Backup dhcpcd.conf before modifying it
cp /etc/dhcpcd.conf /etc/dhcpcd.conf.bak

echo "
interface $INTERFACE
static ip_address=$STATIC_IP/24
static routers=10.0.3.1
static domain_name_servers=8.8.8.8 8.8.4.4
" | tee -a /etc/dhcpcd.conf

# Restart networking service to apply changes
systemctl restart dhcpcd

# Add routes
ip route add 10.0.1.2 dev $INTERFACE
ip route add 10.0.3.0/24 dev $INTERFACE
ip route add 10.0.5.0/24 via 10.0.3.4 dev $INTERFACE
ip route add 10.0.5.0/24 via 10.0.1.2 dev $INTERFACE

echo "Routes added successfully."

# Persist routes in /etc/rc.local (before exit 0)
if ! grep -q "ip route add" /etc/rc.local; then
    sed -i '/^exit 0/i \
ip route add 10.0.1.2 dev '$INTERFACE'\
ip route add 10.0.3.0/24 dev '$INTERFACE'\
ip route add 10.0.5.0/24 via 10.0.3.4 dev '$INTERFACE'\
ip route add 10.0.5.0/24 via 10.0.1.2 dev '$INTERFACE'\
' /etc/rc.local
fi

echo "Routes persisted in /etc/rc.local."

# Display network configuration
ip addr show $INTERFACE
ip route show
