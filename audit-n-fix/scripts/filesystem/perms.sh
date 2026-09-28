#!/usr/bin/env bash





#
# Environment Setup
#
mkdir -p "${log_dir}/tmp"
log i 'Conducting filesystem searches for various criterias...' 'This may take a while.'
while IFS=':' read -rd '' mode uid user gid group type path; do
	((${#mode} == 3)) && mode="0${mode}"
	[[ "${mode:0:1}" =~ ^(4|6)$ ]] && printf '%s\0' "${path}" >&3
	[[ "${mode:0:1}" =~ ^(2|6)$ ]] && printf '%s\0' "${path}" >&4
	[[ "${mode:3:1}" =~ ^(2|3|6)$ ]] && printf '%s\0' "${path}" >&5
	if [[ ${user} == "${uid}" ]]; then
		printf '%s\0' "${path}" >&6
		log w "${path@Q} is owned by an invalid UID."
	fi
	if [[ ${group} == "${gid}" ]]; then
		printf '%s\0' "${path}" >&7
		log w "${path@Q} is owned by an invalid GID."
	fi
	[[ ${type} == 'N' ]] && printf '%s\0' "${path}" >&8
	[[ ${path:0:4} == '/etc/' ]] && ((uid > uid_bounds[SYS_UID_MAX] || gid > uid_bounds[SYS_UID_MAX])) && printf '%s\0' "${path}" >&9
done < <(find / -xephem -printf '%m:%U:%u:%G:%g:%y:%p\0') 3>"${log_dir}/suid-binaries.txt" 4>"${log_dir}/sgid-binaries.txt" 5>"${log_dir}/world-writables.txt" 6>"${log_dir}/no-user.txt" 7>"${log_dir}/no-group.txt" 8>"${log_dir}/broken-symlinks.txt" 9>"${log_dir}/etc-user-owned.txt" &
find /etc/sudoers.d /etc/sudoers -type f -print0 > "${log_dir}/tmp/sudoers-files.txt" &
find /etc/sudoers.d -type d -print0 > "${log_dir}/tmp/sudoers-dirs.txt" &
find /boot -type f -print0 > "${log_dir}/tmp/boot-files.txt" &
find /boot -type d -print0 > "${log_dir}/tmp/boot-dirs.txt" &
find /etc/systemd/system -type f -print0 > "${log_dir}/tmp/systemd-unit-files.txt" &
find /etc/systemd/system -type d -print0 > "${log_dir}/tmp/systemd-unit-dirs.txt" &
find /etc/cron.* /etc/crontab /etc/at.allow -type f -print0 > "${log_dir}/tmp/scheduled-tasks-files.txt" &
find /etc/cron.* /etc/crontab /etc/at.allow -type d -print0 > "${log_dir}/tmp/scheduled-tasks-dirs.txt" &
find /var/log/ -mindepth 1 -type f -print0 > "${log_dir}/tmp/system-log-files.txt" &
find /var/log/ -mindepth 1 -type d -print0 > "${log_dir}/tmp/system-log-dirs.txt" &
find /etc/ssh -type f -print0 > "${log_dir}/tmp/ssh-config-files.txt" &
find /etc/ssh -type d -print0 > "${log_dir}/tmp/ssh-config-dirs.txt" &
find /etc/ssh -name '*.pub' -type f -print0 > "${log_dir}/tmp/ssh-pub-files.txt" &
auditd_log_dir="$(dirname "$(awk -F ' = ' '/^\s*log_file/ { print $2 }' /etc/audit/auditd.conf)")"
find -- "${auditd_log_dir}" -type f -print0 > "${log_dir}/tmp/auditd-log-files.txt" &
find -- "${auditd_log_dir}" -type f -print0 > "${log_dir}/tmp/auditd-log-dirs.txt" &
find /etc/audit /etc/rsyslog.d/ /etc/rsyslog.conf -mindepth 1 -type f -print0 > "${log_dir}/tmp/logging-daemon-config-files.txt" &
find /etc/audit /etc/rsyslog.d/ -type d -print0 > "${log_dir}/tmp/logging-daemon-config-dirs.txt" &
find /etc/profile /etc/bashrc /etc/bash.bashrc /etc/profile.d/ -type f -print0 > "${log_dir}/tmp/global-shell-profile-files.txt" &
find /etc/profile.d/ -type d -print0 > "${log_dir}/tmp/global-shell-profile-dirs.txt" &
find /etc/apt/trusted.gpg.d /usr/share/keyrings -type f -print0 > "${log_dir}/tmp/apt-keyrings.txt" &
wait





#
# SUID Binaries
#
mapfile -td '' paths < "${log_dir}/suid-binaries.txt"
mapfile -td '' selections < <(PS2='Select paths to remove the SUID bit from' cl-new -mo "${paths[@]}")
((${#selections[@]})) && chmod u-s -v -- "${selections[@]}"





#
# SGID Binaries
#
mapfile -td '' paths < "${log_dir}/sgid-binaries.txt"
mapfile -td '' selections < <(PS2='Select paths to remove the SGID bit from' cl-new -mo "${paths[@]}")
((${#selections[@]})) && chmod g-s -v -- "${selections[@]}"





#
# Broken Ownerships
#
# UIDs
mapfile -td '' paths < "${log_dir}/no-user.txt"
perm_fix -o 0 "${paths[@]}"
#
# GIDs
mapfile -td '' paths < "${log_dir}/no-group.txt"
perm_fix -g 0 "${paths[@]}"





#
# Identity & Authorization
#
# /etc/passwd, /etc/group and the shadow files (plus their backups)
perm_fix -m 644 -o 0 -g 0 /etc/passwd /etc/group
if grep -qE '^shadow:' /etc/group; then
	perm_fix -m 640 -o 0 -g shadow /etc/shadow /etc/gshadow
	perm_fix -m 640 -o 0 -g 0 /etc/shadow- /etc/gshadow-
else
	perm_fix -m 600 -o 0 -g 0 /etc/shadow /etc/gshadow /etc/shadow- /etc/gshadow-
fi
#
# Sudoers configuration
mapfile -td '' paths < "${log_dir}/tmp/sudoers-files.txt"
perm_fix -m 640 -o 0 -g 0 "${paths[@]}"
mapfile -td '' paths < "${log_dir}/tmp/sudoers-dirs.txt"
perm_fix -m 750 -o 0 -g 0 "${paths[@]}"





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
perm_fix -m 640 -o 0 -g 0 "${paths[@]}"
mapfile -td '' paths < "${log_dir}/tmp/ssh-config-dirs.txt"
perm_fix -m 750 -o 0 -g 0 "${paths[@]}"
mapfile -td '' paths < "${log_dir}/tmp/ssh-pub-files.txt"
perm_fix -m 644 -o 0 -g 0 "${paths[@]}"
#
# Secure MOTD/banners are secured
perm_fix -m 644 -o 0 -g 0 /etc/issue /etc/issue.net /etc/motd
#
# System logs
perm_fix -m 755 -o 0 -g 0 /var/log
mapfile -td '' paths < "${log_dir}/tmp/system-log-files.txt"
perm_fix -m 640 "${paths[@]}"
mapfile -td '' paths < "${log_dir}/tmp/system-log-dirs.txt"
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
# Secure local home directories
for user in "${int_users[@]}"; do
	home="$(grep -- "^${user}:" /etc/passwd | head -n1 | cut -d: -f6)"
	[[ "${home}" == / ]] && continue
	perm_fix -m 750 -o "${user}" -g "${user}" "${home}"
done
unset home
#
# Secure /root
perm_fix -m 700 -o 0 -g 0 /root
#
# APT keyrings
mapfile -td '' paths < "${log_dir}/tmp/apt-keyrings.txt"
perm_fix -m 644 -o 0 -g 0 "${paths[@]}"
#
# FHS temp directories are world-writable w/ sticky-bit.
perm_fix -m 1777 -o 0 -g 0 /tmp /var/tmp /dev/shm
