```bash
#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run this installer using sudo or as root."
    exit 1
fi

INSTALL_DIR="/opt/pptp-manager"
BIN_DIR="/usr/local/bin"

echo "Installing dependencies..."

if command -v apt >/dev/null 2>&1; then
    apt update
    apt install -y pptp-linux ppp curl iproute2 psmisc
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y pptp ppp curl iproute psmisc
elif command -v yum >/dev/null 2>&1; then
    yum install -y pptp ppp curl iproute psmisc
else
    echo "Unsupported Linux distribution."
    exit 1
fi

mkdir -p "$INSTALL_DIR"

echo "Downloading pptp-manager..."

curl -fsSL \
https://raw.githubusercontent.com/mhd-rsl/pptp-manager/main/pptp-manager \
-o "$INSTALL_DIR/pptp-manager"

chmod +x "$INSTALL_DIR/pptp-manager"

ln -sf "$INSTALL_DIR/pptp-manager" "$BIN_DIR/pptp-manager"

echo ""
echo "========================================"
echo "PPTP Manager installed successfully."
echo "========================================"
echo ""
echo "Usage:"
echo "  sudo pptp-manager"
echo "  sudo pptp-manager setup"
echo "  sudo pptp-manager start officevpn"
echo "  sudo pptp-manager stop officevpn"
echo "  sudo pptp-manager status"
echo ""
```
