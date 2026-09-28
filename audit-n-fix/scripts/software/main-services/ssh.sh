#!/usr/bin/env bash





#
# Reset & Regen
#
# Backup existing SSH configs
mv -v /etc/ssh{,~}
#
# Reinstall SSHD
case "${pkg_mgr}" in
	'apt-get') "${pkg_mgr}" install --reinstall openssh-server -y ;;
	'dnf') "${pkg_mgr}" reinstall openssh-server -y ;;
	'yum') "${pkg_mgr}" reinstall openssh-server -y ;;
	'pacman') "${pkg_mgr}" -S openssh --noconfirm ;;
	'pkg') "${pkg_mgr}" install -f sshd ;;
	*)
		log e 'Unsupported package manager.'
		exit 11
		;;
esac
#
# Regenerate
ssh-keygen -A
ssh-keygen -f /root/.ssh/known_hosts -R localhost
#
# Install preset sshd_config file
install -o 0 -g 0 -m 640 -v cnf/sshd_config /etc/ssh/sshd_config





#
# Diff
#
diff /etc/ssh /etc/ssh~ -rp > "${log_dir}/ssh_config_diffs.txt"
diff /etc/ssh /etc/ssh~ -rp --color=always | less -R
