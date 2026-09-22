#!/usr/bin/env bash





#
# PAM Configuration
#
mapfile -td '' responses < <(PS2='Select patches to apply.' cl-new -mo 'Enforce password quality' 'Fail locking' 'Reject logins for passwordless users')
case "${os_info['ID']} ${os_info['ID_LIKE']}" in
*fedora*)
	for response in "${responses[@]}"; do
		case "${response}" in
		'Enforce password quality')
			args+=('with-pwquality')
			install -m 640 -o 0 -g 0 -Dv cnf/auth/pwquality.conf /etc/security/pwquality.conf
			;;
		'Fail locking')
			args+=('with-faillock')
			;;
		'Reject logins for passwordless users')
			args+=('without-nullok')
			;;
		*)
			log e "Unknown selection \"${response}\"."
			;;
		esac
	done
	authselect select sssd with-pamaccess with-pwhistory with-mkhomedir with-sudo "${args[@]}" --force
	authselect apply-changes
	;;
*debian*|*ubuntu*)
	for response in "${responses[@]}"; do
		case "${response}" in
		'Enforce password quality')
			install -m 640 -o 0 -g 0 -Dv cnf/auth/pwquality /usr/share/pam-configs/pwquality
			install -m 640 -o 0 -g 0 -Dv cnf/auth/pwquality.conf /etc/security/pwquality.conf
			;;
		'Fail locking')
			install -m 640 -o 0 -g 0 -Dv cnf/auth/faillock /usr/share/pam-configs/faillock
			install -m 640 -o 0 -g 0 -Dv cnf/auth/faillock_reset /usr/share/pam-configs/faillock_reset
			install -m 640 -o 0 -g 0 -Dv cnf/auth/faillock_notify /usr/share/pam-configs/faillock_notify
			;;
		'Reject logins for passwordless users')
			sed -i 's/\s*nullok//g' /usr/share/pam-configs/unix
			;;
		*)
			log e "Unknown selection \"${response}\"."
			;;
		esac
	done
	#
	# Update PAM configurations
	pam-auth-update --force --package
	;;
*freebsd*)
	# TODO: TESTING NEEDED
	# Download base image for FreeBSD system
	trap '[[ -f base.txz ]] && rm -v base.txz' EXIT
	base_sys_url="https://download.freebsd.org/releases/$(uname -m)/$(freebsd-version | cut -d'-' -f1,2)/base.txz"
	log i "Fetching base system image from \"${base_sys_url}\"..."
	fetch -o 'base.txz' -asr "${base_sys_url}" 2>&1 1>&2 | log e || exit 12
	#
	# Backup existing /etc/pam.d directory and extract base.
	mv /etc/pam.d{,~}
	tar -xf base.txz -C /etc/pam.d/ etc/pam.d
	#
	# Audit PAM configuration overrides
	mapfile -td '' paths < <(find /usr/local/etc/pam.d/ -type f -print0)
	for path in "${paths[@]}"; do
		# TODO: Automatically reinstall
		pkg which -q -- "${path}"
		(($? == 1)) && printf '%s\0' "${path}" >>"${log_dir}/unidentified-pam-overrides.txt"
	done
	#
	# Enable password quality checks
	pkg install -f pam_pwquality
	install -m 640 -o 0 -g 0 -Dv cnf/auth/pwquality.conf /usr/local/etc/security/pwquality.conf
	;;
*)
	log e 'Operating system not supported.'
	exit 11
	;;
esac
