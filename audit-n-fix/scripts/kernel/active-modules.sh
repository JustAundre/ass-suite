#!/usr/bin/env bash





#
# Active Module Audit
#
# Fetch loaded kernel modules'...
mapfile -td '' mods < <(grep -Eo '^[^ ]+' /proc/modules | sort)
for mod in "${mods[@]}"; do
	# Descriptions
	desc="$(modinfo -d "${mod}" | tr -d '\n')"
	[[ -z "${desc}" ]] && desc='No description.'
	#
	# Dependencies
	deps="$(modinfo "${mod}" -F depends)"
	[[ "${deps}" =~ ^\w+$ ]] && deps=nothing.
	#
	# Combine.
	readable+=("${mod}: ${desc} - Depends on ${deps}")
done
#
# Unload & disable selected modules.
mapfile -td '' mods < <(
	cl-new -mt 'These are active kernel modules; select those to unload and disable.' "${readable[@]}" |
		cut -d: -f1
)
modprobe -r "${mods[@]}"
perm_fix -m 644 -o 0 -g 0 /etc/modprobe.d/hardening.conf
for mod in "${mods[@]}"; do
	echo "install ${mod} /bin/false" >>/etc/modprobe.d/hardening.conf
done
log i 'You can find blocked kernel modules @ "/etc/modprobe.d/hardening.conf"'
