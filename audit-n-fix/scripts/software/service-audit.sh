#!/usr/bin/env bash





#
# SystemD Baselining
#
case "${init}" in
'systemd')
	mapfile -td '' paths < <(find /etc/systemd/system -maxdepth 1 -mindepth 1 -print0)
	for path in "${paths[@]}"; do
		resolved_path="$(readlink -- "${path}")"
		#
		# Symlinks
		if [[ -h "${path}" ]]; then
			case "${resolved_path}" in
			/lib/systemd/system/*|/usr/lib/systemd/system/*)
				log i "Likely vendor service: ${path@Q}"
				printf '%s\0' "${path}" "${resolved_path}" >> "${log_dir}/likely-vendor-services.txt"
				;;
			/dev/null)
				log i "Masked service: ${path@Q}"
				printf '%s\0' "${path}" "${resolved_path}" >> "${log_dir}/masked-services.txt"
				;;
			*)
				log w "Custom (and symlinked) service: ${path@Q}"
				printf '%s\0' "${path}" "${resolved_path}" >> "${log_dir}/custom-services-(symlinked).txt"
				;;
			esac
		#
		# Directories
		elif [[ -d "${path}" ]]; then
			case "${path}" in
			*.d)
				log w "Service override: ${path@Q}"
				printf '%s\0' "${path}" >> "${log_dir}/service-overrides-dirs.txt"
				;;
			*.wants)
				log i "Service dependencies: ${path@Q}"
				printf '%s\0' "${path}" >> "${log_dir}/service-dependencies-dirs.txt"
				;;
			*)
				log w "Unidentified directory: ${path@Q}"
				printf '%s\0' "${path}" >> "${log_dir}/service-unknown-dirs.txt"
				;;
			esac
		#
		# Normal files
		elif [[ -f "${path}" ]]; then
			log w "Custom service found: ${path@Q}"
			printf '%s\0' "${path}" >> "${log_dir}/custom-services.txt"
		fi
	done
	;;
'init')
	case "${pkg_mgr}" in
	'pkg')
		pkg which /etc/rc.d/* | grep -v "not found" | log i
		pkg which /etc/rc.d/* | grep "not found" | log w
		;;
	'rpm')
		for path in /etc/rc.d/init.d/*; do
			rpm -qf "${path}" 2>/dev/null | log i
			rpm -qf "${path}" >/dev/null 2>&1 | log w
		done
		;;
	esac
	;;
*)
	log e 'Unsupported init. system.'
	exit 11
	;;
esac
