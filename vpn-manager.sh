#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run this script as root or via sudo."
    exit 1
fi

# Function to clean up configurations (Uninstaller)
uninstall_vpn() {
    echo "Starting uninstallation process..."
    read -p "Enter the Tunnel Name you want to remove (default: myvpn): " UNINSTALL_NAME
    UNINSTALL_NAME=${UNINSTALL_NAME:-myvpn}

    echo "Stopping VPN connection and background service..."
    systemctl stop "pptp-$UNINSTALL_NAME.service" 2>/dev/null || true
    systemctl disable "pptp-$UNINSTALL_NAME.service" 2>/dev/null || true
    rm -f "/etc/systemd/system/pptp-$UNINSTALL_NAME.service"
    systemctl daemon-reload

    poff "$UNINSTALL_NAME" 2>/dev/null || true
    
    echo "Removing configuration files..."
    rm -f "/etc/ppp/peers/$UNINSTALL_NAME"
    if [ -f /etc/ppp/chap-secrets ]; then
        sed -i "/$UNINSTALL_NAME/d" /etc/ppp/chap-secrets
    fi

    echo "PPTP VPN tunnel '$UNINSTALL_NAME' has been completely removed."
    exit 0
}

# Function to configure Proxmox Host for LXC Pass-through
configure_proxmox_host() {
    echo "==================================================="
    echo "Proxmox Host Admin Mode Enabled"
    echo "==================================================="
    
    # List active LXC containers
    if command -v pct &> /dev/null; then
        echo "Available LXC Containers on this host:"
        pct list || true
    else
        echo "Error: 'pct' command not found. Are you sure this is a Proxmox Host?"
        exit 1
    fi

    read -p "Enter the CT ID (Container ID) you want to enable PPTP for: " CT_ID
    if [ -z "$CT_ID" ] || ! [[ "$CT_ID" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid Container ID."
        exit 1
    fi

    CONF_FILE="/etc/pve/lxc/${CT_ID}.conf"
    if [ ! -f "$CONF_FILE" ]; then
        echo "Error: Configuration file for Container ID $CT_ID not found."
        exit 1
    fi

    # Load PPP module on the host just in case
    modprobe ppp_generic || true

    # Inject required device pass-through configurations if they don't exist
    echo "Injecting device nodes into container configuration..."
    
    if ! grep -q "lxc.cgroup2.devices.allow: c 108:0 rwm" "$CONF_FILE"; then
        echo "lxc.cgroup2.devices.allow: c 108:0 rwm" >> "$CONF_FILE"
    fi

    if ! grep -q "lxc.mount.entry: /dev/ppp dev/ppp none bind,optional,create=file" "$CONF_FILE"; then
        echo "lxc.mount.entry: /dev/ppp dev/ppp none bind,optional,create=file" >> "$CONF_FILE"
    fi

    echo "Success! Proxmox host configuration updated for Container $CT_ID."
    echo " Please restart the container ($CT_ID) to apply changes: 'pct reboot $CT_ID'"
    exit 0
}

# --- Main Menu Menu Selection ---
echo "==================================================="
echo "     Universal PPTP VPN Management Script          "
echo "==================================================="
echo "1) Setup & Connect to a PPTP VPN Client (Server, VM, Client, LXC)"
echo "2) Proxmox Host Admin: Enable PPP/PPTP pass-through for an LXC"
echo "3) Uninstall / Remove an existing PPTP VPN Tunnel"
echo "4) Exit"
read -p "Select an option [1-4]: " SCRIPT_MODE

case $SCRIPT_MODE in
    2) configure_proxmox_host ;;
    3) uninstall_vpn ;;
    4) echo "Exiting."; exit 0 ;;
    1) echo "Proceeding to client installation..." ;;
    *) echo "Invalid option."; exit 1 ;;
esac

# ===================================================
# CLIENT INSTALLATION & CONNECTION MODE
# ===================================================

# 1. Environment and OS Detection
if [ -f /etc/debian_version ] || [ -f /etc/proxmox-release ]; then
    OS="debian"
    apt-get update -y
    apt-get install -y pptp-linux network-manager-pptp iproute2
elif [ -f /etc/redhat-release ]; then
    OS="rhel"
    yum install -y epel-release
    yum install -y pptp network-manager-pptp iproute
else
    echo "Unsupported OS. This script supports Debian/Ubuntu/Proxmox and RHEL/CentOS."
    exit 1
fi

# 2. Check for LXC Container Environment
if [ -f /proc/user_beancounters ] || [ -d /sys/is_container ] || grep -q 'container=lxc' /proc/1/environ; then
    echo "LXC Container environment detected."
    if [ ! -c /dev/ppp ]; then
        echo "Error: /dev/ppp device node is missing in this container."
        echo "Please run this script on your Proxmox Host first and select Option (2) to map it."
        exit 1
    fi
else
    echo "Loading kernel modules..."
    modprobe ppp_mppe || echo "Warning: ppp_mppe module could not be loaded."
fi

# 3. Gather VPN Server Credentials
echo "---------------------------------------------------"
echo "Please enter your PPTP VPN configuration details:"
echo "---------------------------------------------------"

read -p "Tunnel Name (e.g., officevpn): " TUNNEL_NAME
TUNNEL_NAME=${TUNNEL_NAME:-officevpn}

read -p "VPN Server IP/Hostname: " VPN_SERVER
if [ -z "$VPN_SERVER" ]; then echo "Server cannot be empty."; exit 1; fi

read -p "VPN Username: " VPN_USER
if [ -z "$VPN_USER" ]; then echo "Username cannot be empty."; exit 1; fi

read -s -p "VPN Password: " VPN_PASS
echo ""
if [ -z "$VPN_PASS" ]; then echo "Password cannot be empty."; exit 1; fi

# 4. Routing Preference Selection (Split-Tunnel vs Full Tunnel)
echo "---------------------------------------------------"
echo "Select Routing Mode:"
echo "1) Full-Tunnel (Route ALL internet traffic through the VPN)"
echo "2) Split-Tunnel (Only access specific internal subnets via VPN)"
read -p "Option [1-2]: " ROUTE_MODE

ROUTE_OPTIONS="defaultroute replacedefaultroute"
if [ "$ROUTE_MODE" == "2" ]; then
    ROUTE_OPTIONS="# Split tunneling active"
    read -p "Enter the target subnet to route (e.g., 192.168.10.0/24): " SPLIT_SUBNET
fi

# 5. Create Configuration Profiles
echo "Generating configurations..."
mkdir -p /etc/ppp/peers

cat <<EOF > "/etc/ppp/peers/$TUNNEL_NAME"
pty "pptp $VPN_SERVER --nolaunchpptp"
name "$VPN_USER"
remotename $TUNNEL_NAME
require-mppe-128
require-mschap-v2
refuse-eap
refuse-pap
refuse-chap
refuse-mschap
file /etc/ppp/options.pptp
ipparam $TUNNEL_NAME
persist
maxfail 0
$ROUTE_OPTIONS
EOF

# Safely manage credentials inside chap-secrets
sed -i "/$VPN_USER $TUNNEL_NAME/d" /etc/ppp/chap-secrets
echo "$VPN_USER $TUNNEL_NAME \"$VPN_PASS\" *" >> /etc/ppp/chap-secrets
chmod 600 /etc/ppp/chap-secrets

# 6. Optional Persistent Auto-Reconnect Service Definition
read -p "Do you want to create a Systemd Service for Auto-Reconnect on boot? (y/n): " AUTO_START
if [[ "$AUTO_START" =~ ^[Yy]$ ]]; then
    echo "Creating systemd daemon..."
    
    # Build custom routing logic for split tunnels into the daemon lifecycle
    EXEC_START_POST=""
    if [ "$ROUTE_MODE" == "2" ] && [ -not -z "$SPLIT_SUBNET" ]; then
        EXEC_START_POST="ExecStartPost=/bin/sh -c 'sleep 5 && ip route add $SPLIT_SUBNET dev ppp0'"
    fi

    cat <<EOF > "/etc/systemd/system/pptp-$TUNNEL_NAME.service"
[Unit]
Description=PPTP VPN Keep-Alive Tunnel ($TUNNEL_NAME)
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/pon $TUNNEL_NAME
ExecStop=/usr/sbin/poff $TUNNEL_NAME
$EXEC_START_POST
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "pptp-$TUNNEL_NAME.service"
    systemctl start "pptp-$TUNNEL_NAME.service"
    echo "Systemd service deployment complete."
else
    # Fallback to manual execution line items
    echo "Starting direct terminal connection..."
    pon "$TUNNEL_NAME"
    if [ "$ROUTE_MODE" == "2" ] && [ ! -z "$SPLIT_SUBNET" ]; then
        sleep 4
        ip route add "$SPLIT_SUBNET" dev ppp0 || echo "Split route application delayed. Make sure ppp0 establishes correctly."
    fi
fi

# 7. Post Execution Check Up Verification
sleep 5
if ip addr show dev ppp0 > /dev/null 2>&1; then
    echo "==================================================="
    echo "Success! Active connection confirmed via interface ppp0."
    echo "Manage via: pon $TUNNEL_NAME / poff $TUNNEL_NAME"
    echo "==================================================="
else
    echo "==================================================="
    echo " Initialization sequence finished, but interface ppp0 is not live yet."
    echo "Inspect connection failure details using: journalctl -xe"
    echo "==================================================="
fi
