#!/usr/bin/env bash





#
# Environment Setup
#
apache_main_config="/etc/apache2/apache2.conf"
apache_additional_config="/etc/apache2/conf-enabled/99-apache-security.conf"
: >> "$apache_additional_config"





#
# Service Hardening
#
# Comment out Indexing commands in ALL config files (prevents the "Invalid command IndexIgnore" error)
find /etc/apache2 -type f -name "*.conf"\
	-exec sed -i~ "s/^\s*IndexIgnore/# IndexIgnore/g" {} +
find /etc/apache2 -type f -name "*.conf"\
	-exec sed -i "s/^\s*IndexOptions/# IndexOptions/g" {} +
#
# Fix the "Options" error in main config
sed -i 's/^.*Options.*Indexes.*$/\tOptions None/g' "$apache_main_config"
#
# Disable risky modules
a2dismod -fq autoindex status info
#
# Hide version information
reconfig -x 'replace' "ServerTokens" "Prod" /etc/apache2/apache2.conf
reconfig -x 'replace' "ServerSignature" "Off" /etc/apache2/apache2.conf
#
# Standardizes the /var/www/ block to "Options None" and "AllowOverride None"
sed -Ei~ '
	/<Directory\s+\/var\/www\/>/,/<\/Directory>/ {
		s/^\s*Options.*/\tOptions None/
		s/^\s*AllowOverride.*/\tAllowOverride None/
	}
' "$apache_main_config"
# if service goes down, try AllowOverride AuthConfig or AllowOverride All
#
# Header Configuration
echo "🚧: Adding Security Headers..."
echo '
	<IfModule mod_headers.c>
		Header always set X-Frame-Options "SAMEORIGIN"
		Header always set X-Content-Type-Options "nosniff"
		Header set X-XSS-Protection "1"
	</IfModule>
' >>"$apache_main_config"





#
# Extended Hardening
#
if confirm 'Apply extended Apache hardening (TRACE, default site, modules, TLS, WAF)'; then
	# Disable HTTP TRACE
	if grep -q '^TraceEnable' "$apache_main_config"; then
		sed -i 's/^TraceEnable.*/TraceEnable off/' "$apache_main_config"
	else
		reconfig -x 'replace' "TraceEnable" "off"
	fi
	#
	# Remove the default site
	if [[ -f /etc/apache2/sites-enabled/000-default.conf ]]; then
		a2dissite 000-default.conf || true
	fi
	#
	# Disable additional risky modules (if present)
	a2dismod -fq cgi userdir proxy proxy_http proxy_balancer proxy_ftp 2>/dev/null || true
	#
	# Limit the request body size
	reconfig -x 'replace' "LimitRequestBody" "10485760"
	#
	# Strip ETag headers
	reconfig -x 'replace' "FileETag" "None"
	echo 'Header unset ETag' >>"$apache_main_config"
	#
	# Strict TLS configuration (only when mod_ssl is active)
	if a2query -m ssl >/dev/null 2>&1; then
		log i "🚧: Hardening SSL configuration..."
		ssl_conf=/etc/apache2/mods-enabled/ssl.conf
		if [[ -f "$ssl_conf" ]]; then
			sed -Ei 's/^\s*SSLProtocol.*/SSLProtocol All -SSLv2 -SSLv3 -TLSv1 -TLSv1.1/' "$ssl_conf"
			sed -Ei 's/^\s*SSLCipherSuite.*/SSLCipherSuite HIGH:!aNULL:!MD5:!3DES:!CAMELLIA/' "$ssl_conf"
			grep -q '^SSLHonorCipherOrder' "$ssl_conf" ||
				echo 'SSLHonorCipherOrder On' >>"$ssl_conf"
		fi
	fi
	#
	# WAF: ModSecurity + OWASP CRS + mod_evasive
	if confirm 'Install ModSecurity, OWASP CRS and mod_evasive (WAF)'; then
		# secure_install libapache2-mod-security2 modsecurity-crs libapache2-mod-evasive
		a2enmod security2 evasive
		if [[ -f /etc/modsecurity/modsecurity.conf-recommended && ! -f /etc/modsecurity/modsecurity.conf ]]; then
			cp -pv /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf
		fi
		sed -i 's/^SecRuleEngine .*/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf
	fi
fi





#
# Configuration Validation
#
echo "🚧: Verifying configuration syntax..."
a2enmod headers
if ! apache2ctl -t; then
	log e 'Syntax check failed'
	log i 'Run "apache2ctl -t" to see why.'
	exit 10
fi
log i 'Passed syntax check.' 'Restarting Apache...'
systemctl restart apache2
