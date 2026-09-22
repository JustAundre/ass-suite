#!/usr/bin/env bash
# TODO TODO TODO TODO MAKE BETTER PLEASE





#
# Setup
#
# Script variables
backup_dir='/etc/nginx~'
hardening_snippets='/etc/nginx/snippets/security-headers.conf'
general_hardening='/etc/nginx/conf.d/99-hardening.conf'
#
# Make/ensure existence of backup dir
mkdir -p "$backup_dir"





#
# Nginx Setup
#
# Stop Nginx for smooth configurations
systemctl stop nginx
#
# Backup existing configurations
cp -pva "/etc/nginx" "$backup_dir" &&
	log i "Configuration backups are saved under \"$backup_dir\"."
#
# Add secure headers to outgoing requests
mkdir -p /etc/nginx/snippets
install -m 0640 -o 0 -g 0 -Dv general-confs/nginx-headers.conf "${hardening_snippets}"
#
# General reduction of information leakage
install -m 0640 -o 0 -g 0 -Dv general-confs/99-hardening.conf "${general_hardening}"
#
# Ensures it contains the conf.d include
# Insert inside the http {} block right after it opens
grep -qE 'include\s+/etc/nginx/conf\.d/\*\.conf;' "/etc/nginx/nginx.conf" ||
	sed -i~ '0,/http\s*{/s/http\s*{/http {\n\tinclude \/etc\/nginx\/conf.d\/\*\.conf;/' "/etc/nginx/nginx.conf"
#
# Update the general-confs/default file with what is appropriate with your scenario
log i 'Replacing default site configurations with secure defaults...'
cat general-confs/default >/etc/nginx/sites-available/default
#
# Remove overlapping configuration values from nginx.conf
sed -i '/server_tokens/d' "/etc/nginx/nginx.conf"
sed -i '/client_body_buffer_size/d' "/etc/nginx/nginx.conf"
sed -i '/client_header_buffer_size/d' "/etc/nginx/nginx.conf"
sed -i '/client_max_body_size/d' "/etc/nginx/nginx.conf"
sed -i '/large_client_header_buffers/d' "/etc/nginx/nginx.conf"
sed -i '/ssl_protocols/d' "/etc/nginx/nginx.conf"
sed -i '/ssl_prefer_server_ciphers/d' "/etc/nginx/nginx.conf"
sed -i '/ssl_session_cache/d' "/etc/nginx/nginx.conf"
sed -i '/ssl_ciphers/d' "/etc/nginx/nginx.conf"





#
# Optional Hardening
#
# Install fail2ban with the standard nginx jails
if confirm 'Install and enable fail2ban with the nginx jails'; then
	(
		set -e
		secure_install fail2ban
		cat >/etc/fail2ban/jail.d/nginx.local <<-'EOF'
			[nginx-http-auth]
			enabled = true

			[nginx-botsearch]
			enabled = true

			[nginx-limit-req]
			enabled = true
		EOF
		systemctl enable --now fail2ban
	)
fi
#
# Generate strong Diffie-Hellman parameters for TLS
if confirm 'Generate strong DH parameters for TLS (may take a while)'; then
	openssl dhparam -out /etc/nginx/dhparam.pem 4096 &&
		echo 'ssl_dhparam /etc/nginx/dhparam.pem;' >> "${general_hardening}"
fi





#
# Configuration Validation
#
log i 'Testing configuration...'
if ! nginx -t; then
	log i 'Nginx configuration is invalid; reverting Nginx...'
	cp -pv "/etc/nginx~/nginx.conf" "/etc/nginx/nginx.conf"
	cp -pv "${backup_dir}/sites-available/default" "/etc/nginx/sites-available/default"
	exit 10
fi
log i 'Nginx configuration validated.' 'Restarting Nginx...'
systemctl restart nginx
