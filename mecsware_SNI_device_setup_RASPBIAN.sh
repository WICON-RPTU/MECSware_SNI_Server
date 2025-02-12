#!/bin/bash

# Usage:
# 1. Save this script as setup_routes.sh
# 2. Make it executable: chmod +x setup_routes.sh
# 3. Run it with sudo: sudo ./setup_routes.sh
#
# This script sets up static routes and a static IP on a Raspberry Pi.
# It detects the active network manager (NetworkManager, systemd-networkd, or dhcpcd)
# and configures the network accordingly.

# Function to detect the active network manager
detect_network_manager() {
    if systemctl is-active --quiet NetworkManager; then
        echo "NetworkManager"
    elif systemctl is-active --quiet systemd-networkd; then
        echo "systemd-networkd"
    elif systemctl is-active --quiet dhcpcd; then
        echo "dhcpcd"
    else
        echo "unknown"
    fi
}

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

NETWORK_MANAGER=$(detect_network_manager)
echo "Detected network manager: $NETWORK_MANAGER"

if [[ "$NETWORK_MANAGER" == "NetworkManager" ]]; then
    # Check if the connection exists
    if ! nmcli con show "$INTERFACE" > /dev/null 2>&1; then
        echo "NetworkManager connection for $INTERFACE does not exist. Creating one..."
        nmcli con add type ethernet ifname $INTERFACE con-name $INTERFACE
    fi
    # Configure static IP using NetworkManager
    nmcli con mod $INTERFACE ipv4.addresses $STATIC_IP/24
    nmcli con mod $INTERFACE ipv4.gateway 10.0.3.1
    nmcli con mod $INTERFACE ipv4.dns "8.8.8.8 8.8.4.4"
    nmcli con mod $INTERFACE ipv4.method manual
    nmcli con up $INTERFACE
    echo "Static IP configuration applied using NetworkManager."
elif [[ "$NETWORK_MANAGER" == "systemd-networkd" ]]; then
    # Configure static IP using systemd-networkd
    CONFIG_FILE="/etc/systemd/network/10-static.network"
    echo -e "[Match]\nName=$INTERFACE\n\n[Network]\nAddress=$STATIC_IP/24\nGateway=10.0.3.1\nDNS=8.8.8.8 8.8.4.4" | sudo tee $CONFIG_FILE
    sudo systemctl restart systemd-networkd
    echo "Static IP configuration applied using systemd-networkd."
elif [[ "$NETWORK_MANAGER" == "dhcpcd" ]]; then
    # Configure static IP using dhcpcd
    echo -e "interface $INTERFACE\nstatic ip_address=$STATIC_IP/24\nstatic routers=10.0.3.1\nstatic domain_name_servers=8.8.8.8 8.8.4.4" | sudo tee -a /etc/dhcpcd.conf
    sudo systemctl restart dhcpcd
    echo "Static IP configuration applied using dhcpcd."
else
    echo "Unknown network manager detected. Manual configuration may be required."
    exit 1
fi

# Add routes
ip route add 10.0.1.2 dev $INTERFACE
ip route add 10.0.3.0/24 dev $INTERFACE
ip route add 10.0.5.0/24 via 10.0.3.4 dev $INTERFACE
ip route add 10.0.5.0/24 via 10.0.1.2 dev $INTERFACE

echo "Routes added successfully."

# Display network configuration
ip addr show $INTERFACE
ip route show
