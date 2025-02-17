#!/bin/bash
# sudo chmod +x connect_5g_modem.sh
# ./connect_5g_modem.sh

# Check if udhcpc is installed
if ! command -v udhcpc &> /dev/null; then
    echo "udhcpc is not installed. Installing..."
    sudo apt update && sudo apt install -y udhcpc
    if [ $? -ne 0 ]; then
        echo "Failed to install udhcpc. Exiting."
        exit 1
    fi
fi

# Ask user to choose an APN
echo "Select APN:"
echo "1) internet (Nokia)"
echo "2) intranet (MECSware)"
read -p "Enter choice (1 or 2): " apn_choice

case $apn_choice in
    1)
        apn="internet"
        ;;
    2)
        apn="intranet"
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Detect modem
attempt=0
max_attempts=3
modem_detected=""
while [ $attempt -lt $max_attempts ]; do
    modem_detected=$(mmcli -L | grep 'ModemManager1/Modem/')
    if [ -n "$modem_detected" ]; then
        break
    fi
    echo "No modem detected. Retrying in 5 seconds..."
    sleep 5
    ((attempt++))
done

if [ -z "$modem_detected" ]; then
    echo "No modem found after multiple attempts. Exiting."
    exit 1
fi

# Extract modem number
modem_id=$(echo "$modem_detected" | awk -F'/' '{print $NF}' | awk '{print $1}')
echo "Detected modem: $modem_id"

# Connect to the network
if sudo mmcli -m $modem_id --simple-connect "apn=$apn"; then
    echo "Modem successfully connected."
    sudo udhcpc -i wwan0
else
    echo "Failed to connect modem. Exiting."
    exit 1
fi
