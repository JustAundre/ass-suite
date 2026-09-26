#!/usr/bin/env bash





#
# Environment Setup
#
mkdir -p "${log_dir}/tmp"
find / -xephem -type f -perm -4000 -print0 > "${log_dir}/suid-binaries.txt" &
find / -xephem -type f -perm -2000 -print0 > "${log_dir}/sgid-binaries.txt" &
find / -xephem -nouser -print0 > "${log_dir}/no-user.txt" &
find / -xephem -nogroup -print0 > "${log_dir}/no-group.txt" &
find / -xephem -xtype l -print0 > "${log_dir}/broken-symlinks.txt" &
find / -xephem -perm -0002 -print0 > "${log_dir}/world-writables.txt" &
find /etc/sudoers.d /etc/sudoers -type f -print0 > "${log_dir}/tmp/sudoers-files.txt" &
find /etc/sudoers.d -type d -print0 > "${log_dir}/tmp/sudoers-dirs.txt" &
find /boot -type f -print0 > "${log_dir}/tmp/boot-files.txt" &
find /boot -type d -print0 > "${log_dir}/tmp/boot-dirs.txt" &
find /etc/systemd/system -type f -print0 > "${log_dir}/tmp/systemd-unit-files.txt" &
find /etc/systemd/system -type d -print0 > "${log_dir}/tmp/systemd-unit-dirs.txt" &
find /etc/cron.* /etc/crontab /etc/at.allow -type f -print0 > "${log_dir}/tmp/scheduled-tasks-files.txt" &
find /etc/cron.* /etc/crontab /etc/at.allow -type d -print0 > "${log_dir}/tmp/scheduled-tasks-dirs.txt" &
find /var/log/ -mindepth 1 -type f -print0 > "${log_dir}/tmp/system-log-files" &
find /var/log/ -mindepth 1 -type d -print0 > "${log_dir}/tmp/system-log-dirs" &
find /etc/ssh -type f -print0 > "${log_dir}/tmp/ssh-config-files.txt" &
find /etc/ssh -type d -print0 > "${log_dir}/tmp/ssh-config-dirs.txt" &
find /etc/ssh -name '*.pub' -type f -print0 > "${log_dir}/tmp/ssh-pub-files.txt" &
auditd_log_dir="$(dirname "$(awk -F' = ' '/^\s*log_file/ {print $2}' /etc/audit/auditd.conf)")"
find -- "${auditd_log_dir}" -type f -print0 > "${log_dir}/tmp/auditd-log-files.txt" &
find -- "${auditd_log_dir}" -type f -print0 > "${log_dir}/tmp/auditd-log-dirs.txt" &
find /etc/audit /etc/rsyslog.d/ /etc/rsyslog.conf -mindepth 1 -type f -print0 > "${log_dir}/tmp/logging-daemon-config-files.txt" &
find /etc/audit /etc/rsyslog.d/ -type d -print0 > "${log_dir}/tmp/logging-daemon-config-dirs.txt" &
find /etc/profile /etc/bashrc /etc/bash.bashrc /etc/profile.d/ -type f -print0 > "${log_dir}/tmp/global-shell-profile-files.txt" &
find /etc/profile.d/ -type d -print0 > "${log_dir}/tmp/global-shell-profile-dirs.txt" &
for user in "${int_users[@]}"; do
	home="$(grep -- "^${user}:" /etc/passwd | head -n1 | cut -d: -f6)"
	[[ "${home}" == / ]] && continue
	find -- "${home}" -type f -print0 > "${log_dir}/tmp/${user}-files.txt" &
	find -- "${home}" -type d -print0 > "${log_dir}/tmp/${user}-dirs.txt" &
done
unset home
find /root -type f -print0 > "${log_dir}/tmp/root-home-files.txt" &
find /root -type d -print0 > "${log_dir}/tmp/root-home-dirs.txt" &
find /etc/apt/trusted.gpg.d /usr/share/keyrings -type f -print0 > "${log_dir}/tmp/apt-keyrings.txt" &
find /etc -print0 > "${log_dir}/tmp/etc.txt" &
log i 'Please hold while this script conducts numerous asynchronous searches on this filesystem for files and directories matching specific criteria...'
wait





#
# SUID Binaries
#
mapfile -td '' paths < "${log_dir}/suid-binaries.txt"
mapfile -td '' selections < <(PS2='Select binaries to remove the SUID bit from' cl-new -mo "${paths[@]}")
((${#selections[@]})) && chmod u-s -v -- "${selections[@]}"





#
# SGID Binaries
#
mapfile -td '' paths < "${log_dir}/sgid-binaries.txt"
mapfile -td '' selections < <(PS2='Select binaries to remove the SGID bit from' cl-new -mo "${paths[@]}")
((${#selections[@]})) && chmod g-s -v -- "${selections[@]}"





#
# Broken Ownerships
#
# UIDs
mapfile -td '' paths < "${log_dir}/no-user.txt"
for path in "${paths[@]@Q}"; do
	log w "${path} is owned by an invalid UID."
done
perm_fix -o 0 "${paths[@]}"
#
# GIDs
mapfile -td '' paths < "${log_dir}/no-group.txt"
for path in "${paths[@]@Q}"; do
	log w "${path} is owned by an invalid GID."
done
perm_fix -g 0 "${paths[@]}"





#
# Identity & Authorization
#
# /etc/passwd & /etc/group
perm_fix -m 644 -o 0 -g 0 /etc/passwd /etc/group
#
# Shadow file permissions vary by the presence of the shadow group.
if grep -qE '^shadow:' /etc/group; then
	perm_fix -m 640 -o 0 -g shadow /etc/shadow /etc/gshadow
	perm_fix -m 600 -o 0 -g 0 /etc/shadow- /etc/gshadow-
else
	perm_fix -m 000 -o 0 -g 0 /etc/shadow /etc/gshadow /etc/shadow- /etc/gshadow-
fi
#
# Sudoers configuration
mapfile -td '' paths < "${log_dir}/tmp/sudoers-files.txt"
perm_fix -m 600 -o 0 -g 0 "${paths[@]}"
mapfile -td '' paths < "${log_dir}/tmp/sudoers-dirs.txt"
perm_fix -m 700 -o 0 -g 0 "${paths[@]}"





#
# Misc. System Files
#
# Bootloader config
mapfile -td '' paths < "${log_dir}/tmp/boot-files.txt"
perm_fix -m 640 -o 0 -g 0 "${paths[@]}"
mapfile -td '' paths < "${log_dir}/tmp/boot-dirs.txt"
perm_fix -m 750 -o 0 -g 0 "${paths[@]}"
#
# SystemD units
mapfile -td '' paths < "${log_dir}/tmp/systemd-unit-files.txt"
perm_fix -m 640 -o 0 -g 0 "${paths[@]}"
mapfile -td '' paths < "${log_dir}/tmp/systemd-unit-dirs.txt"
perm_fix -m 750 -o 0 -g 0 "${paths[@]}"
#
# Scheduled tasks
mapfile -td '' paths < "${log_dir}/tmp/scheduled-tasks-files.txt"
perm_fix -m 640 -o 0 -g 0 "${paths[@]}"
mapfile -td '' paths < "${log_dir}/tmp/scheduled-tasks-dirs.txt"
perm_fix -m 750 -o 0 -g 0 "${paths[@]}"
#
# SSH configurations, private keys, and public keys.
mapfile -td '' paths < "${log_dir}/tmp/ssh-config-files.txt"
perm_fix -m 600 -o 0 -g 0 "${paths[@]}"
mapfile -td '' paths < "${log_dir}/tmp/ssh-config-dirs.txt"
perm_fix -m 700 -o 0 -g 0 "${paths[@]}"
mapfile -td '' paths < "${log_dir}/tmp/ssh-pub-files.txt"
perm_fix -m 644 -o 0 -g 0 "${paths[@]}"
#
# Secure MOTD/banners are secured
perm_fix -m 644 -o 0 -g 0 /etc/issue /etc/issue.net /etc/motd
#
# System logs
perm_fix -m 755 -o 0 -g 0 /var/log
mapfile -td '' paths < "${log_dir}/tmp/system-log-files"
perm_fix -m 640 "${paths[@]}"
mapfile -td '' paths < "${log_dir}/tmp/system-log-dirs"
perm_fix -m 750 "${paths[@]}"
#
# Some distros use the adm user for these logs
if [[ -d ${auditd_log_dir} ]]; then
	case "${os_info[ID]}" in
	'ubuntu'|'almalinux')
		mapfile -td '' paths < "${log_dir}/tmp/auditd-log-files.txt"
		perm_fix -m 640 -o 0 -g adm "${paths[@]}"
		;;
	*)
		mapfile -td '' paths < "${log_dir}/tmp/auditd-log-dirs.txt"
		perm_fix -m 600 -o 0 -g 0 "${paths[@]}"
		;;
	esac
	perm_fix -m 750 "${auditd_log_dir}"
fi
#
# Secure AuditD/rsyslog configurations
mapfile -td '' paths < "${log_dir}/tmp/logging-daemon-config-files.txt"
perm_fix -m 640 -o 0 -g 0 "${paths[@]}"
mapfile -td '' paths < "${log_dir}/tmp/logging-daemon-config-dirs.txt"
perm_fix -m 750 -o 0 -g 0 "${paths[@]}"
#
# Secure global shell profiles
mapfile -td '' paths < "${log_dir}/tmp/global-shell-profile-files.txt"
perm_fix -m 644 -o 0 -g 0 "${paths[@]}"
mapfile -td '' paths < "${log_dir}/tmp/global-shell-profile-dirs.txt"
perm_fix -m 755 -o 0 -g 0 "${paths[@]}"
#
# Secure local home directories (including /root)
for user in "${int_users[@]}"; do
	home="$(grep -- "^${user}:" /etc/passwd | head -n1 | cut -d: -f6)"
	[[ "${home}" == / ]] && continue
	mapfile -td '' paths < "${log_dir}/tmp/${user}-files.txt"
	perm_fix -m 600 -o "${user}" -g "${user}" "${paths[@]}"
	mapfile -td '' paths < "${log_dir}/tmp/${user}-dirs.txt"
	perm_fix -m 700 -o "${user}" -g "${user}" "${paths[@]}"
done
unset home
mapfile -td '' paths < "${log_dir}/tmp/root-home-files.txt"
perm_fix -m 600 -o 0 -g 0 "${paths[@]}"
mapfile -td '' paths < "${log_dir}/tmp/root-home-dirs.txt"
perm_fix -m 700 -o 0 -g 0 "${paths[@]}"
#
# APT keyrings
mapfile -td '' paths < "${log_dir}/tmp/apt-keyrings.txt"
perm_fix -m 644 -o 0 -g 0 "${paths[@]}"
#
# Privileged binaries
perm_fix -m 750 -o 0 -g 0 /sbin/auditctl /sbin/aureport /sbin/ausearch /sbin/autrace /sbin/auditd /sbin/augenrules /bin/dmesg /usr/bin/dmesg





#
# Misc.
#
# Paths in /etc/ which aren't owned by a system user.
mapfile -td '' paths < "${log_dir}/tmp/etc.txt"
for path in "${paths[@]}"; do
	# If the owners are system users/groups, it's probably fine.
	user_owner="$(stat -c %u -- "${path}")"
	group_owner="$(stat -c %g -- "${path}")"
	if ((user_owner < 1000 || group_owner < 1000)); then
		printf '%s\0' "${path}" > "${log_dir}/etc-system-owned.txt"
	else
		printf '%s\0' "${path}" > "${log_dir}/etc-user-owns.txt"
	fi
done
unset user_owner group_owner
#
# FHS temp directories are world-writable w/ sticky-bit.
perm_fix -m 1777 -o 0 -g 0 /tmp /var/tmp /dev/shm
