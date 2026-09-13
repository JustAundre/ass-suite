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
mapfile -td '' selections < <(
	PS2='These are active kernel modules; select ones to disable.' cl-new -mo "${readable[@]}" |
		cut -d: -f1
)
if ! ((${#selections[@]})); then
	log i 'No modules selected for disabling; ending script...'
	exit 0
fi
modprobe -r "${selections[@]}"
perm_fix -m 644 -o 0 -g 0 /etc/modprobe.d/hardening.conf
printf 'install %s /bin/false' "${selections[@]}" >> /etc/modprobe.d/hardening.conf
log i 'You can find blocked kernel modules @ "/etc/modprobe.d/hardening.conf"'
