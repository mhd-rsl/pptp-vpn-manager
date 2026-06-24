#!/bin/bash
set -e
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or using sudo."
  exit 1
fi

INSTALL_DIR="/opt/pptp-manager"
BIN_DIR="/usr/local/bin"

if command -v apt >/dev/null 2>&1; then
    apt update
    apt install -y pptp-linux ppp curl iproute2 psmisc
fi

mkdir -p "$INSTALL_DIR"

curl -fsSL https://raw.githubusercontent.com/mhd-rsl/pptp-manager/main/pptp-manager \ 
  -o "$INSTALL_DIR/pptp-manager"

chmod +x "$INSTALL_DIR/pptp-manager"
ln -sf "$INSTALL_DIR/pptp-manager" "$BIN_DIR/pptp-manager"

echo "Installation complete."
echo "Run: sudo pptp-manager"
