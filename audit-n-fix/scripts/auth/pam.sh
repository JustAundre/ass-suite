#!/usr/bin/env bash





#
# PAM Configuration
#
# RHEL-like distros
case "${os_info['ID']} ${os_info['ID_LIKE']}" in
*fedora*)
	# Configure PAM w/ secure defaults enabled & further configure password QA
	authselect select sssd with-faillock with-pamaccess with-pwhistory with-pwquality with-mkhomedir with-sudo without-nullok --force
	install -m 640 -o 0 -g 0 -D cnf/auth/pwquality.conf /etc/security/pwquality.conf
	#
	# Regenerate PAM configurations w/ previous configuration
	authselect apply-changes
	;;
*debian*|*ubuntu*)
	mapfile -td '' responses < <(PS2='Select patches to apply.' cl-new -mo 'Enforce password quality' 'Fail locking' 'Reject logins for passwordless users')
	for response in "${responses[@]}"; do
		case "${response}" in
		'Enforce password quality')
			install -m 640 -o 0 -g 0 -D cnf/auth/pwquality /usr/share/pam-configs/pwquality
			install -m 640 -o 0 -g 0 -D cnf/auth/pwquality.conf /etc/security/pwquality.conf
			;;
		'Fail locking')
			install -m 640 -o 0 -g 0 -D cnf/auth/faillock /usr/share/pam-configs/faillock
			install -m 640 -o 0 -g 0 -D cnf/auth/faillock_reset /usr/share/pam-configs/faillock_reset
			install -m 640 -o 0 -g 0 -D cnf/auth/faillock_notify /usr/share/pam-configs/faillock_notify
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
	fetch -s "https://download.freebsd.org/releases/$(uname -m)/$(freebsd-version | cut -d'-' -f1,2)/base.txz"
	pkg install pam_pwquality
	install -m 640 -o 0 -g 0 -D cnf/auth/pwquality.conf /usr/local/etc/security/pwquality.conf
	;;
*)
	log e 'Your operating system is not supported.'
	;;
esac
