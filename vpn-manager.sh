# install.sh

```bash
#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or using sudo."
    exit 1
fi

INSTALL_DIR="/opt/pptp-manager"
BIN_DIR="/usr/local/bin"

echo "Installing dependencies..."

if command -v apt >/dev/null 2>&1; then
    apt update
    apt install -y pptp-linux ppp curl iproute2 psmisc systemd
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y pptp ppp curl iproute psmisc systemd
elif command -v yum >/dev/null 2>&1; then
    yum install -y pptp ppp curl iproute psmisc systemd
else
    echo "Unsupported Linux distribution."
    exit 1
fi

mkdir -p $INSTALL_DIR

curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/pptp-manager/main/pptp-manager \
    -o $INSTALL_DIR/pptp-manager

chmod +x $INSTALL_DIR/pptp-manager

ln -sf $INSTALL_DIR/pptp-manager $BIN_DIR/pptp-manager

echo ""
echo "Installation completed successfully."
echo ""
echo "Available commands:"
echo "  pptp-manager"
echo "  pptp-manager setup"
echo "  pptp-manager start <profile>"
echo "  pptp-manager stop <profile>"
echo "  pptp-manager restart <profile>"
echo "  pptp-manager status"
echo "  pptp-manager logs <profile>"
echo "  pptp-manager proxmox enable <CTID>"
```
