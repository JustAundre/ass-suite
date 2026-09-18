#!/usr/bin/env bash

firewalls=(
	'Uncomplicated Firewall (UFW)'
	'Firewall Daemon (FirewallD)'
)
if hash pfctl; then
	selection='Packet Filters (pf)'
else
	selection="$(PS2='Select your firewall of choice' cl-new "${firewalls[@]}")"
fi
case "${selection}" in
	'UFW')
		rm -rfv /etc/ufw
		if hash apt-get &>/dev/null; then
			apt-get install --reinstall -y ufw
		elif hash dnf &>/dev/null; then
			dnf install ufw -y
		elif hash pacman &>/dev/null; then
			pacman -S ufw --noconfirm
		else
			log e 'Package manager not supported.'
			exit 12
		fi
		systemctl unmask ufw
		systemctl enable --now ufw
		ufw reset
		ufw default deny incoming
		ufw default allow outgoing
		;;
	'FirewallD')
		rm -rfv /etc/firewalld/
		if hash apt-get &>/dev/null; then
			apt-get install --reinstall -y firewalld
		elif hash dnf &>/dev/null; then
			dnf install firewalld -y
		elif hash pacman &>/dev/null; then
			pacman -S firewalld --noconfirm
		else
			log e 'Package manager not supported.'
			exit 12
		fi
		systemctl unmask firewalld
		systemctl enable --now firewalld
		firewall-cmd --reset-to-defaults
		firewall-cmd --set-default-zone public
		firewall-cmd --permanent --load-zone-defaults public
		firewall-cmd --permanent --add-icmp-block echo-request && log i 'Blocked ICMP echo requests.'
		firewall-cmd --permanent --add-icmp-block timestamp-reply && log i 'Blocked ICMP timestamp replies.'
		firewall-cmd --permanent --add-icmp-block timestamp-request && log i 'Blocked ICMP timestamp requests.'
		firewall-cmd --permanent --add-icmp-block redirect && log i 'Blocked ICMP redirects.'
		firewall-cmd --permanent --add-icmp-block address-mask-request && log i 'Blocked ICMP address mask requests.'
		firewall-cmd --permanent --add-icmp-block address-mask-reply && log i 'Blocked ICMP address mask replies.'
		firewall-cmd --permanent --add-icmp-block router-solicitation && log i 'Blocked ICMP router solicitation requests.'
		firewall-cmd --permanent --add-icmp-block router-advertisement && log i 'Blocked ICMP router advertisement requests.'
		firewall-cmd --permanent --add-icmp-block information-request && log i 'Blocked ICMP information requests.'
		firewall-cmd --permanent --add-icmp-block information-reply && log i 'Blocked ICMP information replies.'
		firewall-cmd --reload
		;;
	'pf (Packet Filters)')
		pkg install -fy FreeBSD-pf && log i 'Reinstalled "Packet Filters" package.'
		cp -pv /etc/pf.conf{,~} && log i 'Backed up current pf configuration.'
		install -o 0 -g wheel -m 640 cnf/pf.conf /etc/pf.conf && log i 'Installed preset pf configuration.'
		if pfctl -nf /etc/pf.conf; then
			log i 'Passed syntax check.'
			rm -v /etc/pf.conf~
			pfctl -f /etc/pf.conf && log i 'Reloaded pf configuration.'
		else
			log e 'New pf configuration failed syntax check.'
			if [[ -f '/etc/pf.conf~' ]]; then
				mv -vf /etc/pf.conf{~,} && log i 'Restored original pf configuration.'
				pfctl -f /etc/pf.conf && log i 'Reloaded original pf configuration.'
			else
				rm -v /etc/pf.conf{,~}
			fi
		fi
		service pf restart
		;;
	*)
		log e 'Firewall software unsupported.'
		exit 11
		;;
esac
