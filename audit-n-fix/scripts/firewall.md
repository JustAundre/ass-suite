# Basic Firewall Setup

## Uncomplicated Firewall (UFW)

0. (Re)install UFW

```sh
# Debian-derivatives: Ubuntu, Mint...
sudo apt purge ufw
sudo apt-get install --reinstall -y ufw

# Fedora-derivatives: Redhat, AlmaLinux...
sudo dnf reinstall -y ufw

# Legacy Fedora-derivatives
sudo yum reinstall -y ufw

# Arch-derivatives: CachyOS...
sudo pacman -S --noconfirm ufw
```

1. (Force) enable UFW

```sh
# Unmasks the firewall service
systemctl unmask ufw

# Starts the service
systemctl enable --now ufw

# Try forcing UFW to start
ufw --force enable
```

2. Reset & reconfigure

```sh
# Reset UFW configuration.
ufw reset

# Denies incoming connections and allows outgoing by default.
ufw default deny incoming
ufw default allow outgoing
```

## FirewallD

0. (Re)install FirewallD

```sh
# Debian-derivatives: Ubuntu, Mint...
sudo apt-get purge -y firewalld
sudo apt-get install --reinstall -y firewalld

# Fedora-derivatives: Redhat, AlmaLinux...
sudo dnf reinstall -y firewalld

# Legacy Fedora-derivatives
sudo yum reinstall -y firewalld

# Arch-derivatives: CachyOS...
sudo pacman -S --noconfirm firewalld
```

1. Enable FirewallD

```sh
systemctl unmask firewalld
systemctl enable --now firewalld
```

2. Reset & reconfigure

```sh
# Reset FirewallD configuration.
firewall-cmd --reset-to-defaults

# Set zone to public, allow out, deny in.
firewall-cmd --set-default-zone public
firewall-cmd --permanent --load-zone-defaults public

# Blocks ICMP echo and timestamp requests.
firewall-cmd --permanent --add-icmp-block echo-request
firewall-cmd --permanent --add-icmp-block timestamp-reply
firewall-cmd --permanent --add-icmp-block timestamp-request

# Reload FirewallD.
firewall-cmd --reload
```
