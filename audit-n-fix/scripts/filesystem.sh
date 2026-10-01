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
	[[ ${type} == 'N' ]] && printf '%s\0' "${path}" >&8
	if [[ ${user} == "${uid}" ]]; then
		printf '%s\0' "${path}" >&6
		log w "Owned by an invalid UID: ${path@Q}"
	fi
	if [[ ${group} == "${gid}" ]]; then
		printf '%s\0' "${path}" >&7
		log w "Owned by an invalid GID: ${path@Q}"
	fi
	if [[ ${path:0:4} == '/etc/' ]] && ((uid > id_bounds[SYS_UID_MAX] || gid > id_bounds[SYS_UID_MAX])); then
		printf '%s\0' "${path}" >&9
		log w "Owned by a non-system user: ${path@Q}"
	fi
	if [[ ! ${path} =~ /[\x00-\x7F\n]+$ ]]; then
		printf '%s\0' "${path}" >&10
		log w "Name contains non-ASCII character: ${path@Q}"
	fi
	if [[ ! ${path} =~ ^[a-zA-Z0-9_] ]]; then
		printf '%s\0' "${path}" >&11
		log w "Name leads with a non-alphanumeric character: ${path@Q}"
	fi
done < <(find / -xephem -printf '%m:%U:%u:%G:%g:%y:%p\0')\
	3>"${log_dir}/suid-binaries.txt"\
	4>"${log_dir}/sgid-binaries.txt"\
	5>"${log_dir}/world-writables.txt"\
	6>"${log_dir}/no-user.txt"\
	7>"${log_dir}/no-group.txt"\
	8>"${log_dir}/broken-symlinks.txt"\
	9>"${log_dir}/etc-user-owned.txt"\
	10>"${log_dir}/non-ascii-paths.txt"\
	11>"${log_dir}/non-alphanumeric-leads.txt" &
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
if auditd_log_dir="$(dirname "$(awk -F ' = ' '/^\s*log_file/ { print $2 }' /etc/audit/auditd.conf)")"; then
	find -- "${auditd_log_dir}" -type f -print0 > "${log_dir}/tmp/auditd-log-files.txt" &
	find -- "${auditd_log_dir}" -type d -print0 > "${log_dir}/tmp/auditd-log-dirs.txt" &
fi
find /etc/audit /etc/rsyslog.d/ /etc/rsyslog.conf -mindepth 1 -type f -print0 > "${log_dir}/tmp/logging-daemon-config-files.txt" &
find /etc/audit /etc/rsyslog.d/ -type d -print0 > "${log_dir}/tmp/logging-daemon-config-dirs.txt" &
find /etc/profile /etc/bashrc /etc/bash.bashrc /etc/profile.d/ -type f -print0 > "${log_dir}/tmp/global-shell-profile-files.txt" &
find /etc/profile.d/ -type d -print0 > "${log_dir}/tmp/global-shell-profile-dirs.txt" &
find /etc/apt/trusted.gpg.d /usr/share/keyrings -type f -print0 > "${log_dir}/tmp/apt-keyrings.txt" &
wait





#
# SUID/SGID Binaries
#
mapfile -td '' paths < "${log_dir}/suid-binaries.txt"
mapfile -td '' selections < <(PS2='Select paths to remove the SUID bit from' cl-new -mo "${paths[@]}")
((${#selections[@]})) && chmod u-s -v -- "${selections[@]}"
mapfile -td '' paths < "${log_dir}/sgid-binaries.txt"
mapfile -td '' selections < <(PS2='Select paths to remove the SGID bit from' cl-new -mo "${paths[@]}")
((${#selections[@]})) && chmod g-s -v -- "${selections[@]}"





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
# Configurations
#
# Bootloader config
mapfile -td '' paths < "${log_dir}/tmp/boot-files.txt"
perm_fix -m 640 -o 0 -g 0 "${paths[@]}"
mapfile -td '' paths < "${log_dir}/tmp/boot-dirs.txt"
perm_fix -m 750 -o 0 -g 0 "${paths[@]}"
#
# AuditD/rsyslog configurations
mapfile -td '' paths < "${log_dir}/tmp/logging-daemon-config-files.txt"
perm_fix -m 640 -o 0 -g 0 "${paths[@]}"
mapfile -td '' paths < "${log_dir}/tmp/logging-daemon-config-dirs.txt"
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
# Secure global shell profiles
mapfile -td '' paths < "${log_dir}/tmp/global-shell-profile-files.txt"
perm_fix -m 644 -o 0 -g 0 "${paths[@]}"
mapfile -td '' paths < "${log_dir}/tmp/global-shell-profile-dirs.txt"
perm_fix -m 755 -o 0 -g 0 "${paths[@]}"
#
# Secure local home directories
for entry in "${passwd[@]}"; do
	IFS=':' read -rd $'\n' user hash uid gid gecos home shell <<<"${entry}"
	[[ ${shell} =~ /('nologin'|'false')$ || ${home} == '/' ]] && continue
	perm_fix -m 700 -o "${uid}" -g "${gid}" "${home}" "${home}/.ssh" "${home}/.gnupg"
	perm_fix -m 600 -o "${uid}" -g "${gid}" "${home}/.ssh/authorized_keys" "${home}/.ssh/id_*"
done
#
# APT keyrings
mapfile -td '' paths < "${log_dir}/tmp/apt-keyrings.txt"
perm_fix -m 644 -o 0 -g 0 "${paths[@]}"
#
# FHS temp directories are world-writable w/ sticky-bit.
perm_fix -m 1777 -o 0 -g 0 /tmp /var/tmp /dev/shm






#
# Services
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
# Logs
#
# General Logs
perm_fix -m 755 -o 0 -g 0 /var/log
mapfile -td '' paths < "${log_dir}/tmp/system-log-files.txt"
perm_fix -m 640 "${paths[@]}"
mapfile -td '' paths < "${log_dir}/tmp/system-log-dirs.txt"
perm_fix -m 750 "${paths[@]}"
#
# AuditD logs
# Some distros use the adm user for these
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
