# Manual Tasks

## Verifying Integrity

### Manual check

```bash
# Debian
dpkg -V

# RHEL (both modern & legacy)
rpm -Va

# Arch
pacman -Qk

# FreeBSD
pkg check -sa
```

### Automatic reinstall

```bash
# Debian
dpkg -V | awk '$1 ~ /^..5/ {print $2}' | xargs -r dpkg -S | cut -d: -f1 | sort -u | sudo xargs -r apt-get install --reinstall -y

# RHEL (both modern & legacy)
rpm -Va --nofiles | awk '{print $NF}' | xargs -r rpm -qf | sort -u | sudo xargs -r dnf reinstall -y

# Arch
pacman -Qk 2>&1 | awk '/gaps in/ {print $2}' | sudo xargs -r pacman -S --noconfirm

# FreeBSD
pkg check -sa --checksum 2>&1 | awk -F: '/checksum mismatch|missing/ {print $1}' | sort -u | sudo xargs -r pkg install -fy
```

## Finding Files

Fast, but relies on file extensions:

```sh
# Finding png files, change file extension as needed
sudo find /home -type f '*.png'
```

Comprehensive, but slow:

```bash
# Finding images, change type as needed
sudo find /home -type f -exec file --mime-type {} + | grep 'image/'
```

## Updates

### Debian

```sh
sudo apt-get update
sudo apt-get full-upgrade
sudo apt-get dist-upgrade
```

### RHEL

```sh
# Modern RHEL (8 and above)
sudo dnf update

# Legacy RHEL (7 and below)
sudo yum update
```

### Arch

```sh
sudo pacman -Syu
```

### BSD

```sh
sudo pkg upgrade
```

## Login.defs

Configure password expiries for new users, strict UMASK, enable automatic creation of home directories,
set a secure encryption, and enable user-groups.

Inside `/etc/login.defs`:

```properties
PASS_MAX_DAYS 31
PASS_MIN_DAYS 3
PASS_WARN_AGE 27
ENCRYPT_METHOD YESCRYPT
UMASK 077
CREATE_HOME yes
USERGROUPS_ENAB yes
```

## Display Manager

### LightDM

Disable guest login, auto login, user enumeration, remote X server login, and VNC/RDP access.

Inside `/etc/lightdm/lightdm.conf`:

```properties
allow-guest=false
AutomaticLogin=false
greeter-show-manual-login=true
greeter-hide-users=true
xdmcp-enabled=false
vnc-server-enabled=false
```

### GDM

Disable automatic login

Inside `/etc/gdm/custom.conf`:

```properties
AutomaticLoginEnable=false 
```

### SDDM

Disable automatic login and user enumeration

Inside `/etc/sddm.conf`:

```properties
User 
Session
HideUsers
DisableDebug true
```
