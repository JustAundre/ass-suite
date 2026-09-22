#!/usr/bin/env bash





#
# SystemD Baselining
#
case "${init}" in
'systemd')
	mapfile -td '' paths < <(find /etc/systemd/system -maxdepth 1 -mindepth 1 -print0)
	for svc_path in "${paths[@]}"; do
		# Symlinks
		if [[ -h "${svc_path}" ]]; then
			real_path="$(readlink -- "${svc_path}")"
			case "${real_path}" in
			/lib/systemd/system/*|/usr/lib/systemd/system/*) printf '%s\0' "${svc_path}" "${real_path}" >> "${log_dir}/likely-vendor-services.txt" ;;
			/dev/null) printf '%s\0' "${svc_path}" "${real_path}" >> "${log_dir}/masked-services.txt" ;;
			*) printf '%s\0' "${svc_path}" "${real_path}" >> "${log_dir}/custom-services-(symlinked).txt" ;;
			esac
		#
		# Directories
		elif [[ -d "${svc_path}" ]]; then
			case "${svc_path}" in
			*.d) printf '%s\0' "${svc_path}" >> "${log_dir}/service-overrides-dirs.txt" ;;
			*.wants) printf '%s\0' "${svc_path}" >> "${log_dir}/service-dependencies-dirs.txt" ;;
			*) printf '%s\0' "${svc_path}" >> "${log_dir}/service-unknown-dirs.txt" ;;
			esac
		#
		# Normal files
		elif [[ -f "${svc_path}" ]]; then
			printf '%s\0' "${svc_path}" >>"${log_dir}/custom-services.txt"
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
