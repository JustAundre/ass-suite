#!/usr/bin/env bash





#
# Environment Setup
#
# Determine whether the system uses...
# 0:shadow or 0:0 for the system
is_shadow="$(getent group shadow | cut -d':' -f1)"
is_shadow="${is_shadow:-root}"
#
# Helper function to (mod)ify file (meta)data
# path, owner, octal perm, attribute
metamod() {
	# Change its permissions & attributes based on the given options
	echo "\"${1}\" was flagged."
	chown -- "${2}" "${1}"
	chmod -- "${3}" "${1}"
	chattr -- +"${4}" "${1}"
}
#
# Helper function to (mon)itor (file)s
filemon() {
	while IFS='' read -rd '' file; do
		# Ensure the path isn't a directory
		# Ampersand (&) placed at the end of metamod to prevent it from bottle-necking.
		[[ -f ${file} ]] && metamod "${file}" "${3}" "${4}" "${5}" &
	done < <(inotifywait --includei "${2}" --format '%w%f%0' -qmrP -e attrib -e move -e create -- "${1}")
}





#
# Monitoring
#
# Monitor & revert changes to identity management
filemon /etc '/(passwd|group)$' root 644 ia &
filemon /etc '/g?shadow$' "root:${is_shadow}" 640 ia &
#
# Lockdown all history files
filemon /home '/history$' root 620 a &
filemon /root '/history$' root 620 a &
#
# Lockdown bash rc/logout/profile files
filemon /home '/(rc|logout|profile)$' root 640 ia &
filemon /root '/(rc|logout|profile)$' root 640 ia &
#
# Keep the script active until all children processes exit
wait
