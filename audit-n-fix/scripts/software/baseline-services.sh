#!/usr/bin/env bash





#
# SystemD Baselining
#
# Baseline /etc/systemd/system/ from /lib/systemd/system/
log i 'Baselining "/etc/systemd/system/" against "/lib/systemd/system/"...'
mapfile -td '' paths < <(find /etc/systemd/system -maxdepth 1 -mindepth 1 -print0)
for svc_path in "${paths[@]}"; do
	# Handle symlinks
	if [[ -h "${svc_path}" ]]; then
		# Checks if a service is a symlink to a file in /lib/systemd/system/ or /usr/lib/systemd/system/.
		real_path="$(readlink -- "${svc_path}")"
		if [[
			"${real_path}" == /lib/systemd/system/* ||
			"${real_path}" == /usr/lib/systemd/system/*
		]]; then
			# Generally most services fall under the above condition.
			log i "${svc_path} is likely a vendor provided service that has been enabled."
		elif [[ "${real_path}" == /dev/null ]]; then
			log i "${svc_path} is a masked service pointing to /dev/null."
		else
			if confirm "Review unexpected link (\"${svc_path}\" points to \"${real_path}\")"; then
				"${EDITOR}" -- "${real_path}"
				confirm "Delete link pointing from \"${svc_path}\" to \"${real_path}\"" && unlink -- "${svc_path}"
				confirm "Delete source file \"${real_path}\"" && rm -vi -- "${real_path}"
			fi
		fi
	#
	# Handle directories
	elif [[ -d "${svc_path}" ]]; then
		if [[ "${svc_path}" == *.d ]]; then
			log i "${svc_path} is an overrides directory."
		elif confirm "Review service file \"${svc_path}\""; then
			mapfile -td '' files < <(find "${svc_path}" -type f -print0)
			for file in "${files[@]}"; do
				"${EDITOR}" -- "${file}"
				rm -vi -- "${file}"
			done
		fi
		find -- "${svc_path}" -mindepth 1 -q -print -quit |
			grep -q . &&
			rm -vdi -- "${svc_path}"
	#
	# Prompt to audit files. If yes, audit files then ask for whether to delete the file.
	elif [[ -f "${svc_path}" ]] && confirm "Review non-native service \"${svc_path}\""; then
		"${EDITOR}" -- "${svc_path}"
		rm -vi -- "${svc_path}"
	fi
done
