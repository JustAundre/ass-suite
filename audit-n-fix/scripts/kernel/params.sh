#!/usr/bin/env bash





#
# Kernel Parameters
#
(
	# Snapshot sysctl params pre-application
	before="$(sysctl -a)"
	#
	# Load general sysctl hardening profile
	[[ -f /etc/sysctl.d/99-security.conf ]] ||
		install -m 640 -o 0 -g 0 cnf/sysctl/kernel.conf /etc/sysctl.d/99-security.conf
	#
	# Load Anti-IPv6 sysctl profile
	if [[ ! -f /etc/sysctl.d/99-disable-ipv6.conf ]]; then
		confirm 'Disable IPv6 @ kernel level' &&
			install -m 640 -o 0 -g 0 cnf/sysctl/kernel-no-ipv6.conf /etc/sysctl.d/99-disable-ipv6.conf;
	fi
	#
	# Install service to disable mutability of kernel modules 10 seconds after boot.
	confirm 'Disable the loading or unloading of kernel modules 10 seconds after boot' &&
		install -m 600 -o 0 -g 0 cnf/sysctl/immutable-modules.service /etc/systemd/system/immutable-modules.service &&
		systemctl daemon-reload && systemctl enable --now immutable-modules.service
	#
	# Apply changes
	sysctl --system >/dev/null
	#
	# Snapshot sysctl params post-application
	after="$(sysctl -a)"
	#
	# Check for changes
	diff -u <(printf '%s' "${before}") <(printf '%s' "${after}") &&
		log i 'Nothing has changed, meaning your sysctl is likely already sufficiently hardened.'
)
