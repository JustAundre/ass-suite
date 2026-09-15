#!/usr/bin/env bash





#
# Environment Setup
#
# Script Variables
vsftpdConfig="/etc/vsftpd.conf"
backup="/etc/vsftpd.conf.bak"
certDir=/etc/ssl/private
certFile="${certDir}/vsftpd.pem"
#
# Backup existing configurations
cp -pv "${vsftpdConfig}" "${backup}"
echo "✅: Backed up VSFTPD confugrations to ${backup}"





#
# Install/Verify Integrity of VSFTPD
#
# vsftpd openssl





#
# Harden VSFTPD
#
if ! [[ -f "${certFile}" ]]; then
	echo "🚧: Generating TLS certificate"
	openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout "${certFile}" -out "${certFile}" -subj "/CN=FTP Server"
	chmod 600 "${certFile}"
fi
# Disable anonymous access
echo "🚧: Applying secure VSFTPD configurations..."
reconfig -x 'replace' -d '=' "anonymous_enable" "NO" /etc/vsftpd.conf
#
# Local users only
reconfig -x 'replace' -d '=' "local_enable" "YES" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "write_enable" "YES" /etc/vsftpd.conf
#
# Chroot/anchor users to their home directories
reconfig -x 'replace' -d '=' "chroot_local_user" "YES" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "allow_writeable_chroot" "YES" /etc/vsftpd.conf
#
# Restrict file permissions
reconfig -x 'replace' -d '=' "local_umask" "022" /etc/vsftpd.conf
#
# Disable risky features
reconfig -x 'replace' -d '=' "dirmessage_enable" "NO" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "xferlog_enable" "YES" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "port_enable" "NO" /etc/vsftpd.conf
#
# Enable Logging
reconfig -x 'replace' -d '=' "log_ftp_protocol" "YES" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "vsftpd_log_file" "/var/log/vsftpd.log" /etc/vsftpd.conf
#
# Connection limits (brute-force mitigation)
reconfig -x 'replace' -d '=' "max_clients" "10" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "max_per_ip" "3" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "pasv_enable" "YES" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "pasv_min_port" "40000" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "pasv_max_port" "40100" /etc/vsftpd.conf
#
# Idle/timeout limits
reconfig -x 'replace' -d '=' "idle_session_timeout" "600" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "data_connection_timeout" "300" /etc/vsftpd.conf
#
# Banner
reconfig -x 'replace' -d '=' "ftpd_banner" "Authorized access only." /etc/vsftpd.conf
#
# TLS Hardening
reconfig -x 'replace' -d '=' "ssl_enable" "YES" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "rsa_cert_file" "$certFile" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "rsa_private_key_file" "$certFile" /etc/vsftpd.conf
#
# Force Encryption
reconfig -x 'replace' -d '=' "force_local_logins_ssl" "YES" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "force_local_data_ssl" "YES" /etc/vsftpd.conf
#
# Disable Weak SSL
reconfig -x 'replace' -d '=' "ssl_sslv2" "NO" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "ssl_sslv3" "NO" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "ssl_tlsv1" "NO" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "ssl_tlsv1_1" "NO" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "ssl_tlsv1_2" "YES" /etc/vsftpd.conf
#
# Strong ciphers
reconfig -x 'replace' -d '=' "ssl_ciphers" "HIGH" /etc/vsftpd.conf
#
# Hide users
reconfig -x 'replace' -d '=' "userlist_enable" "YES" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "userlist_deny" "NO" /etc/vsftpd.conf
reconfig -x 'replace' -d '=' "require_ssl_reuse" "NO" /etc/vsftpd.conf





#
# Configuration Validation
#
# Vsftpd has no syntax-check flag; a valid config keeps the daemon running in the foreground, so use a timeout. Exit 124 means it survived until killed (valid).
timeout 2 vsftpd "${vsftpdConfig}" &>/dev/null
if ! [[ $? -eq 124 ]]; then
	log e "Configuration failed validation; reverting..."
	cp -pv "${backup}" "${vsftpdConfig}"
	systemctl restart vsftpd
	exit 10
fi
systemctl restart vsftpd
log i "Vsftpd restarted with no issues."
