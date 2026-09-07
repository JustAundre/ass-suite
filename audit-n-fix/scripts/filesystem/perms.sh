#!/usr/bin/env bash





#
# Script-specific Function(s)
#
# Helper function to select an action to rectify an issue with no preset fix.
fixes=(
	'Change ownership'
	'Change permissions'
	'Rename node'
	'' '' ''
	'Delete node'
)
select_fix() {
	# Prompt for action
	local PS3 selection selections x y user group basename
	PS3+="\"${1}\" is owned by $(stat -c '%U:%G/%u:%g' "${1}") with permissions $(stat -c '%a' "${1}")"
	#
	# Act on selections
	mapfile -t selections < <(cl-new -t 'Select a method of remediation.' checklist "${fixes[@]}")
	for selection in "${selections[@]}"; do
		# Prompt for new ownership
		# Validate given user and group
		# Change the ownership
		case "${selection}" in
		'Change ownership')
			until [[ "${user}" =~ ^[0-9]+$ ]] || getent passwd -- "${user}" &>/dev/null && [[ -n "${user}" ]]; do
				[[ -n "${x}" ]] && log w 'Invalid username/UID provided.' || x=true
				read -erp 'Enter the new user owner: ' user
			done
			until [[ "${group}" =~ ^[0-9]+$ ]] || getent group -- "${group}" &>/dev/null && [[ -n "${group}" ]]; do
				[[ -n "${y}" ]] && log w 'Invalid group/GID provided.' || y=true
				read -erp 'Enter the new group owner: ' group
			done
			chown -hc -- "${user}:${group}" "${1}"
		;;
		'Change permissions')
			until [[ "${perm}" =~ ^[1234567]{3,4}$ ]]; do
				read -erp 'Enter the octal permission: ' perm
			done
			chmod -c -- "${perm}" "${1}"
		;;
		'Rename node')
			read -erp 'Enter the new name for the node' basename
			mv -- "${1}" "$(dirname -- "${1}")""${basename}"
		;;
		'Delete node')
			rm -rfv -- "${1}"
		;;
		esac
	done
}
export -f select_fix





#
# Invalidities
#
# Map out files w/ broken ownership.
mapfile -td '' paths < <(find / -xephem '(' -nouser -o -nogroup ')' -print0)
for path in "${paths[@]}"; do (
	# Verbosity: note invalidities, their type, and the UID/GID.
	[[ "$(stat -c '%U' "${path}")" == UNKNOWN ]] && invalid_type+=UID
	[[ "$(stat -c '%G' "${path}")" == UNKNOWN ]] && {
		[[ -n "${invalid_type}" ]] && invalid_type+=' & '
		invalid_type+=GID
	}
	log i "${path} has an invalid owner ${invalid_type}; changed ownership to 0:0."
	chown -h 0:0 -- "${path}"
) done
#
# Remove invalid symlinks
mapfile -td '' paths < <(find / -xephem -xtype l -print0)
for path in "${paths[@]}"; do
	log i "${path} is a broken symlink; removing..."
	unlink -- "${path}"
done
#
# Ensure FHS temp directories are world-writable w/ sticky-bit.
perm_fix -m 1777 -o 0 -g 0 /tmp /var/tmp /dev/shm





#
# Ambiguous Paths
#
# Prompt for manual review for paths in /etc/ which aren't owned by a system user.
mapfile -td '' paths < <(find /etc -xephem '(' ! -group 0 -o ! -user 0 ')' -print0)
for path in "${paths[@]}"; do
	# If the owners are system users/groups, it's probably fine.
	if [[ "$(stat -c %g "${path}")" -ge 1000 || "$(stat -c %u "${path}")" -ge 1000 ]]; then
		select_fix "${path}"
	else
		log i "${path} isn't owned by 0:0 but marked as likely safe as the owners are system users."
	fi
done
#
# Prompt for manual review for paths which are world-writable.
mapfile -td '' paths < <(find / -xephem -perm -0002 -print0)
for path in "${paths[@]}"; do
	select_fix "${path}"
done





#
# Identity & Authorization
#
# Handle /etc/passwd & /etc/group
perm_fix -m 644 -o 0 -g 0 /etc/passwd /etc/group
#
# Shadow file permissions vary by the presence of the shadow group.
if grep -qE '^shadow:' /etc/group; then
	perm_fix -m 0640 -o 0 -g shadow /etc/shadow /etc/gshadow
	perm_fix -m 0600 -o 0 -g 0 /etc/shadow- /etc/gshadow-
else
	perm_fix -m 0000 -o 0 -g 0 /etc/shadow /etc/gshadow /etc/shadow- /etc/gshadow-
fi
#
# Fix Sudoers configuration
mapfile -td '' paths < <(find /etc/sudoers.d /etc/sudoers -type f -print0)
for path in "${paths[@]}"; do
	perm_fix -m 600 -o 0 -g 0 "${path}"
done
mapfile -td '' paths < <(find /etc/sudoers.d /etc/sudoers -type d -print0)
for path in "${paths[@]}"; do
	perm_fix -m 700 -o 0 -g 0 "${path}"
done





#
# Misc. System Files
#
# Ensure only root can read the bootloader config
mapfile -td '' paths < <(find /boot -type f -print0)
for path in "${paths[@]}"; do
	perm_fix -m 640 -o 0 -g 0 "${path}"
done
mapfile -td '' paths < <(find /boot -type d -print0)
for path in "${paths[@]}"; do
	perm_fix -m 750 -o 0 -g 0 "${path}"
done
#
# Ensure SystemD unit files are secure
mapfile -td '' paths < <(find /etc/systemd/system -type f -print0)
for path in "${paths[@]}"; do
	perm_fix -m 640 -o 0 -g 0 "${path}"
done
mapfile -td '' paths < <(find /etc/systemd/system -type d -print0)
for path in "${paths[@]}"; do
	perm_fix -m 750 -o 0 -g 0 "${path}"
done
#
# Secure cronjobs
mapfile -td '' paths < <(find /etc/cron.* /etc/crontab /etc/at.allow -type f -print0)
for path in "${paths[@]}"; do
	perm_fix -m 640 -o 0 -g 0 "${path}"
done
mapfile -td '' paths < <(find /etc/cron.* /etc/crontab /etc/at.allow -type d -print0)
for path in "${paths[@]}"; do
	perm_fix -m 750 -o 0 -g 0 "${path}"
done
#
# Restrict privileged binaries
perm_fix -m 750 -o 0 -g 0 /sbin/auditctl /sbin/aureport /sbin/ausearch /sbin/autrace /sbin/auditd /sbin/augenrules /bin/dmesg /usr/bin/dmesg
#
# Secure SSH configurations/private keys, and public keys.
mapfile -td '' paths < <(find /etc/ssh -type f -print0)
for path in "${paths[@]}"; do
	perm_fix -m 600 -o 0 -g 0 "${path}"
done
mapfile -td '' paths < <(find /etc/ssh -type d -print0)
for path in "${paths[@]}"; do
	perm_fix -m 700 -o 0 -g 0 "${path}"
done
mapfile -td '' paths < <(find /etc/ssh -name '*.pub' -type f -print0)
for path in "${paths[@]}"; do
	perm_fix -m 644 -o 0 -g 0 "${path}"
done
#
# Secure MOTD/banners are secured
perm_fix -m 644 -o 0 -g 0 /etc/issue /etc/issue.net /etc/motd
#
# Secure logging directory
perm_fix -m 755 -o 0 -g 0 /var/log
mapfile -td '' paths < <(find /var/log/ -mindepth 1 -type f -print0)
for path in "${paths[@]}"; do
	perm_fix -m 640 "${path}"
done
mapfile -td '' paths < <(find /var/log/ -mindepth 1 -type d -print0)
for path in "${paths[@]}"; do
	perm_fix -m 750 "${path}"
done
#
# Some distros use the adm user for these logs
(
	auditd_log_dir="$(dirname "$(awk -F'=' '/^\s*log_file/ {print $2}' /etc/audit/auditd.conf | xargs)")"
	if [[ "${os_info[ID]}" =~ ^(ubuntu|almalinux)$ && -d "${auditd_log_dir}" ]]; then
		mapfile -td '' paths < <(find "${auditd_log_dir}" -type f -print0)
		for path in "${paths[@]}"; do
			perm_fix -m 640 -o 0 -g adm "${path}"
		done
	else
		mapfile -td '' paths < <(find "${auditd_log_dir}" -type f -print0)
		for path in "${paths[@]}"; do
			perm_fix -m 0600 -o 0 -g 0 "${path}"
		done
	fi
	chmod -c 0750 -- "${auditd_log_dir}"
)

#
# Secure AuditD/rsyslog configurations
mapfile -td '' paths < <(find /etc/audit /etc/rsyslog.d/ /etc/rsyslog.conf -mindepth 1 -type f -print0)
for path in "${paths[@]}"; do
	perm_fix -m 640 -o 0 -g 0 "${path}"
done
mapfile -td '' paths < <(find /etc/audit /etc/rsyslog.d/ -type d -print0)
for path in "${paths[@]}"; do
	perm_fix -m 750 -o 0 -g 0 "${path}"
done
#
# Secure global shell profiles
mapfile -td '' paths < <(find /etc/profile /etc/bashrc /etc/bash.bashrc /etc/profile.d/ -type f -print0)
for path in "${paths[@]}"; do
	perm_fix -m 644 -o 0 -g 0 "${path}"
done
mapfile -td '' paths < <(find /etc/profile /etc/bashrc /etc/bash.bashrc /etc/profile.d/ -type d -print0)
for path in "${paths[@]}"; do
	perm_fix -m 755 -o 0 -g 0 "${path}"
done
#
# Secure local home directories (including root's home @ /root)
(for user in "${int_users[@]}"; do
	home="$(grep "^${user}:" /etc/passwd | head -n1 | cut -d: -f6)"

	mapfile -td '' paths < <(find "${home}" -type f -print0)
	for path in "${paths[@]}"; do
		perm_fix -m 600 -o "${user}" -g "${user}" "${path}"
	done

	mapfile -td '' paths < <(find "${home}" -type d -print0)
	for path in "${paths[@]}"; do
		perm_fix -m 700 -o "${user}" -g "${user}" "${path}"
	done
done)
mapfile -td '' paths < <(find /root -type f -print0)
for path in "${paths[@]}"; do
	perm_fix -m 600 -o 0 -g 0 "${path}"
done
mapfile -td '' paths < <(find /root -type d -print0)
for path in "${paths[@]}"; do
	perm_fix -m 700 -o 0 -g 0 "${path}"
done
#
# Debian-based distros exclusive: APT keyrings
if [[ "${os_info[ID]}" == debian || "${os_info[ID]}" == ubuntu ]]; then
	if [[ -d /etc/apt/trusted.gpg.d ]]; then
		mapfile -td '' paths < <(find /etc/apt/trusted.gpg.d -type f -print0)
		for path in "${paths[@]}"; do
			perm_fix -m 644 -o 0 -g 0 "${path}"
		done
	fi
	if [[ -d /usr/share/keyrings ]]; then
		mapfile -td '' paths < <(find /usr/share/keyrings -type f -print0)
		for path in "${paths[@]}"; do
			perm_fix -m 644 -o 0 -g 0 "${path}"
		done
	fi
fi
