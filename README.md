## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/mhd-rsl/pptp-manager/main/install.sh | sudo bash
```

## Interactive Mode

```bash
sudo pptp-manager
```

## Command Line Usage

```bash
sudo pptp-manager setup
sudo pptp-manager start officevpn
sudo pptp-manager stop officevpn
sudo pptp-manager restart officevpn
sudo pptp-manager status
sudo pptp-manager logs officevpn
sudo pptp-manager list
```

## Proxmox LXC Support

On the Proxmox host:

```bash
sudo pptp-manager proxmox enable 101
pct reboot 101
```
